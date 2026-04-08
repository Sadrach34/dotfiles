import QtQuick
import QtQuick.Shapes
import ".."

Row {
    id: root
    property var colors
    property string label: ""
    property bool checked: false
    property var onToggle
    readonly property string _customBgRaw: (Config.wallpaperFilterBarBgColor || "").trim()
    readonly property bool _hasCustomBg: _customBgRaw.length > 0
    readonly property color _customBgColor: _hasCustomBg ? _customBgRaw : "transparent"
    readonly property real _customLuma: (_customBgColor.r * 0.2126) + (_customBgColor.g * 0.7152) + (_customBgColor.b * 0.0722)
    readonly property real _customAlpha: _customBgColor.a > 0 ? _customBgColor.a : 1.0
    readonly property color _customActiveColor: (_customLuma < 0.08)
        ? Qt.rgba(0.84, 0.84, 0.84, _customAlpha)
        : (_customLuma > 0.92
            ? Qt.rgba(0.24, 0.24, 0.24, _customAlpha)
            : (_customLuma < 0.45 ? Qt.lighter(_customBgColor, 1.45) : Qt.darker(_customBgColor, 1.55)))
    readonly property real _activeLuma: (_customActiveColor.r * 0.2126) + (_customActiveColor.g * 0.7152) + (_customActiveColor.b * 0.0722)
    readonly property color _customActiveTextColor: _activeLuma > 0.58 ? "#111111" : "#ffffff"

    width: parent ? parent.width : 0
    height: 28
    spacing: 8

    property real _skew: 4

    Item {
        id: track
        width: 40
        height: 20
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            anchors.fill: parent
            ShapePath {
                fillColor: root.checked
                    ? (root._hasCustomBg
                        ? root._customActiveColor
                        : (root.colors ? root.colors.primary : Style.fallbackAccent))
                    : (root._hasCustomBg
                        ? Qt.rgba(root._customBgColor.r, root._customBgColor.g, root._customBgColor.b, Math.max(root._customBgColor.a, 0.6))
                        : (root.colors ? Qt.rgba(root.colors.surfaceVariant.r, root.colors.surfaceVariant.g, root.colors.surfaceVariant.b, 0.6) : Qt.rgba(0.3, 0.3, 0.35, 0.6)))
                strokeColor: root.checked
                    ? (root._hasCustomBg
                        ? Qt.rgba(root._customActiveColor.r, root._customActiveColor.g, root._customActiveColor.b, 0.85)
                        : (root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.8) : Style.fallbackAccent))
                    : (root.colors ? Qt.rgba(root.colors.outline.r, root.colors.outline.g, root.colors.outline.b, 0.3) : Qt.rgba(1, 1, 1, 0.1))
                strokeWidth: 1
                startX: root._skew; startY: 0
                PathLine { x: track.width;               y: 0 }
                PathLine { x: track.width - root._skew;  y: track.height }
                PathLine { x: 0;                          y: track.height }
                PathLine { x: root._skew;                y: 0 }
            }
        }

        Item {
            id: thumb
            width: 16
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutCubic } }

            Shape {
                anchors.fill: parent
                ShapePath {
                    fillColor: root.checked
                        ? (root._hasCustomBg ? root._customActiveTextColor : (root.colors ? root.colors.primaryText : "#000"))
                        : (root.colors ? Qt.rgba(root.colors.surfaceText.r, root.colors.surfaceText.g, root.colors.surfaceText.b, 0.7) : Qt.rgba(1, 1, 1, 0.5))
                    strokeWidth: 0
                    startX: root._skew * 0.6; startY: 0
                    PathLine { x: thumb.width;                     y: 0 }
                    PathLine { x: thumb.width - root._skew * 0.6;  y: thumb.height }
                    PathLine { x: 0;                                y: thumb.height }
                    PathLine { x: root._skew * 0.6;               y: 0 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (root.onToggle) root.onToggle(!root.checked) }
        }
    }

    Text {
        text: root.label
        anchors.verticalCenter: parent.verticalCenter
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: root.colors ? root.colors.tertiary : Qt.rgba(1, 1, 1, 0.5)
    }
}
