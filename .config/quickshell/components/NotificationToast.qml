import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Toast de notificaciones — esquina superior derecha
// Se alimenta del mismo notif_watch.sh, independiente del TopPanel
PanelWindow {
    id: toast

    anchors { top: true; right: true }
    implicitWidth: 300
    implicitHeight: toastBody !== "" ? 74 : 54
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    WlrLayershell.layer: WlrLayer.Overlay

    // Espacio para no solapar waybar (~40px) + margen extra
    margins.top: 52

    property bool showing: false
    property var  _pending: null
    property string toastApp: ""
    property string toastSummary: ""
    property string toastBody: ""
    property string scriptsPath: Quickshell.env("HOME") + "/.config/quickshell/scripts"

    // Slide desde/hacia la derecha
    margins.right: showing ? 10 : -(implicitWidth + 20)
    Behavior on margins.right {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: toast.showing = false
    }

    // Comprueba DND exactamente cuando llega la notificación (sin depender de timer)
    Process {
        id: dndCheckProc
        command: ["swaync-client", "-D"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "true") toast._pending = null  // DND activo — descartar
            }
        }
        onExited: {
            if (toast._pending !== null) {
                toast.toastApp     = toast._pending.app     || ""
                toast.toastSummary = toast._pending.summary || ""
                toast.toastBody    = toast._pending.body    || ""
                toast.showing      = true
                hideTimer.restart()
                toast._pending = null
            }
        }
    }

    Process {
        id: watchProc
        command: ["bash", toast.scriptsPath + "/notif_watch.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var n = JSON.parse(data.trim())
                    if (!n.summary) return
                    toast._pending = n
                    dndCheckProc.running = false
                    dndCheckProc.running = true
                } catch(e) {}
            }
        }
    }
    Component.onCompleted: watchProc.running = true

    // Ejecuta acciones al hacer click en el toast
    Process { id: openAction }

    Rectangle {
        anchors.fill: parent
        color: "#0f0f0f"
        radius: 12
        border.width: 1
        border.color: "#2a2a2a"
        opacity: toast.showing ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Barra de acento izquierda
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            anchors.topMargin: 8; anchors.bottomMargin: 8
            width: 3; radius: 2
            color: "#6272a4"
        }

        // Icono: cámara para screenshots, campana para el resto
        Text {
            id: bellIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: (toast.toastSummary.toLowerCase().indexOf("screenshot") !== -1
                   || toast.toastBody.toLowerCase().indexOf("swappy") !== -1)
                  ? "󰄄" : "󰂚"
            color: "#6272a4"
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
        }

        // Textos
        Column {
            anchors.left: bellIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: toast.toastApp
                color: "#484848"
                font.pixelSize: 9
                font.family: "JetBrainsMono Nerd Font"
                visible: toast.toastApp !== ""
            }
            Text {
                width: parent.width
                text: toast.toastSummary
                color: "#e0e0e0"
                font.pixelSize: 12; font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: toast.toastBody
                color: "#686868"
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
                visible: toast.toastBody !== ""
            }
        }

        // Click: ejecuta acción según tipo de notificación
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                hideTimer.stop()
                toast.showing = false
                var body = (toast.toastBody    || "").toLowerCase()
                var sum  = (toast.toastSummary || "").toLowerCase()
                if (sum.indexOf("screenshot") !== -1 || body.indexOf("screenshot") !== -1
                        || body.indexOf("swappy") !== -1) {
                    if (body.indexOf("swappy") !== -1) {
                        // Captura swappy: la imagen está en el portapapeles
                        openAction.command = ["bash", "-c",
                            "wl-paste > /tmp/qs_shot.png && swappy -f /tmp/qs_shot.png"]
                        openAction.running = true
                    } else if (body.indexOf("saved") !== -1 || body.indexOf("guardad") !== -1) {
                        // Captura guardada: abrir el PNG más reciente
                        openAction.command = ["bash", "-c",
                            "f=$(ls -t \"${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots\"/*.png 2>/dev/null | head -1); [ -n \"$f\" ] && xdg-open \"$f\""]
                        openAction.running = true
                    }
                }
            }
        }
    }
}
