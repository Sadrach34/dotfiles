import Quickshell
import Quickshell.Wayland
import QtQuick

// Overlay de pantalla completa para cerrar paneles al hacer click fuera.
// Capa WlrLayer.Top → SIEMPRE por debajo de los paneles (WlrLayer.Overlay),
// pero ENCIMA de ventanas normales. Funciona aunque haya un browser o terminal
// abierto debajo.
PanelWindow {
    id: overlay

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    WlrLayershell.layer: WlrLayer.Top

    // Solo activo cuando algún panel está abierto
    visible: root.dashboardVisible || root.topPanelVisible

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.dashboardVisible = false
            root.topPanelVisible  = false
        }
    }
}
