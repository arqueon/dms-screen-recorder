import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string recordState: recordStateGlobal.value
    readonly property int recordTimerSeconds: recordTimerGlobal.value
    readonly property string audioMode: audioModeGlobal.value

    property bool _pendingStop: false

    ccWidgetIcon: recordState === "idle" ? "videocam" : (recordState === "paused" ? "play_circle" : "stop_circle")
    ccWidgetPrimaryText: "Screen Recorder"
    ccWidgetSecondaryText: {
        if (recordState === "idle") return "Ready"
        const status = recordState === "paused" ? "Paused" : "Recording"
        return status + " " + _formatTime(recordTimerSeconds)
    }
    ccWidgetIsActive: recordState !== "idle"

    function _audioModeIcon() {
        switch (audioMode) {
        case "system": return "volume_up"
        case "mic": return "mic"
        case "both_merged": return "graphic_eq"
        case "both_tracks": return "layers"
        default: return "volume_off"
        }
    }

    function _formatTime(totalSeconds) {
        var m = Math.floor(totalSeconds / 60)
        var s = totalSeconds % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    function callRecorder(method) {
        Quickshell.execDetached(["dms", "ipc", "call", "screenRecorder", method])
    }

    function startRecording() { callRecorder("startRecording") }
    function stopRecording() { callRecorder("stopRecording") }
    function togglePause() { callRecorder("togglePause") }
    function cycleAudioMode() { callRecorder("cycleAudioMode") }

    onCcWidgetToggled: callRecorder("toggleRecording")

    PluginGlobalVar {
        id: recordStateGlobal
        varName: "recordState"
        defaultValue: "idle"
    }

    PluginGlobalVar {
        id: audioModeGlobal
        varName: "audioMode"
        defaultValue: "system"
    }

    PluginGlobalVar {
        id: recordTimerGlobal
        varName: "recordTimerSeconds"
        defaultValue: 0
    }

    onRecordStateChanged: {
        if (recordState === "idle") {
            _pendingStop = false
            pendingStopTimer.stop()
        }
    }

    Timer {
        id: pendingStopTimer
        interval: 3000
        repeat: false
        onTriggered: root._pendingStop = false
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight || 24

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (root.recordState === "idle") {
                            root.startRecording()
                        } else if (root._pendingStop) {
                            pendingStopTimer.stop()
                            root._pendingStop = false
                            root.stopRecording()
                        } else {
                            root._pendingStop = true
                            pendingStopTimer.restart()
                        }
                    } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        root._pendingStop = false
                        pendingStopTimer.stop()
                        root.togglePause()
                    }
                }
                onWheel: function(wheel) {
                    if (root.recordState === "idle") root.cycleAudioMode()
                }
            }

            Row {
                id: pillRow
                spacing: Theme.spacingS
                anchors.centerIn: parent
                DankIcon {
                    name: root._pendingStop ? "stop_circle" : (root.recordState === "idle" ? "videocam" : (root.recordState === "paused" ? "play_circle" : "stop_circle"))
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: root._pendingStop ? Theme.warningText : (root.recordState === "idle" ? Theme.widgetIconColor : (root.recordState === "paused" ? Theme.warningText : Theme.errorText))
                    anchors.verticalCenter: parent.verticalCenter
                }
                DankIcon {
                    visible: root.recordState === "idle"
                    name: root._audioModeIcon()
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: root.audioMode === "none" ? Theme.surfaceVariantText : Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    visible: root.recordState !== "idle"
                    text: root._pendingStop ? "Stop?" : root._formatTime(root.recordTimerSeconds)
                    color: root._pendingStop ? Theme.warningText : Theme.surfaceText
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
                        if (root.recordState === "idle") {
                            root.startRecording()
                        } else if (root._pendingStop) {
                            pendingStopTimer.stop()
                            root._pendingStop = false
                            root.stopRecording()
                        } else {
                            root._pendingStop = true
                            pendingStopTimer.restart()
                        }
                    } else if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                        root._pendingStop = false
                        pendingStopTimer.stop()
                        root.togglePause()
                    }
                }
                onWheel: function(wheel) {
                    if (root.recordState === "idle") root.cycleAudioMode()
                }
            }

            Column {
                id: pillCol
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                DankIcon {
                    name: root._pendingStop ? "stop_circle" : (root.recordState === "idle" ? "videocam" : (root.recordState === "paused" ? "play_circle" : "stop_circle"))
                    size: Theme.barIconSize(root.barThickness, -2)
                    color: root._pendingStop ? Theme.warningText : (root.recordState === "idle" ? Theme.widgetIconColor : (root.recordState === "paused" ? Theme.warningText : Theme.errorText))
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                DankIcon {
                    visible: root.recordState === "idle"
                    name: root._audioModeIcon()
                    size: Theme.barIconSize(root.barThickness, -6)
                    color: root.audioMode === "none" ? Theme.surfaceVariantText : Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    visible: root.recordState !== "idle"
                    text: root._pendingStop ? "Stop?" : root._formatTime(root.recordTimerSeconds)
                    color: root._pendingStop ? Theme.warningText : Theme.surfaceText
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
