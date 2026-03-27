// QuickControls — port 1:1 de ambxst's QuickControls.qml + ControlButton.qml
// 5 botones: WiFi, Bluetooth, NightLight, Caffeine, GameMode
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string gmNewScript: Quickshell.env("HOME") + "/.config/hypr/scripts/GMnew"

    function desiredScheduler() {
        if (cafBtn.cafActive) return "lavd"
        if (gmBtn.gmActive) return "flash"
        return "bpfland"
    }

    function applyScheduler() {
        var target = desiredScheduler()
        schedulerProc.command = ["scxctl", "switch", "--sched", target]
        schedulerProc.running = false
        schedulerProc.running = true
    }

    // ── Colores inline (equivalentes a qs.modules.theme) ───────────────────
    readonly property color clrPane:         "#1a1a1a"
    readonly property color clrInBg:         "#222222"
    readonly property color clrBorder:       "#2a2a2a"
    readonly property color clrText:         "#e0e0e0"    // Colors.overBackground
    readonly property color clrPrimary:      "#89b4fa"    // Colors.primary
    readonly property color clrOverPrimary:  "#1a1a2e"    // texto sobre fondo primary
    readonly property color clrPrimaryFocus: Qt.rgba(0.537, 0.706, 0.980, 0.4) // variant:"primaryfocus"
    readonly property color clrFocus:        Qt.rgba(1, 1, 1, 0.08)            // variant:"focus"
    readonly property string fnt:            "Phosphor-Bold"

    implicitWidth:  btnRow.implicitWidth + 16
    implicitHeight: btnRow.implicitHeight + 16

    // ── Pane exterior (StyledRect variant:"pane") ────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:  root.clrPane
        radius: 20
        border.width: 1
        border.color: root.clrBorder

        // ── Fondo interno (StyledRect variant:"internalbg") ──────────────────
        Rectangle {
            anchors.centerIn: parent
            implicitWidth:  btnRow.implicitWidth  + 8
            implicitHeight: btnRow.implicitHeight + 8
            width:  implicitWidth
            height: implicitHeight
            color:  root.clrInBg
            radius: 16

            RowLayout {
                id: btnRow
                anchors.centerIn: parent
                spacing: 4

                // ── WiFi ─────────────────────────────────────────────────────
                ControlBtn {
                    id: wifiBtn
                    property bool wifiEnabled: true
                    iconText: {
                        if (!wifiEnabled) return "\ue4f2" // wifiOff
                        return "\ue4ea"                   // wifiHigh (simplificado)
                    }
                    isActive:    wifiEnabled
                    tooltipText: wifiEnabled ? "Wi-Fi: On" : "Wi-Fi: Off"
                    onBtnClicked: { wifiToggleProc.command = ["bash", "-c", wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"]; wifiToggleProc.running = true }

                    Process {
                        id: wifiStateProc
                        command: ["bash", "-c", "nmcli radio wifi"]
                        stdout: SplitParser { onRead: data => wifiBtn.wifiEnabled = data.trim() === "enabled" }
                        Component.onCompleted: running = true
                    }
                    Process { id: wifiToggleProc; onExited: wifiStateProc.running = true }
                }

                // ── Bluetooth ─────────────────────────────────────────────────
                ControlBtn {
                    id: btBtn
                    property bool btEnabled: false
                    iconText: btEnabled ? "\ue0da" : "\ue0de" // bluetooth : bluetoothOff
                    isActive:    btEnabled
                    tooltipText: btEnabled ? "Bluetooth: On" : "Bluetooth: Off"
                    onBtnClicked: { btToggleProc.command = ["bash", "-c", btEnabled ? "bluetoothctl power off" : "bluetoothctl power on"]; btToggleProc.running = true }

                    Process {
                        id: btStateProc
                        command: ["bash", "-c", "bluetoothctl show | grep -i 'powered: yes'"]
                        stdout: SplitParser { onRead: data => btBtn.btEnabled = data.trim().length > 0 }
                        Component.onCompleted: running = true
                    }
                    Process { id: btToggleProc; onExited: btStateProc.running = true }
                }

                // ── Night Light ───────────────────────────────────────────────
                ControlBtn {
                    id: nightBtn
                    property bool nightActive: false
                    iconText:    "\ue330" // nightLight
                    isActive:    nightActive
                    tooltipText: nightActive ? "Night Light: On" : "Night Light: Off"
                    onBtnClicked: {
                        nightActive = !nightActive
                        nightProc.command = ["bash", "-c", nightActive
                            ? "hyprctl hyprsunset temperature 3500 || wlsunset -T 3500 &"
                            : "hyprctl hyprsunset off || pkill wlsunset"]
                        nightProc.running = true
                    }
                    Process { id: nightProc }
                }

                // ── Caffeine (inhibit sleep) ───────────────────────────────────
                ControlBtn {
                    id: cafBtn
                    property bool cafActive: false
                    property var  cafPid: null
                    iconText:    "\ue1c2" // caffeine
                    isActive:    cafActive
                    tooltipText: cafActive ? "Caffeine: On" : "Caffeine: Off"
                    onBtnClicked: {
                        if (!cafActive) {
                            cafActive = true
                            cafStartProc.running = true
                        } else {
                            cafActive = false
                            cafStopProc.running = true
                        }
                        root.applyScheduler()
                    }
                    Process { id: cafStartProc; command: ["bash", "-c", "systemd-inhibit --what=idle --mode=block --who=quickshell --why=caffeine sleep infinity &"] }
                    Process { id: cafStopProc;  command: ["bash", "-c", "pkill -f 'sleep infinity'"] }
                }

                // ── Game Mode ─────────────────────────────────────────────────
                ControlBtn {
                    id: gmBtn
                    property bool gmActive: false
                    iconText:    "\ue26e" // gameMode
                    isActive:    gmActive
                    tooltipText: gmActive ? "Game Mode: On" : "Game Mode: Off"
                    onBtnClicked: {
                        gmToggleProc.command = ["bash", root.gmNewScript, "toggle"]
                        gmToggleProc.running = true
                    }

                    Process {
                        id: gmToggleProc
                        command: ["true"]
                        onExited: gmStateProc.running = true
                    }

                    Process {
                        id: gmStateProc
                        command: ["bash", root.gmNewScript, "status"]
                        stdout: SplitParser {
                            onRead: data => {
                                gmBtn.gmActive = data.trim() === "on"
                            }
                        }
                    }

                    Component.onCompleted: gmStateProc.running = true
                }
            }
        }
    }

    Process {
        id: schedulerProc
        command: ["true"]
    }

    // Evita prompts de autenticacion al reiniciar quickshell.
    // El scheduler se cambia solo cuando el usuario toca Caffeine/GameMode.

    // ── Componente: ControlButton (1:1 port de ambxst's ControlButton.qml) ──
    component ControlBtn: Item {
        id: cb

        property string iconText:    ""
        property bool   isActive:    false
        property string tooltipText: ""
        signal btnClicked
        signal btnRightClicked
        signal btnLongPressed

        property bool isHovered: cbArea.containsMouse

        Layout.preferredWidth:  48
        Layout.preferredHeight: 48

        // Color de fondo según variante
        readonly property color bgColor: {
            if (isActive && isHovered) return root.clrPrimaryFocus
            if (isActive)              return root.clrPrimary
            if (isHovered)             return root.clrFocus
            return "transparent"
        }
        // Color del icono
        readonly property color textColor: {
            if (isActive && isHovered) return root.clrPrimary
            if (isActive)              return root.clrOverPrimary
            return root.clrText
        }
        // Radio: cuadrado cuando activo (Styling.radius(0)=16), redondeado cuando no (Styling.radius(4)=20)
        readonly property real btnRadius: isActive ? 16 : 20

        Rectangle {
            anchors.fill: parent
            radius: parent.btnRadius
            color:  parent.bgColor
            Behavior on color  { ColorAnimation { duration: 120; easing.type: Easing.OutQuart } }
            Behavior on radius { NumberAnimation { duration: 120; easing.type: Easing.OutQuart } }
        }

        Text {
            anchors.centerIn: parent
            text:            cb.iconText
            font.family:     root.fnt
            font.pixelSize:  18
            color:           cb.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutQuart } }
        }

        MouseArea {
            id: cbArea
            anchors.fill:          parent
            acceptedButtons:       Qt.LeftButton | Qt.RightButton
            hoverEnabled:          true
            pressAndHoldInterval:  1000
            cursorShape:           Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) cb.btnRightClicked()
                else                                  cb.btnClicked()
            }
            onPressAndHold: cb.btnLongPressed()
        }

        ToolTip {
            visible: cbArea.containsMouse && cb.tooltipText.length > 0
            text:    cb.tooltipText
            delay:   600
        }
    }
}
