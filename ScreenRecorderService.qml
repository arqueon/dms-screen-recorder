import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var popoutService: null
    property string recordState: "idle" // idle | recording | paused | stopping
    property int recordTimerSeconds: 0
    property bool _stopRequested: false
    property bool _cancelStart: false
    property string _currentOutputFile: ""
    property string _lastStderr: ""

    function _setState(state) {
        recordState = state
        pluginService?.setGlobalVar(pluginId, "recordState", state)
    }

    function _setTimer(seconds) {
        recordTimerSeconds = seconds
        pluginService?.setGlobalVar(pluginId, "recordTimerSeconds", seconds)
    }

    function _setDiagnostic(text) {
        pluginService?.setGlobalVar(pluginId, "lastDiagnostic", text)
    }

    function _loadSetting(key, fallback) {
        return pluginService ? pluginService.loadPluginData(pluginId, key, fallback) : fallback
    }

    function _shortDiagnostic(text) {
        const cleaned = (text || "").trim().replace(/\s+/g, " ")
        return cleaned.length > 500 ? cleaned.slice(0, 497) + "..." : cleaned
    }

    function _resetRuntimeState() {
        recordingTimer.stop()
        stopEscalationTimer.stop()
        killEscalationTimer.stop()
        _setTimer(0)
        _setState("idle")
        _stopRequested = false
        _cancelStart = false
    }

    Timer {
        id: recordingTimer
        interval: 1000
        repeat: true
        running: root.recordState === "recording"
        onTriggered: root._setTimer(root.recordTimerSeconds + 1)
    }

    Timer {
        id: stopEscalationTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (!recorder.running) return
            ToastService.showInfo("Recorder is taking longer than expected to stop; sending SIGTERM.")
            recorder.signal(15)
            killEscalationTimer.start()
        }
    }

    Timer {
        id: killEscalationTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (!recorder.running) return
            ToastService.showError("Recorder did not stop", "Force-stopping it may leave the video incomplete.")
            recorder.signal(9)
        }
    }

    function startRecording() {
        if (recordState !== "idle") return
        _cancelStart = false
        _setDiagnostic("")
        _setState("preparing")
        _setTimer(0)

        const captureSource = _loadSetting("captureSource", "portal") || "portal"
        if (captureSource === "portal") {
            Proc.runCommand(
                "screenRecorder.portalCheck",
                ["sh", "-c", "gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop 2>/dev/null | grep -q 'org.freedesktop.portal.ScreenCast'"],
                (stdout, exitCode) => {
                    if (_cancelStart || recordState !== "preparing") return
                    if (exitCode !== 0) {
                        _setDiagnostic("The XDG portal ScreenCast interface is unavailable.")
                        _resetRuntimeState()
                        ToastService.showError("Portal capture is unavailable", "Start a compatible xdg-desktop-portal backend, or choose All screens capture.")
                        return
                    }
                    _resolveOutputDirectory()
                }
            )
        } else {
            _resolveOutputDirectory()
        }
    }

    function _resolveOutputDirectory() {
        const configuredDir = String(_loadSetting("outputDir", "") || "").trim()
        Proc.runCommand(
            "screenRecorder.outputDirectory",
            ["sh", "-c", "if [ -n \"$1\" ]; then printf '%s' \"$1\"; else printf '%s/Screencasting' \"${XDG_VIDEOS_DIR:-$HOME/Videos}\"; fi", "screenRecorder", configuredDir],
            (stdout, exitCode) => {
                if (_cancelStart || recordState !== "preparing") return
                const directory = stdout.trim()
                if (exitCode !== 0 || !directory) {
                    _setDiagnostic("Could not resolve the recordings directory.")
                    _resetRuntimeState()
                    ToastService.showError("Invalid recordings folder")
                    return
                }
                _resolveAudioAndStart(directory)
            }
        )
    }

    readonly property var audioModes: ["none", "system", "mic", "both_merged", "both_tracks"]

    function audioMode() {
        const mode = String(_loadSetting("audioMode", "") || "").trim()
        if (audioModes.indexOf(mode) !== -1) return mode
        // Migrate from the pre-1.5.0 recordAudio toggle
        return _loadSetting("recordAudio", true) ? "system" : "none"
    }

    function audioModeLabel(mode) {
        switch (mode) {
        case "system": return "System audio"
        case "mic": return "Microphone"
        case "both_merged": return "System + mic (mixed)"
        case "both_tracks": return "System + mic (separate tracks)"
        default: return "No audio"
        }
    }

    function setAudioMode(mode) {
        if (audioModes.indexOf(mode) === -1) return false
        pluginService?.savePluginData(pluginId, "audioMode", mode)
        pluginService?.setGlobalVar(pluginId, "audioMode", mode)
        const suffix = recordState === "idle" ? "" : " — applies to the next recording"
        ToastService.showInfo("Audio: " + audioModeLabel(mode) + suffix)
        return true
    }

    function _systemAudioDevice() {
        const device = String(_loadSetting("systemAudioDevice", "") || "").trim()
        if (device) return device
        // Honor the pre-1.5.0 audioSource setting when it named a specific source
        const legacy = String(_loadSetting("audioSource", "") || "").trim()
        if (legacy && legacy !== "default") return legacy
        return "default_output"
    }

    function _micDevice() {
        return String(_loadSetting("micDevice", "") || "").trim() || "default_input"
    }

    function _resolveAudioAndStart(directory) {
        const systemDevice = _systemAudioDevice()
        const micDevice = _micDevice()
        switch (audioMode()) {
        case "system":
            _launchRecorder(directory, ["-a", systemDevice])
            break
        case "mic":
            _launchRecorder(directory, ["-a", micDevice])
            break
        case "both_merged":
            _launchRecorder(directory, ["-a", systemDevice + "|" + micDevice])
            break
        case "both_tracks":
            _launchRecorder(directory, ["-a", systemDevice, "-a", micDevice])
            break
        default:
            _launchRecorder(directory, [])
        }
    }

    function _launchRecorder(directory, audioArgs) {
        if (_cancelStart || recordState !== "preparing") return

        const now = new Date()
        const dateStr = now.getFullYear() + "-" +
            ("0" + (now.getMonth() + 1)).slice(-2) + "-" +
            ("0" + now.getDate()).slice(-2) + "_" +
            ("0" + now.getHours()).slice(-2) + "-" +
            ("0" + now.getMinutes()).slice(-2) + "-" +
            ("0" + now.getSeconds()).slice(-2)
        const outputFile = directory.replace(/\/$/, "") + "/" + dateStr + ".mp4"
        const args = ["-w", _loadSetting("captureSource", "portal") || "portal",
                      "-f", _loadSetting("fps", "60") || "60",
                      "-k", "h264",
                      "-q", _loadSetting("quality", "very_high") || "very_high",
                      "-cursor", _loadSetting("recordCursor", true) ? "yes" : "no",
                      "-cr", "limited"]
        if (audioArgs.length > 0) args.push("-ac", "opus")
        for (const arg of audioArgs) args.push(arg)
        args.push("-o", outputFile)

        _currentOutputFile = outputFile
        _lastStderr = ""
        recorder.command = ["sh", "-c", "mkdir -p -- \"$1\" || exit 73; shift; exec gpu-screen-recorder \"$@\"", "screenRecorder", directory].concat(args)
        recorder.running = true
        _setState("recording")
        ToastService.showInfo((_loadSetting("captureSource", "portal") === "portal") ? "Select an area in the portal to start recording." : "Recording started.")
    }

    function stopRecording() {
        if (recordState === "idle") return
        if (recordState === "preparing") {
            _cancelStart = true
            _resetRuntimeState()
            ToastService.showInfo("Recording start cancelled")
            return
        }
        if (recordState === "stopping") return

        const wasPaused = recordState === "paused"
        _stopRequested = true
        _setState("stopping")
        if (recorder.running) {
            if (wasPaused) recorder.signal(18)
            recorder.signal(2)
            stopEscalationTimer.start()
        }
    }

    function togglePause() {
        if (!recorder.running || recordState === "idle" || recordState === "stopping") return
        if (recordState === "recording") {
            recorder.signal(19)
            _setState("paused")
            ToastService.showInfo("Recording paused")
        } else if (recordState === "paused") {
            recorder.signal(18)
            _setState("recording")
            ToastService.showInfo("Recording resumed")
        }
    }

    function _finishStoppedRecording(path) {
        Proc.runCommand("screenRecorder.verifyOutput", ["sh", "-c", "test -s \"$1\"", "screenRecorder", path], (stdout, exitCode) => {
            if (exitCode === 0) {
                const postCommand = String(_loadSetting("postRecordCommand", "") || "").trim()
                if (postCommand) {
                    Quickshell.execDetached(["sh", "-c", "set -- \"$1\"; " + postCommand, "screenRecorder", path])
                }
                ToastService.showInfo("Recording saved successfully")
            } else {
                ToastService.showError("Recording did not produce a video", "The recorder stopped, but the output file is missing or empty.")
            }
        })
    }

    IpcHandler {
        target: "screenRecorder"

        function startRecording(): string {
            if (root.recordState !== "idle") return "already_recording"
            root.startRecording()
            return "recording_start_requested"
        }

        function stopRecording(): string {
            if (root.recordState === "idle") return "not_recording"
            root.stopRecording()
            return "recording_stop_requested"
        }

        function toggleRecording(): string {
            if (root.recordState === "idle") {
                root.startRecording()
                return "recording_start_requested"
            }
            root.stopRecording()
            return "recording_stop_requested"
        }

        function togglePause(): string {
            if (root.recordState === "idle") return "not_recording"
            root.togglePause()
            return root.recordState === "paused" ? "recording_paused" : "recording_resumed"
        }

        function setAudioMode(mode: string): string {
            if (!root.setAudioMode(mode)) return "invalid_mode (valid: " + root.audioModes.join(", ") + ")"
            return "audio_mode_" + mode
        }

        function cycleAudioMode(): string {
            const next = root.audioModes[(root.audioModes.indexOf(root.audioMode()) + 1) % root.audioModes.length]
            root.setAudioMode(next)
            return "audio_mode_" + next
        }

        function getAudioMode(): string {
            return root.audioMode()
        }
    }

    Connections {
        target: root.pluginService
        function onPluginDataChanged(id) {
            if (id === root.pluginId) root.pluginService?.setGlobalVar(root.pluginId, "audioMode", root.audioMode())
        }
    }

    Process {
        id: recorder
        running: false

        stderr: StdioCollector {
            onStreamFinished: root._lastStderr = text.trim()
        }

        onExited: function(exitCode) {
            const wasStopRequested = root._stopRequested
            const elapsedSeconds = root.recordTimerSeconds
            const outputPath = root._currentOutputFile
            const diagnostic = root._shortDiagnostic(root._lastStderr)

            root._resetRuntimeState()
            root._currentOutputFile = ""

            if (wasStopRequested) {
                if (exitCode === 0) {
                    root._finishStoppedRecording(outputPath)
                } else {
                    const message = diagnostic || "gpu-screen-recorder exited with code " + exitCode + "."
                    root._setDiagnostic(message)
                    ToastService.showError("Recording could not be finalized", message)
                }
                return
            }

            if (exitCode !== 0) {
                let message = diagnostic || "gpu-screen-recorder exited with code " + exitCode + "."
                if (exitCode === 127) message = "gpu-screen-recorder is not installed or is not in PATH."
                else if (elapsedSeconds < 3 && exitCode === 1 && !diagnostic) message = "The recorder exited immediately. Check the XDG portal, capture source, and audio settings."
                root._setDiagnostic(message)
                ToastService.showError("Recording failed", message)
            } else {
                const message = "The recorder exited unexpectedly. Check the saved video and plugin diagnostics."
                root._setDiagnostic(message)
                ToastService.showError("Recording ended unexpectedly", message)
            }
        }
    }

    Component.onCompleted: {
        _setState("idle")
        _setTimer(0)
        _setDiagnostic("")
        pluginService?.setGlobalVar(pluginId, "audioMode", audioMode())
    }
}
