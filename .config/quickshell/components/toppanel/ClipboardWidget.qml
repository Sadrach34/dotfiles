import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property bool active: false
    property string lastSnapshot: ""

    color: "#1a1a1a"
    radius: 20
    border.width: 1
    border.color: "#2a2a2a"
    clip: true

    ListModel { id: clipModel }

    function shortText(s) {
        var t = (s || "").trim()
        if (t.length > 140) return t.substring(0, 137) + "..."
        return t
    }

    function shQuote(s) {
        return "'" + (s || "").replace(/'/g, "'\\''") + "'"
    }

    function reloadClipboard() {
        if (loadProc.running) return
        loadProc.buf = ""
        loadProc.running = false
        loadProc.running = true
    }

    function copyEntry(rawLine) {
        if (!rawLine) return
        copyProc.command = [
            "bash", "-lc",
            "printf %s " + shQuote(rawLine) + " | cliphist decode | wl-copy"
        ]
        copyProc.running = false
        copyProc.running = true
    }

    Process {
        id: loadProc
        command: ["bash", "-lc", "cliphist list 2>/dev/null | head -n 80"]
        property string buf: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => loadProc.buf += data }
        onExited: {
            var lines = loadProc.buf.split("\n")
            var cleaned = []
            for (var i = 0; i < lines.length; i++) {
                var raw = lines[i].trim()
                if (!raw) continue
                cleaned.push(raw)
            }

            var snapshot = cleaned.join("\n")
            if (snapshot !== root.lastSnapshot) {
                clipModel.clear()
                for (var j = 0; j < cleaned.length; j++) {
                    var line = cleaned[j]
                    clipModel.append({ rawLine: line, shown: root.shortText(line) })
                }
                root.lastSnapshot = snapshot
            }
            loadProc.buf = ""
        }
    }

    Process { id: copyProc; command: ["true"] }
    Process { id: wipeProc; command: ["bash", "-lc", "cliphist wipe"] }

    Timer {
        id: refreshTimer
        interval: 3500
        repeat: true
        running: root.active
        onTriggered: root.reloadClipboard()
    }

    onActiveChanged: {
        if (active) root.reloadClipboard()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumHeight: 32
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: "#222222"

                Text {
                    anchors.centerIn: parent
                    text: "Portapapeles"
                    color: "#e0e0e0"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.fillHeight: true
                radius: 16
                color: refreshMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "#222222"
                Text {
                    anchors.centerIn: parent
                    text: "\ueca8"
                    font.family: "Phosphor-Bold"
                    font.pixelSize: 16
                    color: "#e0e0e0"
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reloadClipboard()
                }
            }

            Rectangle {
                Layout.preferredWidth: 32
                Layout.fillHeight: true
                radius: 16
                color: wipeMa.containsMouse ? "#f38ba8" : "#222222"
                Text {
                    anchors.centerIn: parent
                    text: "\uec54"
                    font.family: "Phosphor-Bold"
                    font.pixelSize: 16
                    color: wipeMa.containsMouse ? "#1a1a1a" : "#e0e0e0"
                }
                MouseArea {
                    id: wipeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wipeProc.running = false
                        wipeProc.running = true
                        root.reloadClipboard()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: clipModel.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\ueb62"
                    font.family: "Phosphor-Bold"
                    font.pixelSize: 36
                    color: Qt.rgba(1, 1, 1, 0.08)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sin historial"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.2)
                }
            }

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: clipCol.implicitHeight
                clip: true
                visible: clipModel.count > 0

                ColumnLayout {
                    id: clipCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: clipModel

                        delegate: Rectangle {
                            required property var model
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: 10
                            color: rowMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "#222222"
                            border.width: 1
                            border.color: "#2a2a2a"

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: model.shown
                                color: "#e0e0e0"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyEntry(model.rawLine)
                            }
                        }
                    }
                }
            }
        }
    }
}
