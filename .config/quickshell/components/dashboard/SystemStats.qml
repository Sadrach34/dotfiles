import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    property var theme
    property bool dashboardVisible

    Layout.fillWidth: true
    Layout.preferredHeight: 110
    color: theme.surface
    radius: 15
    border.width: 1
    border.color: theme.border

    property int cpuVal: 0
    property int ramVal: 0
    property int diskVal: 0

    Timer {
        interval: 2000
        running: dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running)  cpuProc.running  = true
            if (!ramProc.running)  ramProc.running  = true
            if (!diskProc.running) diskProc.running = true
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 30
        CircularStat { label: "CPU";  icon: ""; barColor: theme.accent;   value: cpuVal }
        CircularStat { label: "RAM";  icon: ""; barColor: theme.text;    value: ramVal }
        CircularStat { label: "DISK"; icon: ""; barColor: theme.subtext; value: diskVal }
    }

    component CircularStat: Item {
        property string label
        property string icon
        property color barColor
        property int value

        width: 90; height: 110

        Column {
            anchors.centerIn: parent
            spacing: 8

            Item {
                width: 70; height: 70
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    anchors.fill: parent
                    property int statValue: value
                    onStatValueChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.lineWidth = 5
                        ctx.lineCap = "round"
                        ctx.strokeStyle = theme.border
                        ctx.beginPath()
                        ctx.arc(35, 35, 32, 0, 2 * Math.PI)
                        ctx.stroke()
                        ctx.strokeStyle = barColor
                        ctx.beginPath()
                        ctx.arc(35, 35, 32, -Math.PI / 2, -Math.PI / 2 + (statValue / 100) * 2 * Math.PI)
                        ctx.stroke()
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: icon
                        color: barColor
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: value + "%"
                        color: theme.text
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: label
                color: theme.subtext
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }

    Process {
        id: cpuProc
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print int($2 + $4)}'"]
        stdout: SplitParser { onRead: data => cpuVal = parseInt(data) || 0 }
    }
    Process {
        id: ramProc
        command: ["bash", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2*100}'"]
        stdout: SplitParser { onRead: data => ramVal = parseInt(data) || 0 }
    }
    Process {
        id: diskProc
        command: ["bash", "-c", "df / | awk 'NR==2 {gsub(/%/,\"\"); print $5}'"]
        stdout: SplitParser { onRead: data => diskVal = parseInt(data) || 0 }
    }
}
