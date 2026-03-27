import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: notifWidget

    readonly property color _surface: "#0f0f0f"
    readonly property color _border:  "#333333"

    property bool expanded: true

    Layout.fillWidth: true
    Layout.preferredHeight: expanded ? 240 : 40
    Behavior on Layout.preferredHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    color:        _surface
    radius:       15
    border.width: 1
    border.color: _border
    clip:         true

    property var notifications: []
    property bool dndActive: false
    property string scriptsPath: Quickshell.env("HOME") + "/.config/quickshell/scripts"

    // Monitor dbus persistente — captura notificaciones en tiempo real
    Process {
        id: notifWatchProc
        command: ["bash", notifWidget.scriptsPath + "/notif_watch.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var n = JSON.parse(data.trim())
                    if (!n.summary) return
                    var list = notifWidget.notifications.slice()
                    list.unshift(n)
                    if (list.length > 30) list = list.slice(0, 30)
                    notifWidget.notifications = list
                } catch(e) {}
            }
        }
    }
    Component.onCompleted: notifWatchProc.running = true

    // Estado DND de swaync
    Process {
        id: swayncProc
        command: ["swaync-client", "-D"]
        stdout: SplitParser {
            onRead: data => { notifWidget.dndActive = data.trim() === "true" }
        }
    }

    Connections {
        target: root
        function onDashboardVisibleChanged() {
            if (root.dashboardVisible) swayncProc.running = true
        }
    }

    Process { id: dndProc;   command: ["swaync-client", "-d"]; onExited: swayncProc.running = true }
    Process { id: clearProc; command: ["swaync-client", "-C"] }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: dndActive ? "󰂛" : "󰂚"
                color: dndActive ? "#555" : "#e0e0e0"
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
            }
            Text {
                text: "Notificaciones" + (notifications.length > 0 ? "  (" + notifications.length + ")" : "")
                color: "#e0e0e0"
                font.pixelSize: 13; font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
            }

            Rectangle {
                visible: expanded
                width: 68; height: 22; radius: 6
                color: dndActive ? "#2a2a2a" : "#1a1a1a"
                border.width: 1; border.color: dndActive ? "#555" : "#252525"
                Text {
                    anchors.centerIn: parent
                    text: dndActive ? "DND ON" : "DND"
                    color: dndActive ? "#888" : "#505050"
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dndProc.running = true }
            }

            Rectangle {
                width: 68; height: 22; radius: 6
                color: "#1a1a1a"
                border.width: 1; border.color: "#252525"
                Text {
                    anchors.centerIn: parent
                    text: "󰆴  limpiar"
                    color: "#505050"
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { notifWidget.notifications = []; clearProc.running = true }
                }
            }

            // Botón colapsar/expandir
            Text {
                text: expanded ? "▲" : "▼"
                color: "#606060"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notifWidget.expanded = !notifWidget.expanded
                }
            }
        }

        Rectangle { visible: expanded; Layout.fillWidth: true; height: 1; color: "#1a1a1a" }

        // Lista
        ScrollView {
            visible: expanded
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            clip: true

            Column {
                width: parent.width
                spacing: 5

                Text {
                    visible: notifications.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Sin notificaciones"
                    color: "#303030"
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    topPadding: 12
                }

                Repeater {
                    model: notifications
                    Rectangle {
                        width: parent.width
                        property bool hasBody: (modelData.body || "") !== ""
                        height: hasBody ? 60 : 38
                        radius: 8
                        color: "#131313"
                        border.width: 1; border.color: "#1e1e1e"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.leftMargin: 12
                            spacing: 2
                            Text { text: modelData.app || ""; color: "#484848"; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                            Text { width: parent.width; text: modelData.summary || ""; color: "#d0d0d0"; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight }
                            Text { visible: (modelData.body || "") !== ""; width: parent.width; text: modelData.body || ""; color: "#686868"; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
}
