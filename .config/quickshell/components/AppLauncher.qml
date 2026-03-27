import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Shapes

// Full-screen app launcher with parallelogram slice UI
// Adapted from piixident project for Hyprland
Scope {
  id: appLauncher

  readonly property color clrPrimary:          "#6272a4"
  readonly property color clrPrimaryText:      "#f8f8f2"
  readonly property color clrTertiary:         "#8be9fd"
  readonly property string fnt:  "JetBrainsMono Nerd Font"
  readonly property string fntI: "JetBrainsMono Nerd Font"

  property bool cardVisible: false
  property string searchText: ""
  property string sourceFilter: ""
  property bool hoverSelectionEnabled: false

  // Frequency-based search ranking
  property string freqCachePath: Quickshell.env("HOME") + "/.cache/quickshell/app-launcher/freq.json"
  property var freqData: ({})

  FileView {
    id: freqFile
    path: appLauncher.freqCachePath
    preload: true
  }

  function loadFreqData() {
    try { appLauncher.freqData = JSON.parse(freqFile.text()) }
    catch (e) { appLauncher.freqData = {} }
  }

  function saveFreqData() {
    freqFile.setText(JSON.stringify(appLauncher.freqData))
  }

  function recordSelection(appName) {
    var query = appLauncher.searchText.toLowerCase().trim()
    if (query === "") return
    var fd = appLauncher.freqData
    for (var len = 2; len <= query.length; len++) {
      var prefix = query.substring(0, len)
      if (!fd[prefix]) fd[prefix] = {}
      if (!fd[prefix][appName]) fd[prefix][appName] = 0
      fd[prefix][appName] += 1
    }
    appLauncher.freqData = fd
    saveFreqData()
  }

  function getFreqScore(appName) {
    var query = appLauncher.searchText.toLowerCase().trim()
    if (query === "" || !appLauncher.freqData[query]) return 0
    return appLauncher.freqData[query][appName] || 0
  }

  property int sliceWidth:    135
  property int expandedWidth: 900
  property int sliceHeight:   520
  property int skewOffset:    35
  property int sliceSpacing:  -22
  property int cardWidth:    1600
  property int topBarHeight:   50
  property int cardHeight: sliceHeight + topBarHeight + 60

  property string scriptsPath: Quickshell.env("HOME") + "/.config/quickshell/scripts"

  Connections {
    target: root
    function onAppLauncherVisibleChanged() {
      if (root.appLauncherVisible) {
        appLauncher.searchText = ""
        searchInput.text = ""
        appLauncher.hoverSelectionEnabled = false
        sliceListView.hoverArmed = false
        sliceListView.lastMouseX = -1
        sliceListView.lastMouseY = -1
        loadFreqData()
        resetIndexTimer.restart()
        cardShowTimer.restart()
        hoverEnableTimer.restart()
        // Always refresh when opening so newly installed apps appear immediately.
        loadApps.buf = ""
        loadApps.running = false
        loadApps.running = true
      } else {
        appLauncher.cardVisible = false
        appLauncher.searchText = ""
        searchInput.text = ""
        appLauncher.hoverSelectionEnabled = false
        sliceListView.hoverArmed = false
        sliceListView.lastMouseX = -1
        sliceListView.lastMouseY = -1
      }
    }
  }

  Timer { id: cardShowTimer; interval: 50; onTriggered: appLauncher.cardVisible = true }
  Timer { id: focusTimer;    interval: 80; onTriggered: sliceListView.forceActiveFocus() }
  Timer { id: hoverEnableTimer; interval: 220; onTriggered: appLauncher.hoverSelectionEnabled = true }
  Timer { id: resetIndexTimer; interval: 100; onTriggered: {
      sliceListView.currentIndex = 0
      sliceListView.positionViewAtIndex(0, ListView.SnapPosition)
  }}

  ListModel { id: appModel }
  ListModel { id: filteredModel }

  function updateFilteredModel() {
    var query = searchText.toLowerCase()
    var sf = sourceFilter
    var results = []
    for (var i = 0; i < appModel.count; i++) {
      var item = appModel.get(i)
      if (query !== "" &&
          item.name.toLowerCase().indexOf(query) === -1 &&
          item.categories.toLowerCase().indexOf(query) === -1 &&
          (item.displayName||"").toLowerCase().indexOf(query) === -1)
        continue
      if (sf === "game"  && item.categories.indexOf("Game")  === -1) continue
      if (sf === "media" && item.categories.indexOf("Audio") === -1
                         && item.categories.indexOf("Video") === -1) continue
      if (sf === "steam" && (item.categories||"").indexOf("Steam") === -1) continue
      results.push({
        name: item.name, exec: item.exec, categories: item.categories,
        iconPath: item.iconPath||"", terminal: item.terminal||false,
        displayName: item.displayName||""
      })
    }
    // Sort by frequency score when there's a query
    if (query !== "") {
      var freqMap = appLauncher.freqData[query] || {}
      results.sort(function(a, b) {
        var fa = freqMap[a.name] || 0
        var fb = freqMap[b.name] || 0
        if (fa !== fb) return fb - fa
        return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
      })
    }
    filteredModel.clear()
    for (var j = 0; j < results.length; j++) filteredModel.append(results[j])
    if (filteredModel.count > 0) {
      sliceListView.currentIndex = 0
      sliceListView.positionViewAtIndex(0, ListView.SnapPosition)
    }
  }

  onSearchTextChanged: {
    updateFilteredModel()
    if (searchInput.text !== searchText) searchInput.text = searchText
  }
  onSourceFilterChanged: updateFilteredModel()

  Process {
    id: loadApps
    command: ["python3", appLauncher.scriptsPath + "/desktop_apps.py"]
    property string buf: ""
    stdout: SplitParser { splitMarker: ""; onRead: data => loadApps.buf += data }
    onExited: {
      try {
        var arr = JSON.parse(loadApps.buf.trim())
        appModel.clear()
        for (var i = 0; i < arr.length; i++) {
          var a = arr[i]
          appModel.append({
            name: a.name||"", exec: a.exec||"", categories: a.categories||"",
            iconPath: a.iconPath||"", terminal: a.terminal||false,
            displayName: a.displayName||""
          })
        }
        appLauncher.updateFilteredModel()
      } catch(e) {}
      loadApps.buf = ""
    }
  }

  // Desktop file watcher: reconstruye caché automáticamente cuando se instala/elimina una app
  Process {
    id: desktopWatcher
    running: true
    command: ["bash", "-c",
      "dirs=(); for d in /usr/share/applications " +
      "\"$HOME/.local/share/applications\" " +
      "/var/lib/flatpak/exports/share/applications " +
      "\"$HOME/.local/share/flatpak/exports/share/applications\"; do " +
      "[ -d \"$d\" ] && dirs+=(\"$d\"); done; " +
      "[ ${#dirs[@]} -eq 0 ] && exit 1; " +
      "exec inotifywait -m -r -e create,delete,modify,moved_to,moved_from " +
      "--include '\\.desktop$' \"${dirs[@]}\""
    ]
    stdout: SplitParser { onRead: line => desktopWatcherDebounce.restart() }
    onExited: desktopWatcherRestart.start()
  }

  // Reiniciar watcher si termina inesperadamente
  Timer {
    id: desktopWatcherRestart
    interval: 5000
    onTriggered: desktopWatcher.running = true
  }

  // Debounce: agrupa cambios rápidos en una sola recarga
  Timer {
    id: desktopWatcherDebounce
    interval: 2000
    onTriggered: {
      appModel.clear()
      loadApps.running = true
    }
  }

  Process { id: appRunner; command: ["true"] }
  Process { id: launchRunner; command: ["true"] }

  function launchApp(exec_cmd, isTerminal, appName) {
    if (appName) recordSelection(appName)
    var cmd = exec_cmd
    if (isTerminal) cmd = "kitty " + cmd
    launchRunner.command = ["hyprctl", "dispatch", "exec", cmd]
    launchRunner.running = false
    launchRunner.running = true
    root.appLauncherVisible = false
  }

  function categoryBadge(cats) {
    var c = cats || ""
    if (c.indexOf("Game")        !== -1) return "GAME"
    if (c.indexOf("Development") !== -1) return "DEV"
    if (c.indexOf("Graphics")    !== -1) return "GFX"
    if (c.indexOf("AudioVideo")  !== -1 || c.indexOf("Audio") !== -1 || c.indexOf("Video") !== -1) return "MEDIA"
    if (c.indexOf("Network")     !== -1) return "NET"
    if (c.indexOf("Office")      !== -1) return "OFFICE"
    if (c.indexOf("System")      !== -1) return "SYS"
    if (c.indexOf("Settings")    !== -1) return "CFG"
    if (c.indexOf("Utility")     !== -1) return "UTIL"
    return "APP"
  }

  function appGlyph(name, cats) {
    var n = (name||"").toLowerCase()
    var c = (cats||"").toLowerCase()
    if (n.indexOf("firefox")  !== -1) return "󰈹"
    if (n.indexOf("chrome")   !== -1 || n.indexOf("chromium") !== -1) return "󰊯"
    if (n.indexOf("spotify")  !== -1) return "󰓇"
    if (n.indexOf("discord")  !== -1) return "󰙯"
    if (n.indexOf("telegram") !== -1) return "󰔁"
    if (n.indexOf("code")     !== -1 || n.indexOf("vscode") !== -1) return "󰨞"
    if (n.indexOf("kitty")    !== -1 || n.indexOf("alacritty") !== -1) return ""
    if (n.indexOf("terminal") !== -1) return ""
    if (n.indexOf("steam")    !== -1) return "󰓓"
    if (n.indexOf("thunar")   !== -1 || n.indexOf("nautilus") !== -1) return "󰉋"
    if (n.indexOf("gimp")     !== -1) return "󰏘"
    if (n.indexOf("blender")  !== -1) return "󰂫"
    if (n.indexOf("obs")      !== -1) return "󰕧"
    if (n.indexOf("vlc")      !== -1 || n.indexOf("mpv") !== -1) return "󰕼"
    if (c.indexOf("game")     !== -1) return "󰊗"
    if (c.indexOf("audio")    !== -1 || c.indexOf("video")      !== -1) return "󰎆"
    if (c.indexOf("graphics") !== -1) return "󰏘"
    if (c.indexOf("network")  !== -1) return "󰖟"
    if (c.indexOf("development") !== -1) return "󰅩"
    if (c.indexOf("system")   !== -1) return "󰜖"
    return "󰘔"
  }

  PanelWindow {
    id: launcherPanel
    screen: Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "qs-app-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.appLauncherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    visible: root.appLauncherVisible

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)
      opacity: appLauncher.cardVisible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    MouseArea {
      anchors.fill: parent
      onClicked: root.appLauncherVisible = false
    }

    Item {
      id: cardContainer
      width: appLauncher.cardWidth; height: appLauncher.cardHeight
      anchors.centerIn: parent
      visible: appLauncher.cardVisible
      opacity: 0
      property bool animateIn: appLauncher.cardVisible
      onAnimateInChanged: {
        fadeInAnim.stop()
        if (animateIn) { opacity = 0; fadeInAnim.start(); focusTimer.restart() }
      }
      NumberAnimation { id: fadeInAnim; target: cardContainer; property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
      MouseArea { anchors.fill: parent; onClicked: {} }

      Rectangle {
        id: filterBarBg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 10
        width: topFilterBar.width + 30; height: topFilterBar.height + 14
        radius: height / 2
        color: Qt.rgba(0.07, 0.07, 0.12, 0.90)
        z: 10
      }

      Row {
        id: topFilterBar
        anchors.centerIn: filterBarBg
        spacing: 16; z: 11

        Row {
          spacing: 4; anchors.verticalCenter: parent.verticalCenter
          Repeater {
            model: [
              { filter: "",      icon: "󰄶", label: "Todo" },
              { filter: "game",  icon: "󰊗", label: "Juegos" },
              { filter: "steam", icon: "󰓓", label: "Steam" },
              { filter: "media", icon: "󰎆", label: "Media" }
            ]
            Rectangle {
              width: 32; height: 24; radius: 4
              property bool isSelected: appLauncher.sourceFilter === modelData.filter
              property bool isHovered: fltMouse.containsMouse
              color: isSelected ? appLauncher.clrPrimary : (isHovered ? Qt.rgba(0.3,0.3,0.5,0.4) : "transparent")
              border.width: isSelected ? 0 : 1
              border.color: isHovered ? Qt.rgba(0.38,0.45,0.64,0.5) : "transparent"
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                anchors.centerIn: parent; text: modelData.icon
                font.pixelSize: 14; font.family: appLauncher.fntI
                color: parent.isSelected ? appLauncher.clrPrimaryText : appLauncher.clrTertiary
              }
              MouseArea {
                id: fltMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { if (parent.isSelected) appLauncher.sourceFilter = ""; else appLauncher.sourceFilter = modelData.filter }
              }
              ToolTip { visible: fltMouse.containsMouse; text: modelData.label; delay: 500 }
            }
          }
        }

        Rectangle { width: 1; height: 20; color: Qt.rgba(0.38,0.45,0.64,0.3); anchors.verticalCenter: parent.verticalCenter }

        Text { text: "󰍉"; font.family: appLauncher.fntI; font.pixelSize: 18; color: appLauncher.clrTertiary; anchors.verticalCenter: parent.verticalCenter }

        TextInput {
          id: searchInput
          width: 200
          font.family: appLauncher.fnt; font.pixelSize: 14; font.weight: Font.Medium
          color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter; clip: true
          onTextChanged: appLauncher.searchText = text
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
              if (sliceListView.currentIndex > 0) sliceListView.currentIndex--
              else sliceListView.currentIndex = filteredModel.count - 1
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
              if (sliceListView.currentIndex < filteredModel.count - 1) sliceListView.currentIndex++
              else sliceListView.currentIndex = 0
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < filteredModel.count) {
                var app = filteredModel.get(sliceListView.currentIndex)
                appLauncher.launchApp(app.exec, app.terminal, app.name)
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.appLauncherVisible = false
              event.accepted = true
            }
          }
          Text { anchors.fill: parent; text: "Buscar apps..."; font: searchInput.font; color: Qt.rgba(1,1,1,0.35); visible: !searchInput.text }
        }

        Text {
          text: filteredModel.count + " apps"
          font.family: appLauncher.fnt; font.pixelSize: 11; font.weight: Font.Medium
          color: Qt.rgba(1,1,1,0.4); anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    ListView {
      id: sliceListView
      anchors.top: cardContainer.top; anchors.topMargin: appLauncher.topBarHeight + 15
      anchors.bottom: cardContainer.bottom; anchors.bottomMargin: 20
      anchors.horizontalCenter: parent.horizontalCenter
      property int visibleCount: 12
      width: appLauncher.expandedWidth + (visibleCount - 1) * (appLauncher.sliceWidth + appLauncher.sliceSpacing)
      orientation: ListView.Horizontal
      model: filteredModel
      clip: false; spacing: appLauncher.sliceSpacing
      flickDeceleration: 1500; maximumFlickVelocity: 3000
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: appLauncher.expandedWidth * 4
      visible: appLauncher.cardVisible
      property bool keyboardNavActive: false
      property bool hoverArmed: false
      property real lastMouseX: -1; property real lastMouseY: -1
      highlightFollowsCurrentItem: true; highlightMoveDuration: 350
      highlight: Item {}
      preferredHighlightBegin: (width - appLauncher.expandedWidth) / 2
      preferredHighlightEnd:   (width + appLauncher.expandedWidth) / 2
      highlightRangeMode: ListView.ApplyRange
      header: Item { width: (sliceListView.width - appLauncher.expandedWidth) / 2; height: 1 }
      footer: Item { width: (sliceListView.width - appLauncher.expandedWidth) / 2; height: 1 }
      focus: root.appLauncherVisible
      onVisibleChanged: { if (visible) forceActiveFocus() }

      MouseArea {
        anchors.fill: parent; propagateComposedEvents: true
        onWheel: function(w) {
          if (w.angleDelta.y > 0 || w.angleDelta.x > 0) sliceListView.currentIndex = Math.max(0, sliceListView.currentIndex - 1)
          else sliceListView.currentIndex = Math.min(filteredModel.count-1, sliceListView.currentIndex+1)
        }
        onPressed: m => m.accepted = false
        onReleased: m => m.accepted = false
        onClicked: m => m.accepted = false
      }

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.appLauncherVisible = false; event.accepted = true; return }
        if (event.text && event.text.length > 0 && !event.modifiers) {
          var c = event.text.charCodeAt(0)
          if (c >= 32 && c < 127) { searchInput.text += event.text; searchInput.forceActiveFocus(); event.accepted = true; return }
        }
        if (event.key === Qt.Key_Backspace) {
          if (searchInput.text.length > 0) searchInput.text = searchInput.text.slice(0,-1)
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < filteredModel.count) {
            var a = filteredModel.get(sliceListView.currentIndex)
            appLauncher.launchApp(a.exec, a.terminal, a.name)
          }
          event.accepted = true; return
        }
        sliceListView.keyboardNavActive = true
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { if (currentIndex > 0) currentIndex--; event.accepted = true }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { if (currentIndex < filteredModel.count-1) currentIndex++; event.accepted = true }
      }

      delegate: Item {
        id: delegateItem
        width: isCurrent ? appLauncher.expandedWidth : appLauncher.sliceWidth
        height: sliceListView.height
        property bool isCurrent: ListView.isCurrentItem
        property bool isHovered: itemMouseArea.containsMouse
        z: isCurrent ? 100 : (isHovered ? 90 : (50 - Math.min(Math.abs(index - sliceListView.currentIndex), 50)))
        property real viewX: x - sliceListView.contentX
        property real fadeZone: appLauncher.sliceWidth * 1.5
        property real edgeOpacity: {
          if (fadeZone <= 0) return 1.0
          var center = viewX + width * 0.5
          var leftFade  = Math.min(1.0, Math.max(0.0, center / fadeZone))
          var rightFade = Math.min(1.0, Math.max(0.0, (sliceListView.width - center) / fadeZone))
          return Math.min(leftFade, rightFade)
        }
        opacity: edgeOpacity
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

        containmentMask: Item {
          function contains(point) {
            var w = delegateItem.width; var h = delegateItem.height; var sk = appLauncher.skewOffset
            if (h <= 0 || w <= 0) return false
            return point.x >= sk*(1.0-point.y/h) && point.x <= w-sk*(point.y/h) && point.y >= 0 && point.y <= h
          }
        }

        Canvas {
          z: -1; anchors.fill: parent; anchors.margins: -10
          property real shadowOffsetX: delegateItem.isCurrent ? 4 : 2
          property real shadowOffsetY: delegateItem.isCurrent ? 10 : 5
          property real shadowAlpha:   delegateItem.isCurrent ? 0.6 : 0.4
          onWidthChanged: requestPaint(); onHeightChanged: requestPaint(); onShadowAlphaChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d"); ctx.clearRect(0,0,width,height)
            var ox=10,oy=10,w=delegateItem.width,h=delegateItem.height,sk=appLauncher.skewOffset
            var sx=shadowOffsetX,sy=shadowOffsetY
            var layers=[{dx:sx,dy:sy,alpha:shadowAlpha*0.5},{dx:sx*0.6,dy:sy*0.6,alpha:shadowAlpha*0.3},{dx:sx*1.4,dy:sy*1.4,alpha:shadowAlpha*0.2}]
            for(var i=0;i<layers.length;i++){var l=layers[i];ctx.globalAlpha=l.alpha;ctx.fillStyle="#000";ctx.beginPath();ctx.moveTo(ox+sk+l.dx,oy+l.dy);ctx.lineTo(ox+w+l.dx,oy+l.dy);ctx.lineTo(ox+w-sk+l.dx,oy+h+l.dy);ctx.lineTo(ox+l.dx,oy+h+l.dy);ctx.closePath();ctx.fill()}
          }
        }

        Item {
          id: imageContainer; anchors.fill: parent
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.07, 0.12, 1) }
              GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.04, 0.08, 1) }
            }
          }
          Image {
            id: appIcon
            anchors.centerIn: parent; anchors.verticalCenterOffset: -20
            width:  delegateItem.isCurrent ? 80 : 44
            height: width
            source: model.iconPath ? "file://" + model.iconPath : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true; smooth: true; cache: true
            visible: status === Image.Ready
            Behavior on width { NumberAnimation { duration: 200 } }
          }
          Text {
            anchors.centerIn: parent; anchors.verticalCenterOffset: -20
            visible: appIcon.status !== Image.Ready
            text: appLauncher.appGlyph(model.name, model.categories)
            font.pixelSize: delegateItem.isCurrent ? 96 : 48; font.family: appLauncher.fntI
            color: delegateItem.isCurrent ? Qt.rgba(0.38,0.45,0.64,0.5) : Qt.rgba(1,1,1,0.1)
            Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
            Behavior on color { ColorAnimation { duration: 200 } }
          }
          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0,0,0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.45))
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
                    startX: appLauncher.skewOffset; startY: 0
                    PathLine { x: delegateItem.width;                        y: 0 }
                    PathLine { x: delegateItem.width-appLauncher.skewOffset; y: delegateItem.height }
                    PathLine { x: 0;                                         y: delegateItem.height }
                    PathLine { x: appLauncher.skewOffset;                    y: 0 }
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
            strokeColor: delegateItem.isCurrent ? appLauncher.clrPrimary
              : (delegateItem.isHovered ? Qt.rgba(0.38,0.45,0.64,0.4) : Qt.rgba(0,0,0,0.6))
            Behavior on strokeColor { ColorAnimation { duration: 200 } }
            strokeWidth: delegateItem.isCurrent ? 3 : 1
            startX: appLauncher.skewOffset; startY: 0
            PathLine { x: delegateItem.width;                        y: 0 }
            PathLine { x: delegateItem.width-appLauncher.skewOffset; y: delegateItem.height }
            PathLine { x: 0;                                         y: delegateItem.height }
            PathLine { x: appLauncher.skewOffset;                    y: 0 }
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 40
          anchors.horizontalCenter: parent.horizontalCenter
          width: nameText.width+24; height: 32; radius: 6
          color: Qt.rgba(0,0,0,0.75)
          border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.5)
          visible: delegateItem.isCurrent
          opacity: delegateItem.isCurrent ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 200 } }
          Text {
            id: nameText; anchors.centerIn: parent
            text: model.name.toUpperCase()
            font.family: appLauncher.fnt; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: appLauncher.clrTertiary; elide: Text.ElideMiddle; maximumLineCount: 1
            width: Math.min(implicitWidth, delegateItem.width-60)
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 8
          anchors.right: parent.right; anchors.rightMargin: appLauncher.skewOffset+8
          width: catBadgeText.width+8; height: 16; radius: 4; z: 10
          color: Qt.rgba(0,0,0,0.75)
          border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.4)
          Text {
            id: catBadgeText; anchors.centerIn: parent
            text: appLauncher.categoryBadge(model.categories)
            font.family: appLauncher.fnt; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: appLauncher.clrTertiary
          }
        }

        MouseArea {
          id: itemMouseArea; anchors.fill: parent; hoverEnabled: true
          acceptedButtons: Qt.LeftButton; cursorShape: Qt.PointingHandCursor
          onPositionChanged: function(mouse) {
            // Keep keyboard opening deterministic: hover no longer changes selection.
            // Selection still changes via arrows/tab, wheel, and click.
            if (!appLauncher.hoverSelectionEnabled) return
          }
          onClicked: {
            if (delegateItem.isCurrent) appLauncher.launchApp(model.exec, model.terminal, model.name)
            else sliceListView.currentIndex = index
          }
        }
      }
    }
  }
}
