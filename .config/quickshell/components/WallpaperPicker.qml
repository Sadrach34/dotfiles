import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Controls
import QtMultimedia

// Wallpaper picker — parallelogram slice style
// Super+Ctrl+W para abrir — soporta imágenes y videos (mp4/gif/etc.)
Scope {
  id: wallpaperPicker

  readonly property color clrPrimary:   "#6272a4"
  readonly property color clrTertiary:  "#8be9fd"
  readonly property string fnt:  "JetBrainsMono Nerd Font"
  readonly property string fntI: "JetBrainsMono Nerd Font"

  property int sliceWidth:    135
  property int expandedWidth: 900
  property int sliceHeight:   520
  property int skewOffset:    35
  property int sliceSpacing:  -22
  property int cardWidth:    1600

  property bool cardVisible: false
  property string wallsDir:  Quickshell.env("HOME") + "/Pictures/wallpapers"
  property string cacheDir:  Quickshell.env("HOME") + "/.cache"
  property string thumbDir:  Quickshell.env("HOME") + "/.cache/wallpaper_thumb"
  property var wallpapers:   []
  property string typeFilter: ""     // "" | "image" | "video" | "gif"
  property string sortMode:   "name" // "name" | "date"

  // Detectar si es video
  function isVideo(f) {
    var low = (f||"").toLowerCase()
    return low.endsWith(".mp4") || low.endsWith(".mkv") || low.endsWith(".mov") || low.endsWith(".webm")
  }
  function isGif(f)   { return (f||"").toLowerCase().endsWith(".gif") }
  function isAnimated(f) { return isVideo(f) || isGif(f) }

  // Preview: para video usa cache ~/.cache/video_preview/fname.png
  //          para gif  usa cache ~/.cache/gif_preview/fname.png
  //          para imagen usa thumbnail cacheado en ~/.cache/wallpaper_thumb/fname.jpg
  function previewSrc(f) {
    if (isVideo(f)) return "file://" + wallpaperPicker.cacheDir + "/video_preview/" + f + ".png"
    if (isGif(f))   return "file://" + wallpaperPicker.cacheDir + "/gif_preview/"   + f + ".png"
    return "file://" + wallpaperPicker.thumbDir + "/" + f + ".jpg"
  }

  Connections {
    target: root
    function onWallpaperPickerVisibleChanged() {
      if (root.wallpaperPickerVisible) {
        cardShowTimer.restart()
        resetIndexTimer.restart()
        if (wallpaperPicker.wallpapers.length === 0) listProc.running = true
        else rebuildModel()
      } else {
        wallpaperPicker.cardVisible = false
      }
    }
  }

  function rebuildModel() {
    updateFilteredModel()
  }

  Timer { id: cardShowTimer; interval: 50;
    onTriggered: { wallpaperPicker.cardVisible = true; focusTimer.restart() } }
  Timer { id: focusTimer; interval: 80; onTriggered: sliceListView.forceActiveFocus() }
  Timer { id: resetIndexTimer; interval: 100; onTriggered: {
      sliceListView.currentIndex = 0
      sliceListView.positionViewAtIndex(0, ListView.SnapPosition)
  }}

  ListModel { id: wallModel }
  ListModel { id: filteredWallModel }

  function updateFilteredModel() {
    var results = []
    for (var i = 0; i < wallModel.count; i++) {
      var item = wallModel.get(i)
      var f = item.filename
      if (wallpaperPicker.typeFilter === "image" && (wallpaperPicker.isVideo(f) || wallpaperPicker.isGif(f))) continue
      if (wallpaperPicker.typeFilter === "video" && !wallpaperPicker.isVideo(f)) continue
      if (wallpaperPicker.typeFilter === "gif"   && !wallpaperPicker.isGif(f)) continue
      results.push({ filename: f, mtime: item.mtime || 0 })
    }
    if (wallpaperPicker.sortMode === "date")
      results.sort(function(a, b) { return b.mtime - a.mtime })
    filteredWallModel.clear()
    for (var j = 0; j < results.length; j++) filteredWallModel.append(results[j])
    if (filteredWallModel.count > 0) {
      sliceListView.currentIndex = 0
      sliceListView.positionViewAtIndex(0, ListView.SnapPosition)
    }
  }

  onTypeFilterChanged: updateFilteredModel()
  onSortModeChanged:   updateFilteredModel()

  Process {
    id: listProc; property string buf: ""
    // Listar TODOS: imágenes + videos + gifs, ordenados
    command: ["bash", "-c",
      "find \"" + wallpaperPicker.wallsDir + "\" -maxdepth 1 -type f " +
      "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' " +
      "-o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \\) " +
      "-printf '%f\\t%T@\\n' | sort -k1,1"]
    stdout: SplitParser { splitMarker: ""; onRead: data => listProc.buf += data }
    onExited: {
      var rawLines = listProc.buf.trim().split("\n").filter(l => l !== "")
      var files = []
      wallModel.clear()
      for (var i = 0; i < rawLines.length; i++) {
        var parts = rawLines[i].split("\t")
        if (parts.length < 2) continue
        var fname = parts[0]; var mtime = parseFloat(parts[1]) || 0
        if (!fname) continue
        files.push(fname)
        wallModel.append({ filename: fname, mtime: mtime })
      }
      wallpaperPicker.wallpapers = files
      updateFilteredModel()
      listProc.buf = ""
      // Construir comando de generación de thumbnails/previews y lanzarlo
      var td = wallpaperPicker.thumbDir
      var wd = wallpaperPicker.wallsDir
      var cd = wallpaperPicker.cacheDir
      var cmds = ["mkdir -p \"" + td + "\" \"" + cd + "/video_preview\" \"" + cd + "/gif_preview\""]
      for (var i = 0; i < files.length; i++) {
        var f = files[i]; var full = wd + "/" + f
        if (wallpaperPicker.isVideo(f)) {
          var out = cd + "/video_preview/" + f + ".png"
          cmds.push("[ -f \"" + out + "\" ] || ffmpeg -v error -y -i \"" + full + "\" -ss 00:00:01.000 -vframes 1 \"" + out + "\" 2>/dev/null")
        } else if (wallpaperPicker.isGif(f)) {
          var out2 = cd + "/gif_preview/" + f + ".png"
          cmds.push("[ -f \"" + out2 + "\" ] || magick \"" + full + "[0]\" -resize 900x520 \"" + out2 + "\" 2>/dev/null")
        } else {
          var thumb = td + "/" + f + ".jpg"
          cmds.push("[ -f \"" + thumb + "\" ] || magick \"" + full + "\" -resize 900x520^ -gravity Center -extent 900x520 -quality 90 \"" + thumb + "\" 2>/dev/null")
        }
      }
      generatePreviews.command = ["bash", "-c", cmds.join("; ")]
      generatePreviews.running = true
    }
  }

  Process { id: generatePreviews; command: ["true"] }

  Process { id: applyProc; command: ["true"] }

  function applyWallpaper(filename) {
    var fullPath = wallpaperPicker.wallsDir + "/" + filename
    var script = Quickshell.env("HOME") + "/.config/hypr/UserScripts/WallpaperApply.sh"
    var type = isVideo(filename) ? "video" : "image"
    // Usar hyprctl dispatch exec para que el proceso corra en el entorno
    // de Hyprland con todos los env vars de Wayland correctos
    applyProc.command = ["hyprctl", "dispatch", "exec",
      "bash \"" + script + "\" " + type + " \"" + fullPath + "\""]
    applyProc.running = true
    root.wallpaperPickerVisible = false
  }

  PanelWindow {
    screen: Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "qs-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.wallpaperPickerVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    visible: root.wallpaperPickerVisible

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0,0,0,0.55)
      opacity: wallpaperPicker.cardVisible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.wallpaperPickerVisible = false }

    Item {
      id: cardContainer
      width: wallpaperPicker.cardWidth; height: wallpaperPicker.sliceHeight + 90
      anchors.centerIn: parent
      visible: wallpaperPicker.cardVisible
      opacity: 0
      property bool animateIn: wallpaperPicker.cardVisible
      onAnimateInChanged: { if (animateIn) { opacity = 0; fadeIn.start() } }
      NumberAnimation { id: fadeIn; target: cardContainer; property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
      MouseArea { anchors.fill: parent; onClicked: {} }

      // Barra de filtros
      Rectangle {
        anchors.top: parent.top; anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: filterRow.width + 24; height: 36; radius: 18; z: 10
        color: Qt.rgba(0.07, 0.08, 0.13, 0.88)
        border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.2)

        Row {
          id: filterRow
          anchors.centerIn: parent
          spacing: 6

          // Filtros por tipo
          Repeater {
            model: [
              { filter: "",       icon: "󰄶", tip: "Todo" },
              { filter: "image",  icon: "󰃩", tip: "Imagen" },
              { filter: "video",  icon: "󰅧", tip: "Video" },
              { filter: "gif",    icon: "󰵸", tip: "GIF" },
            ]
            delegate: Rectangle {
              width: 30; height: 24; radius: 4
              property bool sel: wallpaperPicker.typeFilter === modelData.filter
              property bool hov: tHov.containsMouse
              color: sel ? wallpaperPicker.clrPrimary : (hov ? Qt.rgba(0.38,0.45,0.64,0.2) : "transparent")
              border.width: sel ? 0 : 1
              border.color: hov ? Qt.rgba(0.38,0.45,0.64,0.4) : "transparent"
              Behavior on color { ColorAnimation { duration: 100 } }
              Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 14
                font.family: wallpaperPicker.fntI
                color: parent.sel ? "white" : wallpaperPicker.clrTertiary }
              MouseArea { id: tHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: wallpaperPicker.typeFilter = parent.sel ? "" : modelData.filter }
              ToolTip { visible: tHov.containsMouse; text: modelData.tip; delay: 400 }
            }
          }

          Rectangle { width: 1; height: 20; color: Qt.rgba(0.38,0.45,0.64,0.3) }

          // Orden
          Repeater {
            model: [
              { mode: "name", icon: "󰂺", tip: "A-Z" },
              { mode: "date", icon: "󰃰", tip: "Reciente" },
            ]
            delegate: Rectangle {
              width: 30; height: 24; radius: 4
              property bool sel: wallpaperPicker.sortMode === modelData.mode
              property bool hov: sHov.containsMouse
              color: sel ? wallpaperPicker.clrPrimary : (hov ? Qt.rgba(0.38,0.45,0.64,0.2) : "transparent")
              border.width: sel ? 0 : 1
              border.color: hov ? Qt.rgba(0.38,0.45,0.64,0.4) : "transparent"
              Behavior on color { ColorAnimation { duration: 100 } }
              Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 14
                font.family: wallpaperPicker.fntI
                color: parent.sel ? "white" : wallpaperPicker.clrTertiary }
              MouseArea { id: sHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: wallpaperPicker.sortMode = modelData.mode }
              ToolTip { visible: sHov.containsMouse; text: modelData.tip; delay: 400 }
            }
          }

          Rectangle { width: 1; height: 20; color: Qt.rgba(0.38,0.45,0.64,0.3) }

          // Contador
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: filteredWallModel.count + (filteredWallModel.count !== wallModel.count ? "/" + wallModel.count : "") + " 󰥶"
            font.family: wallpaperPicker.fnt; font.pixelSize: 10; font.weight: Font.Bold
            color: Qt.rgba(0.38,0.45,0.64,0.7)
          }
        }
      }
    }

    ListView {
      id: sliceListView
      anchors.top: cardContainer.top; anchors.topMargin: 52
      anchors.bottom: cardContainer.bottom; anchors.bottomMargin: 10
      anchors.horizontalCenter: parent.horizontalCenter
      property int visibleCount: 12
      width: wallpaperPicker.expandedWidth + (visibleCount-1)*(wallpaperPicker.sliceWidth+wallpaperPicker.sliceSpacing)
      orientation: ListView.Horizontal
      model: filteredWallModel; clip: false; spacing: wallpaperPicker.sliceSpacing
      flickDeceleration: 1500; maximumFlickVelocity: 3000
      boundsBehavior: Flickable.StopAtBounds
      cacheBuffer: wallpaperPicker.expandedWidth * 3
      visible: wallpaperPicker.cardVisible
      highlightFollowsCurrentItem: true; highlightMoveDuration: 350
      highlight: Item {}
      preferredHighlightBegin: (width - wallpaperPicker.expandedWidth) / 2
      preferredHighlightEnd:   (width + wallpaperPicker.expandedWidth) / 2
      highlightRangeMode: ListView.ApplyRange
      header: Item { width: (sliceListView.width - wallpaperPicker.expandedWidth) / 2; height: 1 }
      footer: Item { width: (sliceListView.width - wallpaperPicker.expandedWidth) / 2; height: 1 }
      focus: root.wallpaperPickerVisible
      onVisibleChanged: { if (visible) forceActiveFocus() }

      MouseArea {
        anchors.fill: parent; propagateComposedEvents: true
        onWheel: function(w) {
          if (w.angleDelta.y > 0 || w.angleDelta.x > 0) sliceListView.currentIndex = Math.max(0, sliceListView.currentIndex-1)
          else sliceListView.currentIndex = Math.min(filteredWallModel.count-1, sliceListView.currentIndex+1)
        }
        onPressed: m => m.accepted = false; onReleased: m => m.accepted = false; onClicked: m => m.accepted = false
      }

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape)  { root.wallpaperPickerVisible = false; event.accepted = true; return }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (currentIndex >= 0 && currentIndex < filteredWallModel.count)
            wallpaperPicker.applyWallpaper(filteredWallModel.get(currentIndex).filename)
          event.accepted = true; return
        }
        if ((event.key === Qt.Key_Left  || event.key === Qt.Key_Up)   && currentIndex > 0)                        { currentIndex--; event.accepted = true }
        if ((event.key === Qt.Key_Right || event.key === Qt.Key_Down) && currentIndex < filteredWallModel.count-1) { currentIndex++; event.accepted = true }
      }

      delegate: Item {
        id: delegateItem
        width: isCurrent ? wallpaperPicker.expandedWidth : wallpaperPicker.sliceWidth
        height: sliceListView.height
        property bool isCurrent: ListView.isCurrentItem
        property bool isHov: sliceMouse.containsMouse
        property bool animated: wallpaperPicker.isAnimated(model.filename)
        property bool isVid:    wallpaperPicker.isVideo(model.filename)
        property bool videoActive: false
        property bool videoReady: false

        onIsCurrentChanged: {
          if (isCurrent && isVid) videoDelayTimer.restart()
          else { videoDelayTimer.stop(); videoFrameTimer.stop(); videoActive = false; videoReady = false }
        }
        Timer { id: videoDelayTimer; interval: 300; onTriggered: delegateItem.videoActive = true }
        // Espera 2 frames extra despues de PlayingState antes de ocultar el thumb.
        Timer { id: videoFrameTimer; interval: 80; onTriggered: delegateItem.videoReady = true }
        z: isCurrent ? 100 : (isHov ? 90 : (50 - Math.min(Math.abs(index - sliceListView.currentIndex),50)))
        property real viewX:    x - sliceListView.contentX
        property real fadeZone: wallpaperPicker.sliceWidth * 1.5
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
            var w = delegateItem.width; var h = delegateItem.height; var sk = wallpaperPicker.skewOffset
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
            var ox=10,oy=10,w=delegateItem.width,h=delegateItem.height,sk=wallpaperPicker.skewOffset
            var sx=delegateItem.isCurrent?4:2, sy=delegateItem.isCurrent?10:5
            var layers=[{dx:sx,dy:sy,alpha:shadowAlpha*0.5},{dx:sx*0.6,dy:sy*0.6,alpha:shadowAlpha*0.3},{dx:sx*1.4,dy:sy*1.4,alpha:shadowAlpha*0.2}]
            for(var i=0;i<layers.length;i++){var l=layers[i];ctx.globalAlpha=l.alpha;ctx.fillStyle="#000";ctx.beginPath();ctx.moveTo(ox+sk+l.dx,oy+l.dy);ctx.lineTo(ox+w+l.dx,oy+l.dy);ctx.lineTo(ox+w-sk+l.dx,oy+h+l.dy);ctx.lineTo(ox+l.dx,oy+h+l.dy);ctx.closePath();ctx.fill()}
          }
        }

        Item {
          id: imageContainer; anchors.fill: parent
          // Fondo oscuro base
          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.07, 0.12, 1) }
              GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.04, 0.08, 1) }
            }
          }
          // Thumbnail siempre presente — nunca desaparece
          Image {
            id: thumbImg; anchors.fill: parent
            source: wallpaperPicker.previewSrc(model.filename)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; smooth: true; mipmap: true; cache: true
            sourceSize.width:  wallpaperPicker.expandedWidth
            sourceSize.height: wallpaperPicker.sliceHeight
            visible: !delegateItem.videoReady
          }

          // Full res — se carga encima sin tocar el thumbnail
          Image {
            id: fullImg; anchors.fill: parent
            source: (delegateItem.isCurrent && !wallpaperPicker.isAnimated(model.filename))
              ? "file://" + wallpaperPicker.wallsDir + "/" + model.filename
              : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; smooth: true; mipmap: true; cache: true
            sourceSize.width:  wallpaperPicker.expandedWidth
            sourceSize.height: wallpaperPicker.sliceHeight
            // Solo se muestra cuando ya terminó de cargar completamente
            visible: !delegateItem.videoReady && status === Image.Ready
            opacity: 0
            onStatusChanged: {
              if (status === Image.Ready) fadeFullRes.start()
            }
            NumberAnimation {
              id: fadeFullRes; target: fullImg; property: "opacity"
              from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic
            }
            onSourceChanged: { opacity = 0; fadeFullRes.stop() }
          }
          // Reproducción en vivo para videos (igual que piixident)
          Loader {
            id: videoLoader
            anchors.fill: parent
            active: delegateItem.videoActive
            property bool isPlaying: active && status === Loader.Ready && delegateItem.videoActive
            sourceComponent: Item {
              anchors.fill: parent
              Video {
                anchors.fill: parent
                source: "file://" + wallpaperPicker.wallsDir + "/" + model.filename
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                Component.onCompleted: play()
                onPlaybackStateChanged: {
                  if (playbackState === MediaPlayer.PlayingState)
                    videoFrameTimer.restart()
                }
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
                        startX: wallpaperPicker.skewOffset; startY: 0
                        PathLine { x: delegateItem.width;                              y: 0 }
                        PathLine { x: delegateItem.width - wallpaperPicker.skewOffset; y: delegateItem.height }
                        PathLine { x: 0;                                               y: delegateItem.height }
                        PathLine { x: wallpaperPicker.skewOffset;                      y: 0 }
                      }
                    }
                  }
                }
                maskThresholdMin: 0.3; maskSpreadAtMin: 0.3
              }
            }
          }
          // Ícono fallback si no cargó el preview
          Text {
            anchors.centerIn: parent
            visible: thumbImg.status !== Image.Ready && !videoLoader.isPlaying
            text: delegateItem.animated ? "󰎁" : "󰥶"
            font.family: wallpaperPicker.fntI; font.pixelSize: 48
            color: Qt.rgba(0.38,0.45,0.64,0.35)
          }
          // Oscurecer las no-seleccionadas
          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0,0,0, delegateItem.isCurrent ? 0 : (delegateItem.isHov ? 0.15 : 0.55))
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
                    startX: wallpaperPicker.skewOffset; startY: 0
                    PathLine { x: delegateItem.width;                              y: 0 }
                    PathLine { x: delegateItem.width - wallpaperPicker.skewOffset; y: delegateItem.height }
                    PathLine { x: 0;                                               y: delegateItem.height }
                    PathLine { x: wallpaperPicker.skewOffset;                      y: 0 }
                  }
                }
              }
            }
            maskThresholdMin: 0.3; maskSpreadAtMin: 0.3
          }
        }

        // Borde parallelogram
        Shape {
          anchors.fill: parent; antialiasing: true; preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "transparent"
            strokeColor: delegateItem.isCurrent ? wallpaperPicker.clrPrimary
              : (delegateItem.isHov ? Qt.rgba(0.38,0.45,0.64,0.4) : Qt.rgba(0,0,0,0.6))
            Behavior on strokeColor { ColorAnimation { duration: 200 } }
            strokeWidth: delegateItem.isCurrent ? 3 : 1
            startX: wallpaperPicker.skewOffset; startY: 0
            PathLine { x: delegateItem.width;                              y: 0 }
            PathLine { x: delegateItem.width - wallpaperPicker.skewOffset; y: delegateItem.height }
            PathLine { x: 0;                                               y: delegateItem.height }
            PathLine { x: wallpaperPicker.skewOffset;                      y: 0 }
          }
        }

        // Badge LIVE / GIF para animados
        Rectangle {
          visible: delegateItem.animated
          anchors.top: parent.top; anchors.topMargin: 10
          anchors.right: parent.right; anchors.rightMargin: wallpaperPicker.skewOffset + 6
          width: liveLabel.width + 10; height: 18; radius: 9; z: 10
          color: "#ff5555"
          Text { id: liveLabel; anchors.centerIn: parent
            text: wallpaperPicker.isGif(model.filename) ? "GIF" : "󰎁 LIVE"
            font.family: wallpaperPicker.fnt; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: "white" }
        }

        // Badge nombre (visible cuando seleccionado)
        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 36
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(nameText.implicitWidth + 24, delegateItem.width - 50)
          height: 32; radius: 6; z: 10
          color: Qt.rgba(0,0,0,0.80)
          border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.5)
          visible: delegateItem.isCurrent
          opacity: delegateItem.isCurrent ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 200 } }
          Text {
            id: nameText; anchors.centerIn: parent
            text: model.filename
            font.family: wallpaperPicker.fnt; font.pixelSize: 10; font.weight: Font.Bold
            color: wallpaperPicker.clrTertiary
            elide: Text.ElideMiddle
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
          }
        }

        // Badge "ENTER para aplicar"
        Rectangle {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 8
          anchors.horizontalCenter: parent.horizontalCenter
          width: applyHint.width + 10; height: 18; radius: 4; z: 10
          color: Qt.rgba(0,0,0,0.75); border.width: 1; border.color: Qt.rgba(0.38,0.45,0.64,0.4)
          visible: delegateItem.isCurrent
          Text { id: applyHint; anchors.centerIn: parent
            text: delegateItem.animated ? " ENTER — aplicar animado" : " ENTER — aplicar"
            font.family: wallpaperPicker.fnt; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.5
            color: delegateItem.animated ? "#ff5555" : wallpaperPicker.clrTertiary }
        }

        MouseArea {
          id: sliceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          property real lastX: -1; property real lastY: -1
          onPositionChanged: function(m) {
            var g = mapToItem(sliceListView, m.x, m.y)
            if (Math.abs(g.x-lastX)>2 || Math.abs(g.y-lastY)>2) { lastX=g.x; lastY=g.y; sliceListView.currentIndex = index }
          }
          onClicked: {
            if (delegateItem.isCurrent) wallpaperPicker.applyWallpaper(model.filename)
            else sliceListView.currentIndex = index
          }
        }
      }
    }
  }
}
