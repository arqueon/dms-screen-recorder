import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string recordState: recordStateGlobal.value
    readonly property int recordTimerSeconds: recordTimerGlobal.value

    property bool _pendingStop: false

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

    PluginGlobalVar {
        id: recordStateGlobal
        varName: "recordState"
        defaultValue: "idle"
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
