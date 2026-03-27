pragma ComponentBehavior: Bound
import QtQuick

// Simplified StyledRect stub — just a colored Rectangle with a variant property.
// Replaces ambxst's full StyledRect (gradient/halftone/shader version).
Rectangle {
    id: root
    required property string variant

    clip: true
    antialiasing: true

    color: {
        switch (variant) {
        case "overprimary":   return "#2289b4fa"
        case "primary":       return "#89b4fa"
        case "primaryfocus":  return "#6fa0e8"
        case "focus":         return "#3a3a4e"
        case "common":        return "#2a2a3e"
        case "pane":          return "#252535"
        case "popup":         return "#1a1a2e"
        case "error":         return "#f38ba8"
        case "errorfocus":    return "#e06c8a"
        case "overerror":     return "#f38ba8"
        default:              return "#2a2a3e"
        }
    }
}
