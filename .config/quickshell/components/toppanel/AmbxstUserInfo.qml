// AmbxstUserInfo.qml — port 1:1 de ambxst/modules/widgets/defaultview/UserInfo.qml
// Avatar 24×24 + texto user@host (oculto por defecto, igual que ambxst)
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: avatarClip.width
    implicitHeight: 40

    // ── Nombre del host via Process (igual que ambxst) ───────────────────────
    Process {
        id: hostnameProcess
        command: ["hostname"]
        running: true

        stdout: StdioCollector {
            id: hostnameCollector
            waitForEnd: true
        }
    }

    MouseArea {
        id: userHostArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Avatara: rectángulo recortado con imagen ~/.face.icon
            Item {
                width:  24
                height: 24

                Rectangle {
                    id: avatarClip
                    anchors.centerIn: parent
                    width:  24
                    height: 24
                    radius: 16      // Styling.radius(0) en ambxst
                    clip:   true
                    color:  "#2a2a2a"   // fondo mientras carga la imagen

                    Image {
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.face.icon"
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            // Texto user@host — visible: false igual que ambxst
            Text {
                id: userHostText
                anchors.verticalCenter: parent.verticalCenter
                text:  Quickshell.env("USER") + "@" + hostnameCollector.text.trim()
                color: userHostArea.pressed
                    ? "#e0e0e0"
                    : (userHostArea.containsMouse ? "#89b4fa" : "#e0e0e0")
                font.family:    "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight:    Font.Bold
                elide:  Text.ElideRight
                width:  Math.min(implicitWidth, 180 - 24 - 8)
                visible: false      // mismo que ambxst: solo muestra el avatar

                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }
    }
}
