import QtQuick
import QtQuick.Controls
import ".."

Item {
  id: browser

  property var colors
  property var swService
  property bool browserVisible: false
    readonly property string _customBgRaw: (Config.wallpaperFilterBarBgColor || "").trim()
    readonly property bool _hasCustomBg: _customBgRaw.length > 0
    readonly property color _customBgColor: _hasCustomBg ? _customBgRaw : "transparent"
    readonly property real _customLuma: (_customBgColor.r * 0.2126) + (_customBgColor.g * 0.7152) + (_customBgColor.b * 0.0722)
    readonly property real _customAlpha: _customBgColor.a > 0 ? _customBgColor.a : 1.0
    readonly property color _chipBg: _hasCustomBg
      ? Qt.rgba(_customBgColor.r, _customBgColor.g, _customBgColor.b, Math.max(_customAlpha, 0.82))
      : (browser.colors ? Qt.rgba(browser.colors.surface.r, browser.colors.surface.g, browser.colors.surface.b, 0.8) : Qt.rgba(0.15, 0.17, 0.22, 0.8))
    readonly property color _chipHoverBg: _hasCustomBg
      ? (_customLuma < 0.45 ? Qt.lighter(_customBgColor, 1.2) : Qt.darker(_customBgColor, 1.2))
      : (browser.colors ? Qt.rgba(browser.colors.surfaceVariant.r, browser.colors.surfaceVariant.g, browser.colors.surfaceVariant.b, 0.5) : Qt.rgba(1,1,1,0.15))
    readonly property color _chipActiveBg: _hasCustomBg
      ? (_customLuma < 0.08
        ? Qt.rgba(0.84, 0.84, 0.84, _customAlpha)
        : (_customLuma > 0.92
          ? Qt.rgba(0.24, 0.24, 0.24, _customAlpha)
          : (_customLuma < 0.45 ? Qt.lighter(_customBgColor, 1.45) : Qt.darker(_customBgColor, 1.55))))
      : (browser.colors ? browser.colors.primary : Style.fallbackAccent)
    readonly property real _chipActiveLuma: (_chipActiveBg.r * 0.2126) + (_chipActiveBg.g * 0.7152) + (_chipActiveBg.b * 0.0722)
    readonly property color _chipActiveText: _chipActiveLuma > 0.58 ? "#111111" : "#ffffff"
      readonly property color _panelBg: _hasCustomBg
        ? Qt.rgba(_customBgColor.r, _customBgColor.g, _customBgColor.b, Math.max(_customAlpha, 0.92))
        : (browser.colors ? Qt.rgba(browser.colors.surfaceContainer.r, browser.colors.surfaceContainer.g, browser.colors.surfaceContainer.b, 0.92)
                : Qt.rgba(0.08, 0.1, 0.14, 0.92))
      readonly property color _panelStroke: _hasCustomBg
        ? Qt.rgba(_chipActiveBg.r, _chipActiveBg.g, _chipActiveBg.b, 0.35)
        : (browser.colors ? Qt.rgba(browser.colors.primary.r, browser.colors.primary.g, browser.colors.primary.b, 0.15)
                : Qt.rgba(1, 1, 1, 0.1))

  signal escapePressed()

  clip: true

  visible: browserVisible
  opacity: browserVisible ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Style.animNormal; easing.type: Easing.OutCubic } }

  height: browserVisible ? implicitHeight : 0
  Behavior on height { NumberAnimation { duration: Style.animEnter; easing.type: Easing.OutCubic } }
  implicitHeight: contentCol.implicitHeight + 16

  MouseArea {
    anchors.fill: parent
    propagateComposedEvents: true
    onWheel: function(wheel) {
      if (!browser.swService || browser.swService.loading) { wheel.accepted = false; return }
      if (wheel.angleDelta.y < 0) { browser.swService.nextPage(); wheel.accepted = true }
      else if (wheel.angleDelta.y > 0) { browser.swService.prevPage(); wheel.accepted = true }
      else { wheel.accepted = false }
    }
    onPressed: function(mouse) { mouse.accepted = false }
    onReleased: function(mouse) { mouse.accepted = false }
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: browser._panelBg
    border.width: 1
    border.color: browser._panelStroke
  }
  Column {
    id: contentCol
    anchors.left: parent.left; anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 10

    Row {
      spacing: 8
      width: parent.width

      Rectangle {
        width: 28; height: 28; radius: 6
        property bool isHovered: closeMouse.containsMouse
        color: isHovered ? browser._chipHoverBg
                         : "transparent"
        Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        Text {
          anchors.centerIn: parent
          text: "󰅁"; font.family: Style.fontFamilyNerdIcons; font.pixelSize: 16
          color: browser.colors ? browser.colors.tertiary : "#8bceff"
        }
        MouseArea {
          id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: browser.escapePressed()
        }
        StyledToolTip { visible: closeMouse.containsMouse; text: "Back to wallpapers"; delay: 400 }
      }

      Text {
        text: "󰓓"
        font.family: Style.fontFamilyNerdIcons; font.pixelSize: 18
        color: browser.colors ? browser.colors.tertiary : "#8bceff"
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 220; height: 30; radius: 6
        color: browser._chipBg
        border.width: swSearchInput.activeFocus ? 2 : 1
        border.color: swSearchInput.activeFocus
            ? browser._chipActiveBg
            : (browser.colors ? Qt.rgba(browser.colors.primary.r, browser.colors.primary.g, browser.colors.primary.b, 0.2) : Qt.rgba(1, 1, 1, 0.12))

        TextInput {
          id: swSearchInput
          anchors.fill: parent; anchors.margins: 6
          font.family: Style.fontFamily; font.pixelSize: 12
          color: browser.colors ? browser.colors.surfaceText : "#e0e0e0"
          clip: true
          property string placeholderText: "Search Steam Workshop..."
          Keys.onReturnPressed: { browser.swService.query = text; browser.swService.search(1) }
          Keys.onEscapePressed: browser.escapePressed()
        }
        Text {
          anchors.fill: parent; anchors.margins: 6
          font.family: Style.fontFamily; font.pixelSize: 12
          color: browser.colors ? Qt.rgba(browser.colors.surfaceText.r, browser.colors.surfaceText.g, browser.colors.surfaceText.b, 0.35)
                                : Qt.rgba(1, 1, 1, 0.3)
          text: swSearchInput.placeholderText
          visible: !swSearchInput.text && !swSearchInput.activeFocus
        }
      }

      Rectangle { width: 1; height: 22; color: Qt.rgba(browser._chipActiveBg.r, browser._chipActiveBg.g, browser._chipActiveBg.b, 0.35) }

      Row {
        spacing: 3
        Repeater {
          model: [
            { key: "trend",                    label: "Trending" },
            { key: "totaluniquesubscribers",   label: "Popular" },
            { key: "favorited",                label: "Favorites" }
          ]
          Rectangle {
            width: sortLabel.implicitWidth + 14; height: 26; radius: 4
            property bool isOn: browser.swService ? browser.swService.sorting === modelData.key : false
            property bool isHovered: sortMouse.containsMouse
            color: isOn ? browser._chipActiveBg
                        : (isHovered ? browser._chipHoverBg : "transparent")
            border.width: isOn ? 0 : 1
            border.color: isHovered ? Qt.rgba(browser._chipActiveBg.r, browser._chipActiveBg.g, browser._chipActiveBg.b, 0.5) : "transparent"
            Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
            Text {
              id: sortLabel; anchors.centerIn: parent
              text: modelData.label; font.family: Style.fontFamily; font.pixelSize: 11
              color: parent.isOn ? browser._chipActiveText
                                 : (browser.colors ? browser.colors.tertiary : "#8bceff")
            }
            MouseArea {
              id: sortMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { browser.swService.sorting = modelData.key; browser.swService.search(1) }
            }
          }
        }
      }

      Text {
        visible: browser.swService ? browser.swService.loading : false
        text: "󰔟"
        font.family: Style.fontFamilyNerdIcons; font.pixelSize: 16
        color: browser.colors ? browser.colors.primary : Style.fallbackAccent
        anchors.verticalCenter: parent.verticalCenter
        RotationAnimation on rotation { from: 0; to: 360; duration: Style.animSpin; loops: Animation.Infinite; running: parent.visible }
      }
    }

    Flow {
      width: parent.width
      spacing: 4

      Repeater {
        model: [
          { key: "",           label: "All" },
          { key: "Abstract",   label: "Abstract" },
          { key: "Animal",     label: "Animal" },
          { key: "Anime",      label: "Anime" },
          { key: "CGI",        label: "CGI" },
          { key: "Cyberpunk",  label: "Cyberpunk" },
          { key: "Fantasy",    label: "Fantasy" },
          { key: "Game",       label: "Game" },
          { key: "Girls",      label: "Girls" },
          { key: "Guys",       label: "Guys" },
          { key: "Landscape",  label: "Landscape" },
          { key: "Medieval",   label: "Medieval" },
          { key: "Memes",      label: "Memes" },
          { key: "MMD",        label: "MMD" },
          { key: "Music",      label: "Music" },
          { key: "Nature",     label: "Nature" },
          { key: "Pixel art",  label: "Pixel Art" },
          { key: "Relaxing",   label: "Relaxing" },
          { key: "Retro",      label: "Retro" },
          { key: "Sci-Fi",     label: "Sci-Fi" },
          { key: "Sports",     label: "Sports" },
          { key: "Technology", label: "Technology" },
          { key: "Television", label: "Television" },
          { key: "Unidirectional", label: "Unidirectional" },
          { key: "Vehicle",    label: "Vehicle" }
        ]
        Rectangle {
          width: catLabel.implicitWidth + 14; height: 24; radius: 4
          property bool isOn: browser.swService ? browser.swService.requiredTag === modelData.key : false
          property bool isHovered: catMouse.containsMouse
          color: isOn ? browser._chipActiveBg
                      : (isHovered ? browser._chipHoverBg : "transparent")
          border.width: isOn ? 0 : 1
          border.color: isHovered ? Qt.rgba(browser._chipActiveBg.r, browser._chipActiveBg.g, browser._chipActiveBg.b, 0.5) : "transparent"
          Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
          Text {
            id: catLabel; anchors.centerIn: parent
            text: modelData.label; font.family: Style.fontFamily; font.pixelSize: 10
            color: parent.isOn ? browser._chipActiveText
                               : (browser.colors ? browser.colors.tertiary : "#8bceff")
          }
          MouseArea {
            id: catMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { browser.swService.requiredTag = modelData.key; browser.swService.search(1) }
          }
        }
      }
    }
    Text {
      visible: browser.swService && browser.swService.errorText !== ""
      text: browser.swService ? browser.swService.errorText : ""
      font.family: Style.fontFamily; font.pixelSize: 11
      color: "#ff6b6b"
      width: parent.width
      wrapMode: Text.Wrap
    }

    Grid {
      id: resultsGrid
      columns: 6
      spacing: 8
      width: parent.width

      Repeater {
        model: browser.swService ? browser.swService.results.length : 0
        delegate: Item {
          id: thumbDelegate
          width: (resultsGrid.width - (resultsGrid.columns - 1) * resultsGrid.spacing) / resultsGrid.columns
          height: width * 0.6

          property var wp: browser.swService.results[index]
          property string dlStatus: {
            if (!browser.swService || !wp) return ""
            var s = browser.swService.downloadStatus
            return s[wp.id] || ""
          }
          property real dlProgress: {
            if (!browser.swService || !wp) return 0
            var p = browser.swService.downloadProgress
            return p[wp.id] || 0
          }
          property bool isLocal: {
            if (!browser.swService || !wp) return false
            var ids = browser.swService.localWorkshopIds
            return !!ids[wp.id]
          }

          Rectangle {
            anchors.fill: parent; radius: 6
            color: browser.colors ? Qt.rgba(browser.colors.surface.r, browser.colors.surface.g, browser.colors.surface.b, 0.6)
                                  : Qt.rgba(0.12, 0.14, 0.18, 0.6)
            clip: true

            Image {
              id: thumbImg
              anchors.fill: parent
              source: thumbDelegate.wp ? thumbDelegate.wp.previewUrl : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              cache: false
              sourceSize.width: Math.ceil(thumbDelegate.width)
              sourceSize.height: Math.ceil(thumbDelegate.height)
            }

            Text {
              anchors.centerIn: parent
              visible: thumbImg.status === Image.Loading
              text: "󰔟"
              font.family: Style.fontFamilyNerdIcons; font.pixelSize: 20
              color: browser.colors ? Qt.rgba(browser.colors.surfaceText.r, browser.colors.surfaceText.g, browser.colors.surfaceText.b, 0.3) : Qt.rgba(1,1,1,0.2)
            }

            Rectangle {
              id: hoverOverlay
              anchors.fill: parent; radius: 6
              color: Qt.rgba(0, 0, 0, 0.6)
              opacity: thumbMouse.containsMouse ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: Style.animFast } }

              Column {
                anchors.centerIn: parent
                spacing: 4
                width: parent.width - 12

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: thumbDelegate.wp ? thumbDelegate.wp.title : ""
                  font.family: Style.fontFamily; font.pixelSize: 10; font.weight: Font.Medium
                  color: "#e0e0e0"
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.Wrap
                }

                Rectangle {
                  width: 90; height: 28; radius: 6
                  anchors.horizontalCenter: parent.horizontalCenter
                  visible: thumbDelegate.dlStatus !== "downloading"

                  color: (thumbDelegate.dlStatus === "done" || thumbDelegate.isLocal)
                      ? (browser.colors ? Qt.rgba(browser.colors.primary.r, browser.colors.primary.g, browser.colors.primary.b, 0.3) : Qt.rgba(0.3, 0.8, 0.3, 0.3))
                      : (dlBtnMouse.containsMouse
                          ? (browser.colors ? browser.colors.primary : Style.fallbackAccent)
                          : (browser.colors ? Qt.rgba(browser.colors.primary.r, browser.colors.primary.g, browser.colors.primary.b, 0.6) : Qt.rgba(0.3, 0.76, 0.97, 0.6)))
                  Behavior on color { ColorAnimation { duration: Style.animVeryFast } }

                  Row {
                    anchors.centerIn: parent; spacing: 4
                    Text {
                      text: (thumbDelegate.dlStatus === "done" || thumbDelegate.isLocal) ? "󰄬" : (thumbDelegate.dlStatus === "error" ? "󰅙" : "󰇚")
                      font.family: Style.fontFamilyNerdIcons; font.pixelSize: 14
                      color: (thumbDelegate.dlStatus === "done" || thumbDelegate.isLocal) ? "#8BC34A" : (thumbDelegate.dlStatus === "error" ? "#ff6b6b" : "#fff")
                    }
                    Text {
                      text: (thumbDelegate.dlStatus === "done" || thumbDelegate.isLocal) ? "Installed" : (thumbDelegate.dlStatus === "error" ? "Error" : "Install")
                      font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
                      color: "#fff"
                    }
                  }

                  MouseArea {
                    id: dlBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (thumbDelegate.dlStatus === "done" || thumbDelegate.isLocal || !thumbDelegate.wp) return
                      browser.swService.downloadWorkshop(thumbDelegate.wp.id)
                    }
                  }
                }

                Text {
                  visible: thumbDelegate.dlStatus === "downloading"
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Downloading..."
                  font.family: Style.fontFamily; font.pixelSize: 11
                  color: browser.colors ? browser.colors.primary : Style.fallbackAccent
                }

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: 8
                  Text {
                    text: thumbDelegate.wp ? "󰓃 " + _formatCount(thumbDelegate.wp.subscriptions) : ""
                    font.family: Style.fontFamilyNerdIcons; font.pixelSize: 9
                    color: "#999"
                  }
                  Text {
                    text: thumbDelegate.wp ? "󰋑 " + _formatCount(thumbDelegate.wp.favorited) : ""
                    font.family: Style.fontFamilyNerdIcons; font.pixelSize: 9
                    color: "#999"
                  }
                }
              }
            }

            Row {
              anchors.bottom: parent.bottom; anchors.left: parent.left
              anchors.margins: 4; spacing: 3
              Repeater {
                model: thumbDelegate.wp ? Math.min(thumbDelegate.wp.tags.length, 2) : 0
                Rectangle {
                  width: tagBadge.implicitWidth + 6; height: 14; radius: 3
                  color: Qt.rgba(0, 0, 0, 0.6)
                  Text {
                    id: tagBadge; anchors.centerIn: parent
                    text: thumbDelegate.wp.tags[index]
                    font.family: Style.fontFamily; font.pixelSize: 8
                    color: "#ccc"
                  }
                }
              }
            }

            Rectangle {
              visible: thumbDelegate.isLocal || thumbDelegate.dlStatus === "done"
              anchors.top: parent.top; anchors.left: parent.left
              anchors.margins: 4
              width: dlBadgeRow.implicitWidth + 8; height: 16; radius: 4
              color: browser.colors ? Qt.rgba(browser.colors.primary.r, browser.colors.primary.g, browser.colors.primary.b, 0.85)
                                    : Qt.rgba(0.3, 0.76, 0.97, 0.85)
              Row {
                id: dlBadgeRow; anchors.centerIn: parent; spacing: 3
                Text {
                  text: "󰄬"; font.family: Style.fontFamilyNerdIcons; font.pixelSize: 10
                  color: browser.colors ? browser.colors.primaryText : "#000"
                }
                Text {
                  text: "Installed"; font.family: Style.fontFamily; font.pixelSize: 8; font.weight: Font.Medium
                  color: browser.colors ? browser.colors.primaryText : "#000"
                }
              }
            }

            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: 3
              color: "transparent"
              visible: thumbDelegate.dlStatus === "downloading"
              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * thumbDelegate.dlProgress
                radius: 2
                color: browser.colors ? browser.colors.primary : Style.fallbackAccent
                Behavior on width { NumberAnimation { duration: Style.animNormal; easing.type: Easing.OutCubic } }
              }
            }

            MouseArea {
              id: thumbMouse; anchors.fill: parent; hoverEnabled: true
              propagateComposedEvents: true
              onPressed: function(mouse) { mouse.accepted = false }
            }
          }
        }
      }
    }

    Row {
      spacing: 10
      anchors.horizontalCenter: parent.horizontalCenter
      visible: browser.swService && browser.swService.results.length > 0

      Rectangle {
        width: 60; height: 26; radius: 6
        property bool isHovered: prevMouse.containsMouse
        color: isHovered ? browser._chipHoverBg
                         : "transparent"
        opacity: browser.swService && browser.swService.currentPage > 1 ? 1 : 0.3
        Text {
          anchors.centerIn: parent
          text: "󰅁 Prev"; font.family: Style.fontFamilyNerdIcons; font.pixelSize: 11
          color: browser.colors ? browser.colors.tertiary : "#8bceff"
        }
        MouseArea {
          id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: browser.swService.prevPage()
        }
      }

      Text {
        text: browser.swService ? (browser.swService.currentPage + " / " + browser.swService.lastPage) : "1 / 1"
        font.family: Style.fontFamily; font.pixelSize: 11
        color: browser.colors ? Qt.rgba(browser.colors.surfaceText.r, browser.colors.surfaceText.g, browser.colors.surfaceText.b, 0.5) : Qt.rgba(1,1,1,0.4)
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 60; height: 26; radius: 6
        property bool isHovered: nextMouse.containsMouse
        color: isHovered ? browser._chipHoverBg
                         : "transparent"
        opacity: browser.swService && browser.swService.currentPage < browser.swService.lastPage ? 1 : 0.3
        Text {
          anchors.centerIn: parent
          text: "Next 󰅂"; font.family: Style.fontFamilyNerdIcons; font.pixelSize: 11
          color: browser.colors ? browser.colors.tertiary : "#8bceff"
        }
        MouseArea {
          id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: browser.swService.nextPage()
        }
      }
    }

    Text {
      visible: browser.swService && !browser.swService.loading && browser.swService.results.length === 0 && browser.swService.errorText === ""
      text: "Search the Steam Workshop for Wallpaper Engine wallpapers"
      font.family: Style.fontFamily; font.pixelSize: 12
      color: browser.colors ? Qt.rgba(browser.colors.surfaceText.r, browser.colors.surfaceText.g, browser.colors.surfaceText.b, 0.4)
                            : Qt.rgba(1, 1, 1, 0.3)
      anchors.horizontalCenter: parent.horizontalCenter
    }
  }
  onBrowserVisibleChanged: {
    if (browserVisible && swService && swService.results.length === 0) {
      swSearchInput.forceActiveFocus()
      swService.search(1)
    } else if (browserVisible) {
      swSearchInput.forceActiveFocus()
      swService.scanLocalDirs()
    }
  }
  function _formatCount(n) {
    if (!n || n <= 0) return "0"
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "K"
    return n.toString()
  }

  function _formatSize(bytes) {
    if (!bytes || bytes <= 0) return ""
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " KB"
    return (bytes / 1048576).toFixed(1) + " MB"
  }
}
