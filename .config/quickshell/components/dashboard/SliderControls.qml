import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    property var theme
    property bool dashboardVisible

    Layout.fillWidth: true
    Layout.preferredHeight: 55
    color: theme.surface
    radius: 15
    border.width: 1
    border.color: theme.border

    property int volVal: 50

    Timer {
        interval: 2000
        running: dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!volProc.running) volProc.running = true }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Volume
        Row {
            width: parent.width
            spacing: 10
            Text {
                width: 25; height: 24
                text: volVal == 0 ? "󰝟" : volVal < 50 ? "󰖀" : "󰕾"
                color: theme.accent
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                verticalAlignment: Text.AlignVCenter
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: volMuteProc.running = true
                }
                Process {
                    id: volMuteProc
                    command: ["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
                    onExited: volProc.running = true
                }
            }
            Rectangle {
                width: parent.width - 75; height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: theme.border
                Rectangle {
                    width: parent.width * volVal / 100
                    height: parent.height; radius: 4
                    color: theme.accent
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        var pct = Math.max(0, Math.min(100, Math.round((mouse.x / parent.width) * 100)))
                        volVal = pct
                        volSetProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (pct / 100).toFixed(2)]
                        volSetProc.running = true
                    }
                    onPositionChanged: function(mouse) {
                        if (pressed) {
                            var pct = Math.max(0, Math.min(100, Math.round((mouse.x / parent.width) * 100)))
                            volVal = pct
                            volSetProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (pct / 100).toFixed(2)]
                            volSetProc.running = true
                        }
                    }
                }
                Process { id: volSetProc }
            }
            Text {
                width: 40; height: 24
                text: volVal + "%"
                color: theme.subtext
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%.0f\", $2*100}'"]
        stdout: SplitParser { onRead: data => volVal = parseInt(data) || 0 }
    }
}
