import QtQuick
import Quickshell
import Quickshell.Wayland

// Indicador flotante de grabación activa.
// Visible mientras ScreenRecorder.isRecording sea true.
// Muestra temporizador + botón de parar.
PanelWindow {
    id: root

    required property var targetScreen
    screen: targetScreen

    // Anclar esquina superior-derecha
    anchors.top: true
    anchors.right: true

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.margins {
        top: 40
        right: 16
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: ScreenRecorder.isRecording

    Rectangle {
        id: pill
        anchors.fill: parent
        implicitWidth: row.implicitWidth + 20
        implicitHeight: row.implicitHeight + 14

        radius: Styling.radius(20)
        color: Colors.background
        border.color: Colors.surface
        border.width: 1

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            // Punto rojo pulsante
            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: "#ef4444"

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: ScreenRecorder.isRecording
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            // Etiqueta REC + tiempo
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ScreenRecorder.duration !== "" ? "REC  " + ScreenRecorder.duration : "REC"
                font.family: Config.defaultFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Colors.overBackground
            }

            // Separador
            Rectangle {
                width: 1
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.surface
            }

            // Botón stop
            Rectangle {
                id: stopBtn
                width: 28
                height: 28
                radius: Styling.radius(4)
                anchors.verticalCenter: parent.verticalCenter
                color: stopHover.containsMouse ? "#ef4444" : "transparent"

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: Icons.stop
                    font.family: Icons.font
                    font.pixelSize: 16
                    color: stopHover.containsMouse ? "white" : "#ef4444"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                StyledToolTip {
                    show: stopHover.containsMouse
                    tooltipText: "Detener grabación"
                }

                MouseArea {
                    id: stopHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ScreenRecorder.stopRecording()
                }
            }
        }
    }
}
