import QtQuick
import ".."

Column {
    id: root
    property var colors
    property string label: ""
    property int value: 0
    property int min: 0
    property int max: 1000
    property var onCommit
    readonly property string _customBgRaw: (Config.wallpaperFilterBarBgColor || "").trim()
    readonly property bool _hasCustomBg: _customBgRaw.length > 0
    readonly property color _customBgColor: _hasCustomBg ? _customBgRaw : "transparent"

    width: parent ? parent.width : 0
    spacing: 2

    Text {
        text: root.label
        font.family: Style.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
        color: root.colors ? root.colors.tertiary : Qt.rgba(1, 1, 1, 0.5)
    }

    Rectangle {
        width: parent.width
        height: 26
        radius: 4
        color: root._hasCustomBg
            ? Qt.rgba(root._customBgColor.r, root._customBgColor.g, root._customBgColor.b, Math.max(root._customBgColor.a, 0.75))
            : (root.colors ? Qt.rgba(root.colors.surfaceContainer.r, root.colors.surfaceContainer.g, root.colors.surfaceContainer.b, 0.6) : Qt.rgba(0.15, 0.15, 0.2, 0.6))
        border.width: inputField.activeFocus ? 1 : 0
        border.color: root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.3)

        TextInput {
            id: inputField
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.fontFamilyCode
            font.pixelSize: 11
            color: root.colors ? root.colors.tertiary : "#8bceff"
            clip: true
            selectByMouse: true
            text: root.value.toString()
            validator: IntValidator { bottom: root.min; top: root.max }
            onTextEdited: {
                var n = parseInt(text)
                if (!isNaN(n) && n >= root.min && root.onCommit)
                    root.onCommit(n)
            }
        }
    }
}
