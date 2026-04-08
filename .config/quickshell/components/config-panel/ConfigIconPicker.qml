import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../skwd-wall/qml"

Rectangle {
  id: root
  property var panel
  property var colors

  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.85)
  visible: panel._iconPickerVisible
  z: 100

  property var allIcons: []

  FileView {
    id: _iconDataFile
    path: panel.configDir + "/data/mdi-icons.json"
    preload: true
    watchChanges: true
    onLoaded: root._loadIcons()
    onFileChanged: {
      _iconDataFile.reload()
    }
  }

  function _loadIcons() {
    var text = _iconDataFile.text().trim()
    if (!text) return
    try {
      allIcons = JSON.parse(text)
      _rebuildFiltered()
    } catch (e) {
      console.log("ConfigIconPicker: Failed to parse mdi-icons.json:", e)
    }
  }

  property var _filteredModel: ListModel {}
  property string _searchText: ""

  function focusSearch() {
    iconSearchInput.text = ""
    iconSearchInput.forceActiveFocus()
    _rebuildFiltered()
  }

  function _rebuildFiltered() {
    _filteredModel.clear()
    var q = _searchText.toLowerCase()
    for (var i = 0; i < allIcons.length; i++) {
      var item = allIcons[i]
      if (!q || item.n.indexOf(q) >= 0) {
        _filteredModel.append({name: item.n, glyph: item.g})
      }
    }
  }

  onVisibleChanged: {
    if (visible) _rebuildFiltered()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.panel._iconPickerVisible = false
  }

  Rectangle {
    width: 700
    height: 560
    anchors.centerIn: parent
    radius: 12
    color: root.colors ? Qt.rgba(root.colors.surfaceContainer.r, root.colors.surfaceContainer.g, root.colors.surfaceContainer.b, 0.95) : Qt.rgba(0.1, 0.12, 0.18, 0.95)
    border.width: 1
    border.color: root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.2) : Qt.rgba(1, 1, 1, 0.1)

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 12

      // Header row: title + search + manual paste
      Row {
        width: parent.width
        spacing: 12

        Text {
          text: "󰀻 ICON PICKER"
          font.family: Style.fontFamilyIcons
          font.pixelSize: 16
          font.weight: Font.Bold
          font.letterSpacing: 1.0
          color: root.colors ? root.colors.primary : "#4fc3f7"
          anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: 8; height: 1 }

        Rectangle {
          width: 260
          height: 30
          radius: 6
          color: root.colors ? Qt.rgba(root.colors.surfaceContainer.r, root.colors.surfaceContainer.g, root.colors.surfaceContainer.b, 0.6) : Qt.rgba(0.15, 0.15, 0.2, 0.6)
          border.width: iconSearchInput.activeFocus ? 1 : 0
          border.color: root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.3)
          anchors.verticalCenter: parent.verticalCenter

          TextInput {
            id: iconSearchInput
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.fontFamily
            font.pixelSize: 12
            color: root.colors ? root.colors.surfaceText : "#ddd"
            clip: true
            selectByMouse: true
            onTextChanged: {
              root._searchText = text.trim()
              root._rebuildFiltered()
            }

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              text: "󰍉 search icons by name..."
              font.family: Style.fontFamilyIcons
              font.pixelSize: 11
              color: root.colors ? Qt.rgba(root.colors.surfaceText.r, root.colors.surfaceText.g, root.colors.surfaceText.b, 0.25) : Qt.rgba(1, 1, 1, 0.2)
              visible: !parent.text && !parent.activeFocus
            }
          }
        }

        Item { width: 4; height: 1 }

        Rectangle {
          width: 120
          height: 30
          radius: 6
          color: root.colors ? Qt.rgba(root.colors.surfaceContainer.r, root.colors.surfaceContainer.g, root.colors.surfaceContainer.b, 0.6) : Qt.rgba(0.15, 0.15, 0.2, 0.6)
          border.width: manualIconInput.activeFocus ? 1 : 0
          border.color: root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.3)
          anchors.verticalCenter: parent.verticalCenter

          TextInput {
            id: manualIconInput
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: Style.fontFamilyIcons
            font.pixelSize: 14
            color: root.colors ? root.colors.tertiary : "#8bceff"
            clip: true
            selectByMouse: true

            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              text: "paste glyph"
              font.family: Style.fontFamily
              font.pixelSize: 10
              color: root.colors ? Qt.rgba(root.colors.surfaceText.r, root.colors.surfaceText.g, root.colors.surfaceText.b, 0.25) : Qt.rgba(1, 1, 1, 0.2)
              visible: !parent.text && !parent.activeFocus
            }
          }
        }

        Rectangle {
          width: applyManualLabel.implicitWidth + 16
          height: 30
          radius: 6
          color: applyManualMouse.containsMouse
            ? (root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.2))
            : (root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.1))
          anchors.verticalCenter: parent.verticalCenter
          visible: manualIconInput.text !== ""

          Text {
            id: applyManualLabel
            anchors.centerIn: parent
            text: "APPLY"
            font.family: Style.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
            color: root.colors ? root.colors.primary : "#4fc3f7"
          }

          MouseArea {
            id: applyManualMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var key = root.panel._iconPickerTargetKey
              if (key && manualIconInput.text) {
                if (!root.panel.appsData[key]) root.panel.appsData[key] = {}
                root.panel.appsData[key].icon = manualIconInput.text
                root.panel.hasUnsavedChanges = true
                root.panel.appsDataChanged()
              }
              root.panel._iconPickerVisible = false
              manualIconInput.text = ""
            }
          }
        }
      }

      Text {
        text: root._filteredModel.count + " icons" + (root._searchText ? " matching \"" + root._searchText + "\"" : "")
        font.family: Style.fontFamily
        font.pixelSize: 10
        color: root.colors ? Qt.rgba(root.colors.surfaceText.r, root.colors.surfaceText.g, root.colors.surfaceText.b, 0.4) : Qt.rgba(1, 1, 1, 0.3)
      }

      // Icon grid
      GridView {
        id: iconGrid
        width: parent.width
        height: parent.height - 72
        cellWidth: 52
        cellHeight: 52
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root._filteredModel

        delegate: Rectangle {
          width: 48; height: 48
          radius: 8
          color: iconCellMouse.containsMouse
            ? (root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.15))
            : (root.colors ? Qt.rgba(root.colors.surfaceVariant.r, root.colors.surfaceVariant.g, root.colors.surfaceVariant.b, 0.2) : Qt.rgba(1, 1, 1, 0.05))
          border.width: iconCellMouse.containsMouse ? 1 : 0
          border.color: root.colors ? Qt.rgba(root.colors.primary.r, root.colors.primary.g, root.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)

          Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -6
            text: model.glyph
            font.family: Style.fontFamilyIcons
            font.pixelSize: 22
            color: iconCellMouse.containsMouse
              ? (root.colors ? root.colors.primary : "#4fc3f7")
              : (root.colors ? root.colors.surfaceText : "#ddd")
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            text: {
              var n = model.name
              var parts = n.split(" ")
              return parts[0].length > 8 ? parts[0].substring(0, 7) + "…" : parts[0]
            }
            font.family: Style.fontFamily
            font.pixelSize: 7
            color: root.colors ? Qt.rgba(root.colors.surfaceText.r, root.colors.surfaceText.g, root.colors.surfaceText.b, 0.35) : Qt.rgba(1, 1, 1, 0.25)
          }

          MouseArea {
            id: iconCellMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            ToolTip {
              id: iconTooltip
              visible: iconCellMouse.containsMouse
              text: model.name
              delay: 400
            }

            onClicked: {
              var key = root.panel._iconPickerTargetKey
              if (key) {
                if (!root.panel.appsData[key]) root.panel.appsData[key] = {}
                root.panel.appsData[key].icon = model.glyph
                root.panel.hasUnsavedChanges = true
                root.panel.appsDataChanged()
              }
              root.panel._iconPickerVisible = false
            }
          }
        }
      }
    }
  }
}
