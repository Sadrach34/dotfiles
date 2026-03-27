pragma Singleton
import QtQuick

// Minimal Styling stub for the screenshot module.
QtObject {
    function radius(offset) {
        return Math.max(12 + offset, 0)
    }

    function srItem(variant) {
        switch (variant) {
        case "overprimary":   return "#89b4fa"
        case "primary":       return "#89b4fa"
        case "focus":         return "#45475a"
        case "error":         return "#f38ba8"
        case "overerror":     return "#f38ba8"
        default:              return "#cdd6f4"
        }
    }

    function getStyledRectConfig(variant) { return {} }
}
