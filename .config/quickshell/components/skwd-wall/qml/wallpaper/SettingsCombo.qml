import QtQuick
import ".."

Column {
    id: root
    property var colors
    property string label: ""
    property string value: ""
    property var model: []
    property var onSelect
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
    readonly property real _customActiveLuma: (_customActiveColor.r * 0.2126) + (_customActiveColor.g * 0.7152) + (_customActiveColor.b * 0.0722)
    readonly property color _customActiveTextColor: _customActiveLuma > 0.58 ? "#111111" : "#ffffff"

    width: parent ? parent.width : 0
    spacing: 2

    Text {
        text: root.label
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: root.colors ? root.colors.tertiary : Qt.rgba(1, 1, 1, 0.5)
    }

    Flow {
        width: parent.width
        spacing: 4

        Repeater {
            model: root.model
            Item {
                width: _comboLabel.implicitWidth + 24 + 8
                height: 26
                z: _comboIsActive ? 10 : (_comboMouse.containsMouse ? 5 : 1)

                property bool _comboIsActive: root.value === modelData

                Canvas {
                    id: _comboCanvas
                    anchors.fill: parent

                    property color fillColor: parent._comboIsActive
                        ? (root._hasCustomBg
                            ? root._customActiveColor
                            : (root.colors ? root.colors.primary : Style.fallbackAccent))
                        : (_comboMouse.containsMouse
                            ? (root.colors ? Qt.rgba(root.colors.surfaceVariant.r, root.colors.surfaceVariant.g, root.colors.surfaceVariant.b, 0.6) : Qt.rgba(1, 1, 1, 0.15))
                            : (root._hasCustomBg
                                ? Qt.rgba(root._customBgColor.r, root._customBgColor.g, root._customBgColor.b, Math.max(root._customBgColor.a, 0.85))
                                : (root.colors ? Qt.rgba(root.colors.surfaceContainer.r, root.colors.surfaceContainer.g, root.colors.surfaceContainer.b, 0.85) : Qt.rgba(0.1, 0.12, 0.18, 0.85))))
                    property color strokeColor: parent._comboIsActive
                        ? Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.6)
                        : (root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.08))

                    onFillColorChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onWidthChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var sk = 8
                        ctx.fillStyle = fillColor
                        ctx.beginPath()
                        ctx.moveTo(sk, 0)
                        ctx.lineTo(width, 0)
                        ctx.lineTo(width - sk, height)
                        ctx.lineTo(0, height)
                        ctx.closePath()
                        ctx.fill()
                        ctx.strokeStyle = strokeColor
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                }

                Text {
                    id: _comboLabel
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Style.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: parent._comboIsActive
                        ? (root._hasCustomBg ? root._customActiveTextColor : (root.colors ? root.colors.primaryText : "#000"))
                        : (root.colors ? root.colors.tertiary : "#8bceff")
                }

                MouseArea {
                    id: _comboMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.onSelect) root.onSelect(modelData) }
                }
            }
        }
    }
}
