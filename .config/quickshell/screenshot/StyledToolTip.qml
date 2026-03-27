pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Minimal StyledToolTip stub.
ToolTip {
    id: root
    property string tooltipText: ""
    property bool show: false

    text: tooltipText
    delay: 1000
    timeout: -1
    visible: show && tooltipText.length > 0

    background: Rectangle {
        color: "#1a1a2e"
        radius: 6
        border.color: "#313244"
        border.width: 1
    }
    contentItem: Text {
        text: root.tooltipText
        color: "#cdd6f4"
        font.pixelSize: 13
        font.weight: Font.Bold
    }
}
