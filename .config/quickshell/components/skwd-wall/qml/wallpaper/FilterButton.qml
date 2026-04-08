import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: btn

    property var colors
    property bool isActive: false
    property string icon: ""
    property string label: ""
    property bool useNerdFont: icon !== ""
    property string tooltip: ""
    property int skew: 10
    property color activeColor: "transparent"
    property color inactiveBaseColor: "transparent"
    property bool hasActiveColor: false
    property real activeOpacity: 1.0

    signal clicked()

    width: _label.implicitWidth + 24 + skew
    height: 24
    z: isActive ? 10 : (isHovered ? 5 : 1)

    readonly property bool isHovered: _mouse.containsMouse
    readonly property string _customBgRaw: (Config.wallpaperFilterBarBgColor || "").trim()
    readonly property bool _hasCustomBg: _customBgRaw.length > 0
    readonly property color _resolvedInactiveColor: (btn.inactiveBaseColor.a > 0)
        ? btn.inactiveBaseColor
        : (_hasCustomBg
            ? _customBgRaw
            : (btn.colors ? Qt.rgba(btn.colors.surfaceContainer.r, btn.colors.surfaceContainer.g, btn.colors.surfaceContainer.b, 0.85) : Qt.rgba(0.1, 0.12, 0.18, 0.85)))
    readonly property real _inactiveLuma: (_resolvedInactiveColor.r * 0.2126) + (_resolvedInactiveColor.g * 0.7152) + (_resolvedInactiveColor.b * 0.0722)
    readonly property real _inactiveAlpha: _resolvedInactiveColor.a > 0 ? _resolvedInactiveColor.a : 1.0
    readonly property color _derivedActiveColor: (_inactiveLuma < 0.08)
        ? Qt.rgba(0.84, 0.84, 0.84, _inactiveAlpha)
        : (_inactiveLuma > 0.92
            ? Qt.rgba(0.24, 0.24, 0.24, _inactiveAlpha)
            : (_inactiveLuma < 0.45 ? Qt.lighter(_resolvedInactiveColor, 1.45) : Qt.darker(_resolvedInactiveColor, 1.55)))
    readonly property color _resolvedActiveColor: btn.hasActiveColor
        ? btn.activeColor
        : (_hasCustomBg ? _derivedActiveColor : (btn.colors ? btn.colors.primary : Style.fallbackAccent))
    readonly property real _activeLuma: (_resolvedActiveColor.r * 0.2126) + (_resolvedActiveColor.g * 0.7152) + (_resolvedActiveColor.b * 0.0722)
    readonly property color _activeTextColor: _activeLuma > 0.58 ? "#111111" : "#ffffff"

    Canvas {
        id: _canvas
        anchors.fill: parent

        property color fillColor: btn.isActive
            ? btn._resolvedActiveColor
            : (btn.isHovered
                ? (btn.colors ? Qt.rgba(btn.colors.surfaceVariant.r, btn.colors.surfaceVariant.g, btn.colors.surfaceVariant.b, 0.6) : Qt.rgba(1, 1, 1, 0.15))
                : btn._resolvedInactiveColor)
        property color strokeColor: btn.isActive
            ? Qt.rgba(btn._resolvedActiveColor.r, btn._resolvedActiveColor.g, btn._resolvedActiveColor.b, 0.6)
            : (btn.colors ? Qt.rgba(btn.colors.primary.r, btn.colors.primary.g, btn.colors.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.08))

        onFillColorChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var sk = btn.skew
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
        id: _label
        anchors.centerIn: parent
        text: btn.icon || btn.label
        font.pixelSize: btn.useNerdFont ? 14 : 10
        font.family: btn.useNerdFont ? Style.fontFamilyNerdIcons : Style.fontFamily
        font.weight: btn.useNerdFont ? Font.Normal : Font.Bold
        font.letterSpacing: btn.useNerdFont ? 0 : 0.5
        color: btn.isActive
            ? (btn.hasActiveColor ? btn._activeTextColor : (btn.colors ? btn.colors.primaryText : "#000"))
            : (btn.colors ? btn.colors.tertiary : "#8bceff")
    }

    opacity: btn.activeOpacity

    MouseArea {
        id: _mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    StyledToolTip {
        visible: btn.tooltip !== "" && _mouse.containsMouse
        text: btn.tooltip
        delay: Style.tooltipDelay
    }
}
