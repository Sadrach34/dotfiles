import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

// Window switcher — parallelogram slice style (igual que AppLauncher)
// Alt+Tab: navega, soltar Alt confirma
Scope {
  id: windowSwitcher

  readonly property color clrPrimary:     "#6272a4"
  readonly property color clrTertiary:    "#8be9fd"
  readonly property string fnt:  "JetBrainsMono Nerd Font"
  readonly property string fntI: "JetBrainsMono Nerd Font"

  property int sliceWidth:    135
  property int expandedWidth: 900
  property int sliceHeight:   520
  property int skewOffset:    35
  property int sliceSpacing:  -22
  property int cardWidth:    1600

  property bool cardVisible: false
  property bool preserveIndex: false
  property var allWindowsData: []

  function updateFilter() {
    var selWinId = (filteredModel.count > 0 && sliceListView.currentIndex >= 0)
                   ? filteredModel.get(sliceListView.currentIndex).winId : ""
    filteredModel.clear()
    var newSelIdx = 0; var found = false
    for (var i = 0; i < windowSwitcher.allWindowsData.length; i++) {
      var w = windowSwitcher.allWindowsData[i]
      if (!found && w.winId === selWinId) { newSelIdx = filteredModel.count; found = true }
      filteredModel.append(w)
    }
    if (filteredModel.count > 0)
      sliceListView.currentIndex = newSelIdx
  }

  ListModel { id: filteredModel }
  Process { id: fetchWindows; command: ["hyprctl", "clients", "-j"]; property string buf: ""
    stdout: SplitParser { splitMarker: ""; onRead: data => fetchWindows.buf += data }
    onExited: {
      try {
        var arr = JSON.parse(fetchWindows.buf.trim())
        arr.sort((a,b) => (a.focusHistoryID||999) - (b.focusHistoryID||999))
        var tmp = []
        for (var i = 0; i < arr.length; i++) {
          var w = arr[i]
          if (!w.mapped || w.hidden) continue
          // Excluir ventanas en workspaces especiales (ej. drop terminal en special:scratchpad)
          if (w.workspace && w.workspace.name && w.workspace.name.startsWith("special:")) continue
          tmp.push({
            winId: w.address||"",
            title: (w.title||"").slice(0,60),
            appId: w.class||"",
            workspaceId: (w.workspace&&w.workspace.id)||0,
            wsName:      (w.workspace&&w.workspace.name)||"",
            isFocused:   w.focusHistoryID === 0,
            isFloating:  w.floating || false
          })
        }
        windowSwitcher.allWindowsData = tmp
        if (!windowSwitcher.preserveIndex)
          sliceListView.currentIndex = tmp.length > 1 ? 1 : 0
        windowSwitcher.preserveIndex = false
        windowSwitcher.updateFilter()
      } catch(e) {}
      fetchWindows.buf = ""
    }
  }
  Process { id: focusProc;  command: ["true"] }
  Process { id: closeProc;  command: ["true"] }

  Timer {
    id: refreshTimer
    interval: 100
    onTriggered: { fetchWindows.buf = ""; fetchWindows.running = true }
  }

  function closeSelected() {
    if (filteredModel.count > 0 && sliceListView.currentIndex >= 0) {
      var win = filteredModel.get(sliceListView.currentIndex)
      closeProc.command = ["hyprctl","dispatch","closewindow","address:"+win.winId]
      closeProc.running = true
      windowSwitcher.preserveIndex = true
      refreshTimer.restart()
    }
  }

  function confirm() {
    if (filteredModel.count > 0 && sliceListView.currentIndex >= 0) {
      var win = filteredModel.get(sliceListView.currentIndex)
      focusProc.command = ["hyprctl","dispatch","focuswindow","address:"+win.winId]
      focusProc.running = true
    }
    root.windowSwitcherVisible = false
  }
  function cancel() { root.windowSwitcherVisible = false }
  function next()   { if (filteredModel.count > 0) sliceListView.currentIndex = (sliceListView.currentIndex+1) % filteredModel.count }
  function prev()   { if (filteredModel.count > 0) sliceListView.currentIndex = (sliceListView.currentIndex+filteredModel.count-1) % filteredModel.count }

  function winGlyph(appId) {
    var c = (appId||"").toLowerCase()
    if (c.indexOf("firefox")  !== -1) return "󰈹"
    if (c.indexOf("chrome")   !== -1 || c.indexOf("chromium") !== -1) return "󰊯"
    if (c.indexOf("spotify")  !== -1) return "󰓇"
    if (c.indexOf("discord")  !== -1) return "󰙯"
    if (c.indexOf("telegram") !== -1) return "󰔁"
    if (c.indexOf("code")     !== -1 || c.indexOf("vscode")   !== -1) return "󰨞"
    if (c.indexOf("kitty")    !== -1 || c.indexOf("alacritty")!== -1) return ""
    if (c.indexOf("term")     !== -1) return ""
    if (c.indexOf("steam")    !== -1) return "󰓓"
    if (c.indexOf("thunar")   !== -1 || c.indexOf("nautilus") !== -1) return "󰉋"
    if (c.indexOf("gimp")     !== -1) return "󰏘"
    if (c.indexOf("blender")  !== -1) return "󰂫"
    if (c.indexOf("obs")      !== -1) return "󰕧"
    if (c.indexOf("vlc")      !== -1 || c.indexOf("mpv")      !== -1) return "󰕼"
    return "󰖗"
  }

  function winName(appId) {
    var c = (appId||"").toLowerCase()
    if (c.indexOf("firefox")  !== -1) return "Firefox"
    if (c.indexOf("chrome")   !== -1) return "Chrome"
    if (c.indexOf("chromium") !== -1) return "Chromium"
    if (c.indexOf("spotify")  !== -1) return "Spotify"
    if (c.indexOf("discord")  !== -1) return "Discord"
    if (c.indexOf("telegram") !== -1) return "Telegram"
    if (c.indexOf("code")     !== -1) return "VSCode"
    if (c.indexOf("kitty")    !== -1) return "Kitty"
    if (c.indexOf("alacritty")!== -1) return "Alacritty"
    if (c.indexOf("term")     !== -1) return "Terminal"
    if (c.indexOf("steam")    !== -1) return "Steam"
    if (c.indexOf("thunar")   !== -1) return "Thunar"
    if (c.indexOf("nautilus") !== -1) return "Nautilus"
    if (c.indexOf("gimp")     !== -1) return "GIMP"
    if (c.indexOf("blender")  !== -1) return "Blender"
    if (c.indexOf("obs")      !== -1) return "OBS"
    if (c.indexOf("vlc")      !== -1) return "VLC"
    if (c.indexOf("mpv")      !== -1) return "mpv"
    return appId || "Ventana"
  }

  Connections {
    target: root
    function onWindowSwitcherVisibleChanged() {
      if (root.windowSwitcherVisible) {
        fetchWindows.buf = ""
        fetchWindows.running = true
        cardShowTimer.restart()
      } else {
        windowSwitcher.cardVisible = false
      }
    }
  }

  Timer { id: cardShowTimer; interval: 50;
    onTriggered: { windowSwitcher.cardVisible = true; sliceListView.forceActiveFocus() } }

  PanelWindow {
    screen: Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "qs-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.windowSwitcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    visible: root.windowSwitcherVisible

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0,0,0,0.55)
      opacity: windowSwitcher.cardVisible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    MouseArea { anchors.fill: parent; onClicked: windowSwitcher.cancel() }

    Item {
      id: cardContainer
      width: windowSwitcher.cardWidth; height: windowSwitcher.sliceHeight + 35
      anchors.centerIn: parent
      visible: windowSwitcher.cardVisible
      opacity: 0
      property bool animateIn: windowSwitcher.cardVisible
      onAnimateInChanged: {
        if (animateIn) { opacity = 0; fadeIn.start() }
      }
      NumberAnimation { id: fadeIn; target: cardContainer; property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
      MouseArea { anchors.fill: parent; onClicked: {} }
    }

    // Super-release capture (el switcher se abre con Win+Tab)
    FocusScope {
      id: altDetector; anchors.fill: parent
      Keys.onReleased: event => {
        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R
            || event.key === Qt.Key_Alt  || event.key === Qt.Key_AltGr) {
          windowSwitcher.confirm(); event.accepted = true
        }
      }
    }

    ListView {
      id: sliceListView
      anchors.top: cardContainer.top
      anchors.topMargin: 15
      anchors.bottom: cardContainer.bottom; anchors.bottomMargin: 20
      anchors.horizontalCenter: parent.horizontalCenter
      property int visibleCount: 12
      width: windowSwitcher.expandedWidth + (visibleCount-1)*(windowSwitcher.sliceWidth+windowSwitcher.sliceSpacing)
      orientation: ListView.Horizontal
      model: filteredModel; clip: false; spacing: windowSwitcher.sliceSpacing
      flickDeceleration: 1500; maximumFlickVelocity: 3000
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: windowSwitcher.expandedWidth * 4
      visible: windowSwitcher.cardVisible
      highlightFollowsCurrentItem: true; highlightMoveDuration: 350
      highlight: Item {}
      preferredHighlightBegin: (width - windowSwitcher.expandedWidth) / 2
      preferredHighlightEnd:   (width + windowSwitcher.expandedWidth) / 2
      highlightRangeMode: ListView.StrictlyEnforceRange
      header: Item { width: (sliceListView.width - windowSwitcher.expandedWidth) / 2; height: 1 }
      footer: Item { width: (sliceListView.width - windowSwitcher.expandedWidth) / 2; height: 1 }
      Keys.onPressed: event => {
        if      (event.key === Qt.Key_Escape)                               { windowSwitcher.cancel();  event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { windowSwitcher.confirm(); event.accepted = true }
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)   { windowSwitcher.prev();   event.accepted = true }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)     { windowSwitcher.next();   event.accepted = true }
        else if (event.key === Qt.Key_Left)                                 { windowSwitcher.prev();   event.accepted = true }
        else if (event.key === Qt.Key_Right)                                { windowSwitcher.next();   event.accepted = true }
      }

      Text {
        anchors.centerIn: parent; visible: filteredModel.count === 0
        text: "SIN VENTANAS ABIERTAS"
        font.family: windowSwitcher.fnt; font.pixelSize: 18; font.weight: Font.Bold; font.letterSpacing: 2
        color: Qt.rgba(1,1,1,0.3)
      }

      MouseArea {
        anchors.fill: parent; propagateComposedEvents: true
        onWheel: function(w) {
          if (w.angleDelta.y > 0 || w.angleDelta.x > 0) sliceListView.currentIndex = Math.max(0, sliceListView.currentIndex-1)
          else sliceListView.currentIndex = Math.min(filteredModel.count-1, sliceListView.currentIndex+1)
        }
        onPressed: m => m.accepted = false; onReleased: m => m.accepted = false; onClicked: m => m.accepted = false
      }

      delegate: Item {
        id: delegateItem
        width: isCurrent ? windowSwitcher.expandedWidth : windowSwitcher.sliceWidth
        height: sliceListView.height
        property bool isCurrent: ListView.isCurrentItem
        property bool isHov: sliceMouse.containsMouse
        z: isCurrent ? 100 : (isHov ? 90 : (50 - Math.min(Math.abs(index - sliceListView.currentIndex),50)))
        property real viewX:    x - sliceListView.contentX
        property real fadeZone: windowSwitcher.sliceWidth * 1.5
        property real edgeOpacity: {
          if (fadeZone <= 0) return 1.0
          var center = viewX + width*0.5
          var lf = Math.min(1.0, Math.max(0.0, center / fadeZone))
          var rf = Math.min(1.0, Math.max(0.0, (sliceListView.width - center) / fadeZone))
          return Math.min(lf, rf)
        }
        opacity: edgeOpacity
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        containmentMask: Item {
          function contains(point) {
            var w = delegateItem.width; var h = delegateItem.height; var sk = windowSwitcher.skewOffset
            if (h <= 0 || w <= 0) return false
            return point.x >= sk*(1.0-point.y/h) && point.x <= w-sk*(point.y/h) && point.y >= 0 && point.y <= h
          }
        }

        Canvas {
          z: -1; anchors.fill: parent; anchors.margins: -10
          property real shadowAlpha: delegateItem.isCurrent ? 0.6 : 0.4
          onWidthChanged: requestPaint(); onHeightChanged: requestPaint(); onShadowAlphaChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d"); ctx.clearRect(0,0,width,height)
            var ox=10,oy=10,w=delegateItem.width,h=delegateItem.height,sk=windowSwitcher.skewOffset
            var sx=delegateItem.isCurrent?4:2, sy=delegateItem.isCurrent?10:5
            var layers=[{dx:sx,dy:sy,alpha:shadowAlpha*0.5},{dx:sx*0.6,dy:sy*0.6,alpha:shadowAlpha*0.3},{dx:sx*1.4,dy:sy*1.4,alpha:shadowAlpha*0.2}]
            for(var i=0;i<layers.length;i++){var l=layers[i];ctx.globalAlpha=l.alpha;ctx.fillStyle="#000";ctx.beginPath();ctx.moveTo(ox+sk+l.dx,oy+l.dy);ctx.lineTo(ox+w+l.dx,oy+l.dy);ctx.lineTo(ox+w-sk+l.dx,oy+h+l.dy);ctx.lineTo(ox+l.dx,oy+h+l.dy);ctx.closePath();ctx.fill()}
          }
        }

        Item {
          id: imageContainer; anchors.fill: parent
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(0.10, 0.11, 0.18, 1) }
              GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.05, 0.10, 1) }
            }
          }
          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0,0,0, delegateItem.isCurrent ? 0 : (delegateItem.isHov ? 0.2 : 0.45))
            Behavior on color { ColorAnimation { duration: 200 } }
          }
          Text {
            anchors.centerIn: parent; anchors.verticalCenterOffset: -20
            text: windowSwitcher.winGlyph(model.appId)
            font.family: windowSwitcher.fntI
            property int iconSz: delegateItem.isCurrent ? 96 : 48
            font.pixelSize: iconSz
            Behavior on iconSz { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            color: delegateItem.isCurrent ? windowSwitcher.clrPrimary : Qt.rgba(0.54,0.63,0.84,0.4)
            Behavior on color { ColorAnimation { duration: 200 } }
          }
          layer.enabled: true; layer.smooth: true; layer.samples: 4
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
              sourceItem: Item {
                width: imageContainer.width; height: imageContainer.height
                layer.enabled: true; layer.smooth: true; layer.samples: 8
                Shape {
                  anchors.fill: parent; antialiasing: true; preferredRendererType: Shape.CurveRenderer
                  ShapePath {
                    fillColor: "white"; strokeColor: "transparent"
                    startX: windowSwitcher.skewOffset; startY: 0
                    PathLine { x: delegateItem.width;                           y: 0 }
                    PathLine { x: delegateItem.width - windowSwitcher.skewOffset; y: delegateItem.height }
                    PathLine { x: 0;                                            y: delegateItem.height }
                    PathLine { x: windowSwitcher.skewOffset;                    y: 0 }
                  }
                }
              }
            }
            maskThresholdMin: 0.3; maskSpreadAtMin: 0.3
          }
        }

        Shape {
          anchors.fill: parent; antialiasing: true; preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: delegateItem.isCurrent ? windowSwitcher.clrPrimary
              : (delegateItem.isHov ? Qt.rgba(0.38,0.45,0.64,0.4) : Qt.rgba(0,0,0,0.6))
            Behavior on strokeColor { ColorAnimation { duration: 200 } }
            strokeWidth: delegateItem.isCurrent ? 3 : 1
            startX: windowSwitcher.skewOffset; startY: 0
            PathLine { x: delegateItem.width;                           y: 0 }
            PathLine { x: delegateItem.width - windowSwitcher.skewOffset; y: delegateItem.height }
            PathLine { x: 0;                                            y: delegateItem.height }
            PathLine { x: windowSwitcher.skewOffset;                    y: 0 }
          }
        }

        // Badge "FOCUSED"
        Rectangle {
          anchors.top: parent.top; anchors.topMargin: 10
          anchors.left: parent.left; anchors.leftMargin: windowSwitcher.skewOffset + 6
          width: focLabel.width + 12; height: 20; radius: 10
          color: windowSwitcher.clrPrimary
          visible: model.isFocused; z: 10
          Text { id: focLabel; anchors.centerIn: parent; text: "ACTIVA"
            font.family: windowSwitcher.fnt; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: "#0d0d0d" }
        }

        // Badge nombre + título (visible cuando seleccionado)
        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 40
          anchors.horizontalCenter: parent.horizontalCenter
          width: nameLabelCol.width + 24; height: nameLabelCol.height + 16
          radius: 6; color: Qt.rgba(0,0,0,0.75)
          border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.5)
          visible: delegateItem.isCurrent
          opacity: delegateItem.isCurrent ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 200 } }
          Column {
            id: nameLabelCol; anchors.centerIn: parent; spacing: 4
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: windowSwitcher.winName(model.appId).toUpperCase()
              font.family: windowSwitcher.fnt; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 0.5
              color: windowSwitcher.clrPrimary
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: model.title || ""
              font.family: windowSwitcher.fnt; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.6)
              width: Math.min(implicitWidth, delegateItem.width - 80)
              elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
            }
          }
        }

        // Badge workspace (bottom-right)
        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 8
          anchors.right: parent.right; anchors.rightMargin: windowSwitcher.skewOffset + 8
          width: wsBadge.width + 8; height: 16; radius: 4; z: 10
          color: Qt.rgba(0,0,0,0.75); border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.4)
          Text { id: wsBadge; anchors.centerIn: parent; text: "WS " + (model.wsName||model.workspaceId)
            font.family: windowSwitcher.fnt; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: windowSwitcher.clrTertiary }
        }

        // Badge "FLOAT" (bottom-left)
        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 8
          anchors.left: parent.left; anchors.leftMargin: windowSwitcher.skewOffset + 8
          width: floatLabel.width + 8; height: 16; radius: 4; z: 10
          color: Qt.rgba(0,0,0,0.75); border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.4)
          visible: model.isFloating
          Text { id: floatLabel; anchors.centerIn: parent; text: "FLOAT"
            font.family: windowSwitcher.fnt; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: windowSwitcher.clrTertiary }
        }

        MouseArea {
          id: sliceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          property real lastX: -1; property real lastY: -1
          onPositionChanged: function(m) {
            var g = mapToItem(sliceListView, m.x, m.y)
            if (Math.abs(g.x-lastX)>2 || Math.abs(g.y-lastY)>2) {
              lastX=g.x; lastY=g.y; sliceListView.currentIndex = index
            }
          }
          onClicked: {
            if (delegateItem.isCurrent) windowSwitcher.confirm()
            else sliceListView.currentIndex = index
          }
        }
      }
    }
  }

  // Overlays en monitores secundarios para capturar teclado desde cualquier pantalla
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: secondaryPanel
      property var modelData
      property bool isMain: modelData === Quickshell.screens[0]

      screen: modelData
      visible: root.windowSwitcherVisible && !isMain
      color: "transparent"

      anchors { top: true; bottom: true; left: true; right: true }
      WlrLayershell.namespace: "qs-window-switcher-secondary"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: (root.windowSwitcherVisible && !isMain) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.55)
        opacity: windowSwitcher.cardVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }
      MouseArea { anchors.fill: parent; onClicked: windowSwitcher.cancel() }

      FocusScope {
        anchors.fill: parent
        focus: root.windowSwitcherVisible && !secondaryPanel.isMain
        Keys.onReleased: event => {
          if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R
              || event.key === Qt.Key_Alt  || event.key === Qt.Key_AltGr) {
            windowSwitcher.confirm(); event.accepted = true
          }
        }
        Keys.onPressed: event => {
          if      (event.key === Qt.Key_Escape)                               { windowSwitcher.cancel();       event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { windowSwitcher.confirm();      event.accepted = true }
          else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)   { windowSwitcher.prev();         event.accepted = true }
          else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)     { windowSwitcher.next();         event.accepted = true }
          else if (event.key === Qt.Key_Left)                                 { windowSwitcher.prev();         event.accepted = true }
          else if (event.key === Qt.Key_Right)                                { windowSwitcher.next();         event.accepted = true }
          else if (event.key === Qt.Key_Delete)                               { windowSwitcher.closeSelected(); event.accepted = true }
        }
      }
    }
  }
}
