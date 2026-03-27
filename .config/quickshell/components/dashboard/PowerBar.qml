import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    property var theme

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    color: theme.surface
    radius: 15
    border.width: 1
    border.color: theme.border

    Row {
        anchors.centerIn: parent
        spacing: 25
        PowerBtn { icon: "⏻"; iconColor: theme.accent;   cmd: "systemctl poweroff" }
        PowerBtn { icon: "󰜉"; iconColor: theme.text;    cmd: "systemctl reboot" }
        PowerBtn { icon: "󰌾"; iconColor: theme.accent;   cmd: "hyprlock" }
        PowerBtn { icon: "󰒲"; iconColor: theme.text;    cmd: "systemctl suspend" }
        PowerBtn { icon: "󰍃"; iconColor: theme.subtext; cmd: "hyprctl dispatch exit" }
        PowerBtn { icon: "󰂚"; iconColor: theme.text;    cmd: "swaync-client --toggle-panel" }
    }

    component PowerBtn: Rectangle {
        property string icon
        property color iconColor
        property string cmd

        width: 40; height: 40; radius: 10
        color: powerMa.containsMouse ? theme.highlight : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: icon
            color: iconColor
            font.pixelSize: 18
            font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea {
            id: powerMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cmdProc.running = true
        }
        Process {
            id: cmdProc
            command: ["bash", "-c", cmd]
        }
    }
}
