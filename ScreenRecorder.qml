import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string fps: pluginData.fps || "60"
    property string quality: pluginData.quality || "very_high"
    property bool recordCursor: pluginData.recordCursor !== undefined ? pluginData.recordCursor : true
    property string outputDir: pluginData.outputDir || ""
    property string captureSource: pluginData.captureSource || "portal"

    property string recordState: "idle"  // idle | recording | paused
    property int recordTimerSeconds: 0
    property bool _stopRequested: false
    property bool _cooldown: false

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

    onCcWidgetToggled: {
        if (root.recordState === "idle") {
            startRecording()
            if (typeof PopoutService !== "undefined" && PopoutService) PopoutService.closeControlCenter()
        } else {
            stopRecording()
            if (typeof PopoutService !== "undefined" && PopoutService) PopoutService.closeControlCenter()
        }
    }

    function togglePause() {
        if (root.recordState === "idle") return
        if (root.recordState === "recording") {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGSTOP -f gpu-screen-recorder"])
            root.recordState = "paused"
            ToastService.showInfo("Screen Recorder", "Grabación pausada")
        } else if (root.recordState === "paused") {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGCONT -f gpu-screen-recorder"])
            root.recordState = "recording"
            ToastService.showInfo("Screen Recorder", "Grabación reanudada")
        }
    }

    function startRecording() {
        if (root.recordState !== "idle" || root._cooldown) return
        if (typeof pluginService !== "undefined" && pluginService) {
            root.fps = pluginService.loadPluginData(pluginId, "fps", "60") || "60"
            root.quality = pluginService.loadPluginData(pluginId, "quality", "very_high") || "very_high"
            root.recordCursor = pluginService.loadPluginData(pluginId, "recordCursor", true)
        }
        var dir = (outputDir || "").replace(/\/$/, "") || "${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasting"
        var cursorFlag = root.recordCursor ? "yes" : "no"
        var script = "DIR=\"" + dir.replace(/"/g, '\\"') + "\"; mkdir -p \"$DIR\"; FILE=\"$DIR/$(date +'%Y-%m-%d_%H-%M-%S').mp4\"; exec gpu-screen-recorder -w " + captureSource + " -f " + root.fps + " -k h264 -ac opus -a default_output -q " + root.quality + " -cursor " + cursorFlag + " -cr limited -o \"$FILE\""
        var proc = recorderProcessComponent.createObject(root, { procCommand: ["sh", "-c", script] })
        proc.running = true
        root.recordState = "recording"
        root.recordTimerSeconds = 0
        recordingTimer.start()
        ToastService.showInfo("Screen Recorder", "Selecciona en el Portal. Clic en el icono para detener.")
    }

    function stopRecording() {
        if (root.recordState === "idle") return
        root._stopRequested = true
        if (root.recordState === "paused") {
            Quickshell.execDetached(["sh", "-c", "pkill -SIGCONT -f gpu-screen-recorder"])
        }
        // SIGINT para guardar el MP4; luego SIGKILL para cerrar el Portal si sigue abierto
        Quickshell.execDetached(["sh", "-c", "sleep 0.2; pkill -SIGINT -f gpu-screen-recorder; sleep 1.2; pkill -SIGKILL -f gpu-screen-recorder"])
        root.recordState = "idle"
        recordingTimer.stop()
        root.recordTimerSeconds = 0
        root._cooldown = true
        cooldownTimer.start()
        ToastService.showInfo("Screen Recorder", "Guardado")
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
                    ToastService.showInfo("Screen Recorder", "Grabación cancelada")
                }
                root._stopRequested = false
                destroy()
            }
        }
    }

    ccWidgetIcon: root.recordState === "idle" ? "videocam" : (root.recordState === "recording" ? "stop_circle" : "pause_circle")
    ccWidgetPrimaryText: "Screen Recorder"
    ccWidgetSecondaryText: {
        if (root.recordState === "idle") return "Listo"
        if (root.recordState === "paused") return "Pausado · " + _formatTime(root.recordTimerSeconds)
        return "Grabando · " + _formatTime(root.recordTimerSeconds)
    }
    ccWidgetIsActive: root.recordState !== "idle"

    horizontalBarPill: Component {
        Item {
            width: pillRow.width
            implicitHeight: pillRow.height || 24

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (root.recordState === "idle") startRecording()
                        else stopRecording()
                    } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        root.togglePause()
                    }
                }
            }

            Row {
                id: pillRow
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                DankIcon {
                    name: root.recordState === "idle" ? "videocam" : (root.recordState === "recording" ? "stop_circle" : "pause_circle")
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: root.recordState === "idle" ? Theme.widgetIconColor : (root.recordState === "recording" ? Theme.errorText : Theme.warningText)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    visible: root.recordState !== "idle"
                    text: root._formatTime(root.recordTimerSeconds)
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            width: parent.width || 24
            implicitHeight: pillCol.height

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (root.recordState === "idle") startRecording()
                        else stopRecording()
                    } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        root.togglePause()
                    }
                }
            }

            Column {
                id: pillCol
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                DankIcon {
                    name: root.recordState === "idle" ? "videocam" : (root.recordState === "recording" ? "stop_circle" : "pause_circle")
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: root.recordState === "idle" ? Theme.widgetIconColor : (root.recordState === "recording" ? Theme.errorText : Theme.warningText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    visible: root.recordState !== "idle"
                    text: root._formatTime(root.recordTimerSeconds)
                    color: Theme.surfaceText
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
