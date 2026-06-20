import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    pluginId: "screenRecorder"

    property string fps: pluginData.fps || "60"
    property string quality: pluginData.quality || "very_high"
    property bool recordCursor: pluginData.recordCursor !== undefined ? pluginData.recordCursor : true
    property bool recordAudio: pluginData.recordAudio !== undefined ? pluginData.recordAudio : true
    property string outputDir: pluginData.outputDir || ""
    property string captureSource: pluginData.captureSource || "portal"

    property string recordState: "idle"  // idle | recording | paused
    property int recordTimerSeconds: 0
    property bool _stopRequested: false
    property bool _cooldown: false
    property string _currentOutputFile: ""



    function _formatTime(totalSeconds) {
        var m = Math.floor(totalSeconds / 60)
        var s = totalSeconds % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    Timer {
        id: recordingTimer
        interval: 1000
        repeat: true
        running: root.recordState === "recording"
        onTriggered: root.recordTimerSeconds += 1
    }

    function togglePause() {
        if (root.recordState === "idle") return
        if (root.recordState === "recording") {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGSTOP -f gpu-screen-recorder"])
            root.recordState = "paused"
            ToastService.showInfo("Recording paused")
        } else if (root.recordState === "paused") {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGCONT -f gpu-screen-recorder"])
            root.recordState = "recording"
            ToastService.showInfo("Recording resumed")
        }
    }

    function startRecording() {
        if (root.recordState !== "idle" || root._cooldown) return
        if (typeof pluginService !== "undefined" && pluginService) {
            root.fps = pluginService.loadPluginData(pluginId, "fps", "60") || "60"
            root.quality = pluginService.loadPluginData(pluginId, "quality", "very_high") || "very_high"
            root.recordCursor = pluginService.loadPluginData(pluginId, "recordCursor", true)
            root.recordAudio = pluginService.loadPluginData(pluginId, "recordAudio", true)
            root.captureSource = pluginService.loadPluginData(pluginId, "captureSource", "portal") || "portal"
            root.outputDir = pluginService.loadPluginData(pluginId, "outputDir", "") || ""
        }
        var dir = (root.outputDir || "").replace(/\/$/, "") || "${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasting"
        var cursorFlag = root.recordCursor ? "yes" : "no"
        var audioFlags = root.recordAudio ? " -ac opus -a default_output" : ""
        var now = new Date()
        var dateStr = now.getFullYear() + '-' +
            ('0' + (now.getMonth() + 1)).slice(-2) + '-' +
            ('0' + now.getDate()).slice(-2) + '_' +
            ('0' + now.getHours()).slice(-2) + '-' +
            ('0' + now.getMinutes()).slice(-2) + '-' +
            ('0' + now.getSeconds()).slice(-2)
        var fileName = dateStr + '.mp4'
        root._currentOutputFile = (dir + '/' + fileName).trim()
        var script = "if ! command -v gpu-screen-recorder >/dev/null 2>&1; then exit 127; fi; DIR=\"" + dir.replace(/"/g, '\\"') + "\"; mkdir -p \"$DIR\"; exec gpu-screen-recorder -w " + root.captureSource + " -f " + root.fps + " -k h264" + audioFlags + " -q " + root.quality + " -cursor " + cursorFlag + " -cr limited -o \"$DIR/" + fileName + "\""
        var proc = recorderProcessComponent.createObject(root, { procCommand: ["sh", "-c", script] })
        proc.running = true
        root.recordState = "recording"
        root.recordTimerSeconds = 0
        recordingTimer.start()
        ToastService.showInfo("Recording started. Select area in the Portal.")
    }

    function stopRecording() {
        if (root.recordState === "idle") return
        root._stopRequested = true
        if (root.recordState === "paused") {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGCONT -f gpu-screen-recorder"])
        }
        Quickshell.execDetached(["sh", "-c", "sleep 0.2; pkill -SIGINT -f gpu-screen-recorder; sleep 1.2; pkill -SIGKILL -f gpu-screen-recorder"])
        root.recordState = "idle"
        recordingTimer.stop()
        root.recordTimerSeconds = 0
        root._cooldown = true
        cooldownTimer.start()
        ToastService.showInfo("Recording stopped and saved successfully")
    }

    IpcHandler {
        target: "screenRecorder"

        function startRecording(): string {
            if (root.recordState !== "idle") return "already_recording"
            root.startRecording()
            return "recording_started"
        }

        function stopRecording(): string {
            if (root.recordState === "idle") return "not_recording"
            root.stopRecording()
            return "recording_stopped"
        }

        function toggleRecording(): string {
            if (root.recordState === "idle") {
                root.startRecording()
                return "recording_started"
            } else {
                root.stopRecording()
                return "recording_stopped"
            }
        }

        function togglePause(): string {
            if (root.recordState === "idle") return "not_recording"
            root.togglePause()
            return root.recordState === "paused" ? "recording_paused" : "recording_resumed"
        }
    }

    Timer {
        id: cooldownTimer
        interval: 1500
        repeat: false
        onTriggered: root._cooldown = false
    }

    Component {
        id: recorderProcessComponent
        Process {
            property var procCommand: ["sh", "-c", ""]
            command: procCommand
            onExited: function(exitCode) {
                root.recordState = "idle"
                recordingTimer.stop()
                root.recordTimerSeconds = 0
                if (!root._stopRequested && exitCode !== 0) {
                    if (exitCode === 127) {
                        ToastService.showError("gpu-screen-recorder is not installed or not in PATH.")
                    } else if (root.recordTimerSeconds < 3 && exitCode === 1) {
                        ToastService.showError("Check if xdg-desktop-portal is running and configured correctly.")
                    } else {
                        ToastService.showError("Recording crashed or was cancelled. Exit code: " + exitCode)
                    }
                }
                if (root._stopRequested && root._currentOutputFile) {
                    var postCmd = (root.pluginService.loadPluginData(root.pluginId, "postRecordCommand", "") || "").trim()
                    if (postCmd) {
                        var path = root._currentOutputFile
                        Quickshell.execDetached(["sh", "-c", "set -- \"" + path.replace(/"/g, '\\"') + "\"; " + postCmd])
                    }
                }
                root._stopRequested = false
                root._currentOutputFile = ""
                destroy()
            }
        }
    }
}
