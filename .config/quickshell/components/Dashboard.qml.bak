import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "./dashboard"
import "./toppanel"

PanelWindow {
    id: dashboard
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; right: true }
    margins { top: 40; bottom: 10; right: root.dashboardVisible ? 6 : -450 }
    implicitWidth: 420
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: root.dashboardVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    Behavior on margins.right { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property string configPath: Quickshell.env("HOME") + "/.config/quickshell"

    DashTheme { id: theme }

    Item {
        anchors.fill: parent
        focus: root.dashboardVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (profileSection.pfpPickerOpen) {
                    profileSection.pfpPickerOpen = false
                } else {
                    root.dashboardVisible = false
                }
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            color: theme.background
            radius: 20
            border.width: 1
            border.color: theme.border

            MouseArea {
                anchors.fill: parent
                visible: profileSection.pfpPickerOpen
                onClicked: profileSection.pfpPickerOpen = false
                z: 50
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 20
                contentHeight: contentCol.implicitHeight
                clip: true
                z: 100

                ColumnLayout {
                    id: contentCol
                    width: parent.width
                    spacing: 8

                    // ── Foto de perfil, nombre de usuario y tiempo de actividad ──
                    ProfileSection {
                        id: profileSection
                        theme: theme
                        configPath: dashboard.configPath
                        dashboardVisible: root.dashboardVisible
                    }

                    // ── Botones de acciones: apagar, reiniciar, bloquear, suspender, salir ──
                    PowerBar {
                        theme: theme
                    }

// ── Notificaciones del sistema ──
                      NotificationsWidget {
                          Layout.fillWidth: true
                    }

                    // ── Reproductor de música con playerctl + GIF animado ──
                    MusicPlayer {
                        theme: theme
                        configPath: dashboard.configPath
                        dashboardVisible: root.dashboardVisible
                    }

                    // ── Control de volumen del sistema via wpctl ──
                    SliderControls {
                        theme: theme
                        dashboardVisible: root.dashboardVisible
                    }

                    // ── Uso de CPU, RAM y disco en tiempo real con gráficas circulares ──
                    SystemStats {
                        theme: theme
                        dashboardVisible: root.dashboardVisible
                    }

                    // ── Reloj digital + calendario mensual navegable ──
                    ClockWidget {
                        theme: theme
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onDashboardVisibleChanged() {
            if (root.dashboardVisible) focusTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 50; repeat: false
        onTriggered: {
            dashboard.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            releaseTimer.start()
        }
    }
    Timer {
        id: releaseTimer
        interval: 100; repeat: false
        onTriggered: {
            dashboard.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
        }
    }
}
