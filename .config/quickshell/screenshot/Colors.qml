pragma Singleton
import QtQuick

// Minimal color stub for the screenshot module.
// Uses neutral dark colors — no dependency on ambxst's theme system.
QtObject {
    readonly property color background:       "#1e1e2e"
    readonly property color surface:          "#313244"
    readonly property color primaryFixed:     "#89b4fa"
    readonly property color overBackground:   "#cdd6f4"
    readonly property color primary:          "#89b4fa"
    readonly property color overPrimary:      "#1e1e2e"
    readonly property color secondaryFixedDim:"#313244"
    readonly property color overSecondary:    "#cdd6f4"
    readonly property color overSurface:      "#cdd6f4"
}
