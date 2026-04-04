import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "./dashboard"
import "./toppanel"

// Panel superior con 5 pestañas — diseño idéntico al dashboard de ambxst
// (columna de tabs a la izquierda + separador + área de contenido)
//
//  Tab 0 – widgets   : App launcher / apps frecuentes
//  Tab 1 – wallpapers: Galería ~/Pictures/wallpapers (click → swww)
//  Tab 2 – heartbeat : SystemStats (CPU/RAM/Disco)
//  Tab 3 – assistant : Asistente (chat IA placeholder)
//  Tab 4 – notepad   : NotesWidget + AppVolumeWidget  ← la que ya tenías
PanelWindow {
    id: topPanel

    anchors { top: true; left: true; right: true }
    implicitHeight: 500
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.topPanelVisible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    margins.top: root.topPanelVisible ? 48 : -(implicitHeight + 12)
    Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // ── Estado ───────────────────────────────────────────────────────────────
    property int currentTab: 0

    readonly property int tabCount:   5
    readonly property int tabWidth:   48
    readonly property int tabSpacing: 8
    readonly property int animMs:     250

    // Phosphor-Bold (cargado en shell.qml)
    readonly property var tabIcons:    ["\ueb02", "\ue6c8", "\ue2ac", "\ue6a2", "\ue63e"]
    readonly property var tabTooltips: ["Apps", "Fondos", "Métricas", "Asistente", "Notas / Volumen"]

    function navigateTo(idx) { currentTab = idx }

    // ── Colores (mismos que el TopPanel original) ─────────────────────────────
    readonly property color clrBg:      "#0d0d0d"
    readonly property color clrSurface: "#161616"
    readonly property color clrBorder:  "#2a2a2a"
    readonly property color clrText:    "#e0e0e0"
    readonly property color clrSubtext: "#606060"
    readonly property color clrAccent:  "#ffffff"

    // ── Tema (ambxst DashTheme) ────────────────────────────────────────────────
    DashTheme { id: theme }

    // ── Monitor de recursos del sistema (= SystemResources de ambxst) ──────────
    SysResources { id: sysRes }
    Binding { target: sysRes; property: "active"; value: topPanel.currentTab === 2 && root.topPanelVisible }

    // ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill:        parent
        anchors.leftMargin:  60
        anchors.rightMargin: 60
        color:  topPanel.clrBg
        radius: 16
        border.width: 1
        border.color: topPanel.clrBorder
        focus: root.topPanelVisible
        clip:  true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.topPanelVisible = false
                event.accepted = true
            }
        }

        Row {
            anchors.fill:    parent
            anchors.margins: 8
            spacing: 8

            // ── Columna de pestañas ───────────────────────────────────────────
            Item {
                id: tabsCol
                width:  topPanel.tabWidth
                height: parent.height

                // Rueda del ratón
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var up = event.angleDelta.y > 0
                        var n  = topPanel.currentTab
                        if (up  && n > 0)                          n--
                        else if (update && n < topPanel.tabCount - 1) n++
                        if (n !== topPanel.currentTab) topPanel.navigateTo(n)
                    }
                }

                // ── Indicador de selección con efecto goma (= ambxst) ─────────
                Rectangle {
                    id: tabHighlight
                    width:  parent.width
                    radius: 8
                    color:  Qt.rgba(1, 1, 1, 0.06)
                    z: 0

                    function yFor(idx) {
                        return idx * (topPanel.tabWidth + topPanel.tabSpacing)
                    }

                    property real targetY: yFor(topPanel.currentTab)
                    property real fast:    targetY
                    property real slow:    targetY

                    onTargetYChanged: { fast = targetY; slow = targetY }

                    Behavior on fast { NumberAnimation { duration: topPanel.animMs / 3; easing.type: Easing.OutSine } }
                    Behavior on slow { NumberAnimation { duration: topPanel.animMs;     easing.type: Easing.OutSine } }

                    x:      0
                    y:      Math.min(fast, slow)
                    height: Math.abs(fast - slow) + topPanel.tabWidth
                }

                // ── Botones ───────────────────────────────────────────────────
                Column {
                    anchors.top:   parent.top
                    anchors.left:  parent.left
                    anchors.right: parent.right
                    spacing: topPanel.tabSpacing

                    Repeater {
                        model: topPanel.tabIcons

                        Rectangle {
                            required property string modelData
                            required property int    index

                            width:  topPanel.tabWidth
                            height: topPanel.tabWidth
                            radius: 8
                            color:  "transparent"
                            z: 1

                            Text {
                                anchors.centerIn: parent
                                text:        modelData
                                font.family: "Phosphor-Bold"
                                font.pixelSize: 20
                                color: topPanel.currentTab === index
                                    ? topPanel.clrAccent
                                    : topPanel.clrSubtext
                                Behavior on color { ColorAnimation { duration: topPanel.animMs } }
                            }

                            // Tooltip
                            Rectangle {
                                visible: tabHover.containsMouse
                                anchors.left:           parent.right
                                anchors.leftMargin:     6
                                anchors.verticalCenter: parent.verticalCenter
                                width:  tipText.implicitWidth + 14
                                height: 24
                                radius: 6
                                color:  topPanel.clrSurface
                                border.color: topPanel.clrBorder
                                border.width: 1
                                z: 99

                                Text {
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: topPanel.tabTooltips[index] || ""
                                    color: topPanel.clrText
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }

                            MouseArea {
                                id: tabHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: topPanel.navigateTo(index)
                            }
                        }
                    }
                }
            } // tabsCol

            // ── Separador vertical ────────────────────────────────────────────
            Rectangle {
                width:  1
                height: parent.height
                color:  topPanel.clrBorder
            }

            // ── Área de contenido ─────────────────────────────────────────────
            Item {
                id: contentArea
                width:  parent.width - topPanel.tabWidth - 8 - 1 - 8
                height: parent.height
                clip:   true

                // Cada pestaña: opacity + traslación vertical (= ambxst)
                component TabPane : Item {
                    required property int paneIndex
                    anchors.fill: parent

                    readonly property bool active: topPanel.currentTab === paneIndex
                    opacity: active ? 1.0 : 0.0
                    enabled: active  // Inactive tabs must NOT intercept mouse/keyboard events

                    transform: Translate {
                        y: active ? 0 : (topPanel.currentTab > paneIndex ? -18 : 18)
                        Behavior on y { NumberAnimation { duration: topPanel.animMs; easing.type: Easing.OutQuart } }
                    }
                    Behavior on opacity { NumberAnimation { duration: topPanel.animMs; easing.type: Easing.OutQuart } }
                }

                // ── Tab 0: Widgets — layout idéntico al WidgetsTab de ambxst ──────────
                // FullPlayer | QuickControls+Calendar | NotificationHistory | Sliders verticales
                TabPane {
                    id: widgetsPane
                    paneIndex: 0

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // ── Col 1: reproductor de música (216px) ──────────────
                        FullPlayer {
                            Layout.preferredWidth: 216
                            Layout.fillHeight: true
                        }

                        Rectangle { width: 1; Layout.fillHeight: true; color: topPanel.clrBorder }

                        // ── Col 2: controles rápidos + calendario (ancho fijo) ─
                        Item {
                            id: widgetsColumn
                            Layout.preferredWidth: ambxstQC.implicitWidth
                            Layout.fillHeight: true

                            Flickable {
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: innerCol.implicitHeight
                                clip: true

                                ColumnLayout {
                                    id: innerCol
                                    width: parent.width
                                    spacing: 8

                                    AmbxstQuickControls {
                                        id: ambxstQC
                                        Layout.fillWidth: true
                                    }

                                    AmbxstCalendar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: width
                                    }
                                }
                            }
                        }

                        Rectangle { width: 1; Layout.fillHeight: true; color: topPanel.clrBorder }

                        // ── Col 3: notificaciones (fill) ──────────────────────
                        AmbxstNotificationHistory {
                            Layout.fillWidth:  true
                            Layout.fillHeight: true
                        }

                        Rectangle { width: 1; Layout.fillHeight: true; color: topPanel.clrBorder }

                        ClipboardWidget {
                            Layout.preferredWidth: 300
                            Layout.fillHeight: true
                            active: widgetsPane.active && root.topPanelVisible
                        }

                        Rectangle { width: 1; Layout.fillHeight: true; color: topPanel.clrBorder }

                        // ── Col 4: volumen por aplicaciones ───────────────────
                        AppVolumeWidget {
                            Layout.preferredWidth: 308
                            Layout.fillHeight: true
                        }

                        Rectangle { width: 1; Layout.fillHeight: true; color: topPanel.clrBorder }

                        // ── Col 5: sliders verticales brillo + volumen (48px) ─
                        AmbxstVerticalSliders {
                            Layout.preferredWidth: 48
                            Layout.fillHeight: true
                        }
                    }
                } // Tab 0

                // ── Tab 1: Fondos de pantalla — igual que ambxst WallpapersTab ──
                TabPane {
                    id: wallTab
                    paneIndex: 1

                    readonly property string wallsDir:  Quickshell.env("HOME") + "/Pictures/wallpapers"
                    readonly property string thumbDir:  Quickshell.env("HOME") + "/.cache/wallpaper_thumb"
                    readonly property string cacheDir:  Quickshell.env("HOME") + "/.cache"

                    // ── Estado ─────────────────────────────────────────────────────────
                    property string typeFilter:    ""      // "" | "image" | "video" | "gif"
                    property string sortMode:      "name"  // "name" | "date"
                    property string searchText:    ""
                    property int    selectedIndex: -1
                    property string currentWallpaper: ""  // ruta completa del fondo activo
                    readonly property int gridColumns: 7
                    readonly property int wallMargin:  4

                    // ── Datos ───────────────────────────────────────────────────────────
                    property var allWalls: []        // [{filename, mtime}]
                    property var filteredWalls: []   // [{filename, mtime}] filtrado

                    // ── Helpers ─────────────────────────────────────────────────────────
                    function isVideo(f) {
                        var l = (f || "").toLowerCase()
                        return l.endsWith(".mp4") || l.endsWith(".mkv") || l.endsWith(".mov") || l.endsWith(".webm")
                    }
                    function isGif(f) { return (f || "").toLowerCase().endsWith(".gif") }
                    function isAnimated(f) { return isVideo(f) || isGif(f) }

                    function previewSrc(f) {
                        if (isVideo(f)) return "file://" + wallTab.cacheDir + "/video_preview/" + f + ".png"
                        if (isGif(f))   return "file://" + wallTab.cacheDir + "/gif_preview/"   + f + ".png"
                        return "file://" + wallTab.thumbDir + "/" + f + ".jpg"
                    }

                    function updateFilter() {
                        var q  = wallTab.searchText.toLowerCase()
                        var tf = wallTab.typeFilter
                        var result = []
                        for (var i = 0; i < wallTab.allWalls.length; i++) {
                            var item = wallTab.allWalls[i]
                            var f    = item.filename
                            if (q  && f.toLowerCase().indexOf(q) === -1) continue
                            if (tf === "image"  && (isVideo(f) || isGif(f))) continue
                            if (tf === "video"  && !isVideo(f))              continue
                            if (tf === "gif"    && !isGif(f))                continue
                            result.push(item)
                        }
                        if (wallTab.sortMode === "date")
                            result.sort(function(a, b) { return b.mtime - a.mtime })
                        wallTab.filteredWalls = result
                        if (wallTab.selectedIndex >= result.length)
                            wallTab.selectedIndex = result.length > 0 ? 0 : -1
                    }

                    function applyWallpaper(filename) {
                        var fullPath = wallTab.wallsDir + "/" + filename
                        var script   = Quickshell.env("HOME") + "/.config/hypr/UserScripts/WallpaperApply.sh"
                        var t        = isVideo(filename) ? "video" : "image"
                        wallApplyProc2.command = ["bash", script, t, fullPath]
                        wallApplyProc2.running = false
                        wallApplyProc2.running = true
                        wallTab.currentWallpaper = fullPath
                    }

                    onTypeFilterChanged:  updateFilter()
                    onSortModeChanged:    updateFilter()
                    onSearchTextChanged:  updateFilter()

                    onActiveChanged: {
                        if (active) {
                            // Leer fondo actual del symlink
                            readCurrentProc.running = false
                            readCurrentProc.running = true
                            // Cargar lista si vacía
                            if (wallTab.allWalls.length === 0 && !wallListProc.running) {
                                wallListProc.buf = ""
                                wallListProc.running = true
                            }
                        }
                    }

                    // ── Procesos ────────────────────────────────────────────────────────
                    Process {
                        id: readCurrentProc
                        command: ["readlink", "-f", Quickshell.env("HOME") + "/.config/hypr/wallpaper_effects/.wallpaper_current"]
                        stdout: SplitParser { onRead: data => { var p = data.trim(); if (p) wallTab.currentWallpaper = p } }
                    }

                    Process {
                        id:  wallListProc
                        property string buf: ""
                        command: ["bash", "-c",
                            "find \"" + wallTab.wallsDir + "\" -maxdepth 1 -type f " +
                            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' " +
                            "-o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \\) " +
                            "-printf '%f\\t%T@\\n' | sort -k1,1"]
                        stdout: SplitParser { splitMarker: ""; onRead: data => wallListProc.buf += data }
                        onExited: {
                            var lines = wallListProc.buf.trim().split("\n").filter(l => l !== "")
                            var walls = []
                            for (var i = 0; i < lines.length; i++) {
                                var parts = lines[i].split("\t")
                                if (parts.length < 2 || !parts[0]) continue
                                walls.push({ filename: parts[0], mtime: parseFloat(parts[1]) || 0 })
                            }
                            wallTab.allWalls = walls
                            wallTab.updateFilter()
                            wallListProc.buf = ""
                            // Generar thumbnails
                            var td = wallTab.thumbDir; var wd = wallTab.wallsDir; var cd = wallTab.cacheDir
                            var cmds = ["mkdir -p \"" + td + "\" \"" + cd + "/video_preview\" \"" + cd + "/gif_preview\""]
                            for (var j = 0; j < walls.length; j++) {
                                var f = walls[j].filename; var full = wd + "/" + f
                                if (wallTab.isVideo(f)) {
                                    var vo = cd + "/video_preview/" + f + ".png"
                                    cmds.push("[ -f \"" + vo + "\" ] || ffmpeg -v error -y -i \"" + full + "\" -ss 00:00:01.000 -vframes 1 \"" + vo + "\" 2>/dev/null")
                                } else if (wallTab.isGif(f)) {
                                    var go = cd + "/gif_preview/" + f + ".png"
                                    cmds.push("[ -f \"" + go + "\" ] || magick \"" + full + "[0]\" -resize 300x300 \"" + go + "\" 2>/dev/null")
                                } else {
                                    var th = td + "/" + f + ".jpg"
                                    cmds.push("[ -f \"" + th + "\" ] || magick \"" + full + "\" -resize 300x300^ -gravity Center -extent 300x300 -quality 80 \"" + th + "\" 2>/dev/null")
                                }
                            }
                            wallThumbProc.command = ["bash", "-c", cmds.join("; ")]
                            wallThumbProc.running = false
                            wallThumbProc.running = true
                        }
                    }

                    Process { id: wallThumbProc; command: ["true"] }
                    Process { id: wallApplyProc2; command: ["true"] }

                    // ── UI — idéntico a ambxst WallpapersTab ────────────────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // ── Barra superior ─────────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            spacing: 6

                            // Búsqueda
                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 8
                                color:  topPanel.clrSurface
                                border.color: wallSearch2.activeFocus ? "#6272a4" : topPanel.clrBorder
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    text: "\uf002"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                    color: topPanel.clrSubtext
                                }
                                TextInput {
                                    id: wallSearch2
                                    anchors { fill: parent; leftMargin: 30; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: topPanel.clrText
                                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                                    clip: true
                                    onTextChanged: wallTab.searchText = text
                                    Keys.onEscapePressed: {
                                        focus = false
                                        if (text !== "") { text = ""; wallTab.searchText = "" }
                                    }
                                    Keys.onDownPressed: {
                                        if (wallTab.filteredWalls.length > 0 && wallTab.selectedIndex < wallTab.filteredWalls.length - 1)
                                            wallTab.selectedIndex++
                                        wallGrid.positionViewAtIndex(wallTab.selectedIndex, GridView.Visible)
                                    }
                                    Keys.onUpPressed: {
                                        if (wallTab.selectedIndex > 0) wallTab.selectedIndex--
                                        wallGrid.positionViewAtIndex(wallTab.selectedIndex, GridView.Visible)
                                    }
                                    Keys.onReturnPressed: {
                                        if (wallTab.selectedIndex >= 0 && wallTab.selectedIndex < wallTab.filteredWalls.length)
                                            wallTab.applyWallpaper(wallTab.filteredWalls[wallTab.selectedIndex].filename)
                                    }
                                }
                                Text {
                                    anchors { fill: parent; leftMargin: 30 }
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search wallpapers..."
                                    color: topPanel.clrSubtext
                                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                                    visible: wallSearch2.text === "" && !wallSearch2.activeFocus
                                }
                            }

                            // Contador
                            Text {
                                text: wallTab.filteredWalls.length +
                                      (wallTab.filteredWalls.length !== wallTab.allWalls.length ? "/" + wallTab.allWalls.length : "")
                                color: topPanel.clrSubtext; font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        // FilterBar — chips de texto idénticos a ambxst FilterBar ─────
                        Row {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [
                                    { filter: "image", label: "Images" },
                                    { filter: "gif",   label: "GIF"    },
                                    { filter: "video", label: "Videos" }
                                ]
                                delegate: Item {
                                    required property var modelData
                                    property bool sel: wallTab.typeFilter === modelData.filter
                                    property bool hov: chipMa.containsMouse
                                    width: chipCont.implicitWidth + 24; height: 32
                                    Behavior on width { NumberAnimation { duration: 83; easing.type: Easing.OutCubic } }

                                    Rectangle {
                                        anchors.fill: parent; radius: 6
                                        color: (sel && hov) ? "#7282b4" : sel ? "#6272a4" : hov ? Qt.rgba(1,1,1,0.07) : "transparent"
                                        border.width: 1; border.color: sel ? "#6272a4" : hov ? "#6272a4" : topPanel.clrBorder
                                        Behavior on color { ColorAnimation { duration: 83 } }
                                    }

                                    Row {
                                        id: chipCont; anchors.centerIn: parent; spacing: sel ? 4 : 0
                                        Behavior on spacing { NumberAnimation { duration: 83 } }

                                        Item {
                                            width: sel ? chkIco.width : 0; height: chkIco.height; clip: true
                                            Behavior on width { NumberAnimation { duration: 83; easing.type: Easing.OutCubic } }
                                            Text {
                                                id: chkIco; text: "\ue182"
                                                font.family: "Phosphor-Bold"; font.pixelSize: 14
                                                color: "#ffffff"; opacity: sel ? 1.0 : 0.0
                                                Behavior on opacity { NumberAnimation { duration: 83 } }
                                            }
                                        }
                                        Text {
                                            text: modelData.label
                                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                            color: sel ? "#ffffff" : topPanel.clrText
                                        }
                                    }

                                    MouseArea {
                                        id: chipMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: wallTab.typeFilter = sel ? "" : modelData.filter
                                    }
                                }
                            }
                        }

                        // ── GridView — 7 columnas cuadradas (igual que ambxst) ────────
                        Item {
                            id: wallGridContainer
                            Layout.fillWidth:  true
                            Layout.fillHeight: true
                            clip: true

                            readonly property real cellSize: Math.floor(width / wallTab.gridColumns)

                            GridView {
                                id: wallGrid
                                anchors.fill: parent
                                anchors.margins: -wallTab.wallMargin
                                cellWidth:  wallGridContainer.cellSize + wallTab.wallMargin * 2
                                cellHeight: wallGridContainer.cellSize + wallTab.wallMargin * 2
                                flow: GridView.FlowLeftToRight
                                boundsBehavior: Flickable.StopAtBounds
                                model: wallTab.filteredWalls
                                currentIndex: wallTab.selectedIndex
                                cacheBuffer: cellHeight
                                displayMarginBeginning: cellHeight
                                displayMarginEnd: cellHeight
                                flickDeceleration: 5000
                                maximumFlickVelocity: 8000
                                clip: true
                                // highlight sincronizado con selectedIndex
                                highlightFollowsCurrentItem: true
                                highlightMoveDuration: 150

                                onCurrentIndexChanged: {
                                    if (currentIndex !== wallTab.selectedIndex && currentIndex >= 0)
                                        wallTab.selectedIndex = currentIndex
                                }

                                // ── Highlight — borde + label (= ambxst) ──────────────
                                highlight: Item {
                                    width:  wallGrid.cellWidth
                                    height: wallGrid.cellHeight
                                    z: 100

                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width:  wallGrid.cellWidth  - wallTab.wallMargin * 2
                                        height: wallGrid.cellHeight - wallTab.wallMargin * 2
                                        radius: 8
                                        color:  "transparent"
                                        border.color: "#6272a4"
                                        border.width: 2
                                        visible: wallTab.selectedIndex >= 0
                                        z: 10

                                        // Marco exterior negro (igual que ambxst)
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -24
                                            color: "transparent"
                                            border.color: topPanel.clrBg
                                            border.width: 28
                                            radius: 32
                                            z: 5

                                            // Etiqueta con nombre y scroll (= ambxst)
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.left:   parent.left
                                                anchors.right:  parent.right
                                                height: 28
                                                color:  "transparent"
                                                z: 6
                                                clip: true
                                                visible: wallTab.selectedIndex >= 0

                                                property bool isCurrentWallpaper: {
                                                    if (wallTab.selectedIndex < 0 || wallTab.selectedIndex >= wallTab.filteredWalls.length) return false
                                                    return wallTab.wallsDir + "/" + wallTab.filteredWalls[wallTab.selectedIndex].filename === wallTab.currentWallpaper
                                                }

                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: wallGrid.cellWidth - 20
                                                    height: parent.height
                                                    color: "transparent"
                                                    clip: true

                                                    Text {
                                                        id: hlLabel
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        x: 4
                                                        text: {
                                                            if (parent.parent.parent.isCurrentWallpaper) return "CURRENT"
                                                            if (wallTab.selectedIndex >= 0 && wallTab.selectedIndex < wallTab.filteredWalls.length)
                                                                return wallTab.filteredWalls[wallTab.selectedIndex].filename
                                                            return ""
                                                        }
                                                        color: parent.parent.parent.isCurrentWallpaper ? "#6272a4" : topPanel.clrText
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        readonly property bool needsScroll: contentWidth > parent.width - 8

                                                        onTextChanged: { if (needsScroll) x = 4 }
                                                        onNeedsScrollChanged: { if (needsScroll) { x = 4; hlScroll.restart() } }

                                                        SequentialAnimation {
                                                            id: hlScroll
                                                            running: hlLabel.needsScroll && !parent.parent.parent.parent.isCurrentWallpaper
                                                            loops: Animation.Infinite
                                                            PauseAnimation { duration: 1000 }
                                                            NumberAnimation { target: hlLabel; property: "x"
                                                                to: hlLabel.parent.width - hlLabel.contentWidth - 4
                                                                duration: 2000; easing.type: Easing.InOutQuad }
                                                            PauseAnimation { duration: 1000 }
                                                            NumberAnimation { target: hlLabel; property: "x"
                                                                to: 4; duration: 2000; easing.type: Easing.InOutQuad }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Delegate ─────────────────────────────────────────
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width:  wallGrid.cellWidth
                                    height: wallGrid.cellHeight

                                    property bool isCurrentWall: wallTab.wallsDir + "/" + modelData.filename === wallTab.currentWallpaper
                                    property bool isHovered: false
                                    property bool isSelected: wallTab.selectedIndex === index

                                    // Lazy loading — solo cargar si está visible en el viewport
                                    readonly property bool isInViewport: {
                                        var top    = wallGrid.contentY
                                        var bottom = top + wallGrid.height
                                        var buf    = wallGrid.cellHeight
                                        return (y + height + buf >= top) && (y - buf <= bottom)
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: wallTab.wallMargin

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color:  topPanel.clrSurface
                                            clip:   true

                                            // Carga lazy del thumbnail
                                            Loader {
                                                anchors.fill: parent
                                                active: parent.parent.parent.isInViewport && wallTab.active
                                                asynchronous: true
                                                sourceComponent: Image {
                                                    anchors.fill: parent
                                                    source:      wallTab.previewSrc(modelData.filename)
                                                    fillMode:    Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    smooth: true
                                                    mipmap: true
                                                    cache:  true
                                                    sourceSize.width:  wallGridContainer.cellSize
                                                    sourceSize.height: wallGridContainer.cellSize
                                                    onStatusChanged: {
                                                        if (status === Image.Error)
                                                            source = "file://" + wallTab.wallsDir + "/" + modelData.filename
                                                    }
                                                }

                                                // Spinner mientras carga
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: topPanel.clrSurface
                                                    visible: parent.status !== Loader.Ready
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "\uf110"
                                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                                                        color: topPanel.clrSubtext
                                                        NumberAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: parent.visible }
                                                    }
                                                }
                                            }

                                            // Badge GIF/VIDEO
                                            Rectangle {
                                                visible: wallTab.isAnimated(modelData.filename)
                                                anchors { top: parent.top; left: parent.left; margins: 4 }
                                                width: typeLabel.width + 8; height: 16; radius: 4; z: 10
                                                color: "#ff5555"
                                                Text {
                                                    id: typeLabel; anchors.centerIn: parent
                                                    text: wallTab.isGif(modelData.filename) ? "GIF" : "LIVE"
                                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; font.weight: Font.Bold
                                                    color: "white"
                                                }
                                            }

                                            // Overlay oscuro al hover / no-seleccionado
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(0, 0, 0, parent.parent.isHovered ? 0.15 : 0)
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            // Overlay "CURRENT" — mismo estilo que ambxst
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.left:   parent.left
                                                anchors.right:  parent.right
                                                height: 24; color: Qt.rgba(0.07, 0.09, 0.14, 0.85)
                                                visible: parent.parent.parent.isCurrentWall
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "CURRENT"
                                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.weight: Font.Bold
                                                    font.letterSpacing: 1
                                                    color: "#6272a4"
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onEntered: {
                                            parent.isHovered = true
                                            wallTab.selectedIndex = index
                                        }
                                        onExited:  parent.isHovered = false
                                        onClicked: wallTab.applyWallpaper(modelData.filename)
                                    }

                                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                } // Tab 1

                // ── Tab 2: Heartbeat — diseño idéntico al MetricsTab de ambxst ──────
                TabPane {
                    id: metricsPane2
                    paneIndex: 2

                    property real chartZoom: 1.0
                    property string mHostname: ""
                    property string mOsName: ""

                    onActiveChanged: {
                        if (active) {
                            mHostnameProc.running = true
                            mOsProc.running = true
                        }
                    }

                    Process {
                        id: mHostnameProc; running: false; command: ["hostname"]
                        stdout: StdioCollector { waitForEnd: true
                            onStreamFinished: { var h = text.trim(); if (h) metricsPane2.mHostname = h.charAt(0).toUpperCase() + h.slice(1) } }
                    }
                    Process {
                        id: mOsProc; running: false
                        command: ["sh", "-c", "grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'"]
                        stdout: StdioCollector { waitForEnd: true
                            onStreamFinished: { var o = text.trim(); if (o) metricsPane2.mOsName = o } }
                    }

                    // Repintar canvas cuando llegan datos nuevos
                    Connections {
                        target: sysRes
                        function onCpuHistoryChanged() { if (metricsPane2.active) metricChart.requestPaint() }
                        function onRamHistoryChanged()  { if (metricsPane2.active) metricChart.requestPaint() }
                    }

                    // ResourceItem — copia exacta de ambxst ResourceItem.qml
                    component ResBar : Item {
                        property string icon: ""
                        property real   value: 0.0
                        property color  barColor: "#ffffff"
                        implicitHeight: 20

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            Text {
                                text: icon
                                color: topPanel.clrText
                                font.pixelSize: 15
                                font.family: "Phosphor-Bold"
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                Layout.alignment: Qt.AlignVCenter
                                radius: 3
                                color: "#0a0a0a"
                                border.width: 1
                                border.color: barColor

                                Rectangle {
                                    width: (parent.width - 6) * Math.max(0, Math.min(1, value))
                                    height: parent.height - 6
                                    radius: parent.radius - 1
                                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 3 }
                                    color: barColor
                                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    } // ResBar

                    // ── copia exacta de ambxst MetricsTab RowLayout raíz ──────────
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Left panel - Resources (width 250 = ambxst)
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 250
                            color: "transparent"

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 2

                                // User info section — copia exacta de ambxst
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    spacing: 16

                                    // Avatar
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 80
                                        radius: 40
                                        color: "#1a1a2e"
                                        border.width: 2
                                        border.color: "#8be9fd"
                                        clip: true

                                        Image {
                                            id: mAvatar
                                            anchors.fill: parent
                                            source: "file://" + Quickshell.env("HOME") + "/.face.icon"
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\ue4c2"
                                            font.family: "Phosphor-Bold"
                                            font.pixelSize: 36
                                            color: "#8be9fd"
                                            visible: mAvatar.status !== Image.Ready
                                        }
                                    }

                                    // Username / Hostname / OS
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text { text: "\ue4c2"; font.family: "Phosphor-Bold"; font.pixelSize: 13; color: "#8be9fd" }
                                            Text {
                                                Layout.fillWidth: true
                                                text: { var u = Quickshell.env("USER") || "user"; return u.charAt(0).toUpperCase() + u.slice(1) }
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Medium
                                                color: topPanel.clrText; elide: Text.ElideRight
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text { text: "\ue0ac"; font.family: "Phosphor-Bold"; font.pixelSize: 13; color: "#8be9fd" }
                                            Text {
                                                Layout.fillWidth: true
                                                text: metricsPane2.mHostname || "hostname"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Medium
                                                color: topPanel.clrText; elide: Text.ElideRight
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text { text: "\uf303"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#8be9fd" }
                                            Text {
                                                Layout.fillWidth: true
                                                text: metricsPane2.mOsName || "Linux"
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.weight: Font.Medium
                                                color: topPanel.clrText; elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // "System" separator — copia exacta de ambxst
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    spacing: 8

                                    Rectangle { Layout.preferredHeight: 1; Layout.fillWidth: true; color: topPanel.clrBorder }
                                    Text {
                                        text: "System"
                                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                                        color: topPanel.clrText
                                    }
                                    Rectangle { Layout.preferredHeight: 1; Layout.fillWidth: true; color: topPanel.clrBorder }
                                }

                                // Resource bars — copia exacta de ambxst
                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.leftMargin: 16
                                    Layout.rightMargin: 16
                                    contentHeight: mResCol.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Column {
                                        id: mResCol
                                        width: parent.width
                                        spacing: 12

                                        // CPU
                                        Column {
                                            width: parent.width; spacing: 4
                                            ResBar { width: parent.width; icon: "\ue610"; value: sysRes.cpuUsage / 100; barColor: "#ff5555" }
                                            RowLayout {
                                                width: parent.width; spacing: 4
                                                Text { Layout.fillWidth: true; text: sysRes.cpuModel || "CPU"; color: topPanel.clrSubtext; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideMiddle }
                                                Rectangle { width: 1; height: 10; color: topPanel.clrBorder }
                                                Text { text: Math.round(sysRes.cpuUsage) + "%"; color: topPanel.clrText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
                                                Text { visible: sysRes.cpuTemp >= 0; text: "\ue5cc"; color: "#ff5555"; font.pixelSize: 10; font.family: "Phosphor-Bold" }
                                                Text { visible: sysRes.cpuTemp >= 0; text: sysRes.cpuTemp + "°"; color: topPanel.clrText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
                                            }
                                        }

                                        // RAM
                                        Column {
                                            width: parent.width; spacing: 4
                                            ResBar { width: parent.width; icon: "\ue9c4"; value: sysRes.ramUsage / 100; barColor: "#8be9fd" }
                                            RowLayout {
                                                width: parent.width; spacing: 4
                                                Text {
                                                    Layout.fillWidth: true; elide: Text.ElideMiddle
                                                    text: (sysRes.ramUsed / 1024 / 1024).toFixed(1) + " GB / " + (sysRes.ramTotal / 1024 / 1024).toFixed(1) + " GB"
                                                    color: topPanel.clrSubtext; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                                                }
                                                Rectangle { width: 1; height: 10; color: topPanel.clrBorder }
                                                Text { text: Math.round(sysRes.ramUsage) + "%"; color: topPanel.clrText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
                                            }
                                        }

                                        // GPUs
                                        Repeater {
                                            model: sysRes.gpuDetected ? sysRes.gpuCount : 0
                                            Column {
                                                required property int index
                                                width: mResCol.width; spacing: 4
                                                readonly property string gpuClr: {
                                                    var v = sysRes.gpuVendors[index] || ""
                                                    return v === "nvidia" ? "#50fa7b" : v === "amd" ? "#ff5555" : v === "intel" ? "#6272a4" : "#bd93f9"
                                                }
                                                ResBar { width: parent.width; icon: "\ue612"; value: (sysRes.gpuUsages[index] || 0) / 100; barColor: parent.gpuClr }
                                                RowLayout {
                                                    width: parent.width; spacing: 4
                                                    Text { Layout.fillWidth: true; text: sysRes.gpuNames[index] || "GPU"; color: topPanel.clrSubtext; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideMiddle }
                                                    Rectangle { width: 1; height: 10; color: topPanel.clrBorder }
                                                    Text { text: Math.round(sysRes.gpuUsages[index] || 0) + "%"; color: topPanel.clrText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
                                                    Text { visible: (sysRes.gpuTemps[index] ?? -1) >= 0; text: "\ue5cc"; color: parent.gpuClr; font.pixelSize: 10; font.family: "Phosphor-Bold" }
                                                    Text { visible: (sysRes.gpuTemps[index] ?? -1) >= 0; text: (sysRes.gpuTemps[index] ?? 0) + "°"; color: topPanel.clrText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
                                                }
                                            }
                                        }

                                        // Discos
                                        Repeater {
                                            model: sysRes.monitorDisks
                                            Column {
                                                required property string modelData
                                                width: mResCol.width; spacing: 4
                                                ResBar { width: parent.width; icon: "\ue248"; value: (sysRes.diskUsage[modelData] || 0) / 100; barColor: "#f1fa8c" }
                                                RowLayout {
                                                    width: parent.width; spacing: 4
                                                    Text { Layout.fillWidth: true; text: modelData; color: topPanel.clrSubtext; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideMiddle }
                                                    Rectangle { width: 1; height: 10; color: topPanel.clrBorder }
                                                    Text { text: Math.round(sysRes.diskUsage[modelData] || 0) + "%"; color: topPanel.clrText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold }
                                                }
                                            }
                                        }
                                    } // mResCol
                                } // Flickable
                            } // ColumnLayout
                        } // Left rect

                        // Right panel — Chart (copia exacta de ambxst)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            // Chart container
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: topPanel.clrSurface
                                radius: 12
                                border.width: 1
                                border.color: topPanel.clrBorder
                                clip: true

                                Rectangle {
                                    anchors { fill: parent; margins: 4 }
                                    color: "#080808"
                                    radius: 8

                                    Canvas {
                                        id: metricChart
                                        anchors.fill: parent

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            var w = width, h = height
                                            ctx.clearRect(0, 0, w, h)
                                            if (sysRes.cpuHistory.length < 2) return

                                            var zoomedMax = Math.max(10, Math.floor(50 / metricsPane2.chartZoom))
                                            var ptSpacing = w / (zoomedMax - 1)
                                            var actualPts = Math.min(zoomedMax, sysRes.cpuHistory.length)
                                            var graphOff  = w - ((actualPts - 1) * ptSpacing)

                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.04)
                                            ctx.lineWidth = 1
                                            for (var gi = 1; gi < 8; gi++) {
                                                ctx.beginPath(); ctx.moveTo(0, h * gi / 8); ctx.lineTo(w, h * gi / 8); ctx.stroke()
                                            }

                                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05)
                                            ctx.lineWidth = 2
                                            var winStart  = sysRes.totalPts - actualPts
                                            var firstGrid = Math.floor(winStart / 10) * 10
                                            for (var ai = firstGrid; ai <= sysRes.totalPts + 10; ai += 10) {
                                                var vi = ai - winStart
                                                if (vi >= 0 && vi < actualPts) {
                                                    var gx = graphOff + vi * ptSpacing
                                                    ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h); ctx.stroke()
                                                }
                                            }

                                            function drawLine(history, colorStr) {
                                                if (!history || history.length < 2) return
                                                var vis    = Math.min(zoomedMax, history.length)
                                                var recent = history.slice(-vis)
                                                var clr    = Qt.color(colorStr)
                                                var grad   = ctx.createLinearGradient(0, 0, 0, h)
                                                grad.addColorStop(0,   Qt.rgba(clr.r, clr.g, clr.b, 0.4))
                                                grad.addColorStop(0.5, Qt.rgba(clr.r, clr.g, clr.b, 0.2))
                                                grad.addColorStop(1,   Qt.rgba(clr.r, clr.g, clr.b, 0.0))
                                                ctx.fillStyle = grad
                                                ctx.beginPath()
                                                ctx.moveTo(graphOff, h)
                                                ctx.lineTo(graphOff, h - recent[0] * h)
                                                for (var j = 1; j < recent.length; j++)
                                                    ctx.lineTo(graphOff + j * ptSpacing, h - recent[j] * h)
                                                ctx.lineTo(graphOff + (recent.length - 1) * ptSpacing, h)
                                                ctx.closePath(); ctx.fill()
                                                ctx.strokeStyle = colorStr
                                                ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round"
                                                ctx.beginPath()
                                                for (var k = 0; k < recent.length; k++) {
                                                    if (k === 0) ctx.moveTo(graphOff, h - recent[k] * h)
                                                    else ctx.lineTo(graphOff + k * ptSpacing, h - recent[k] * h)
                                                }
                                                ctx.stroke()
                                            }

                                            drawLine(sysRes.cpuHistory, "#ff5555")
                                            drawLine(sysRes.ramHistory,  "#8be9fd")
                                            if (sysRes.gpuDetected && sysRes.gpuCount > 0) {
                                                for (var gi2 = 0; gi2 < sysRes.gpuCount; gi2++) {
                                                    if (sysRes.gpuHistories[gi2] && sysRes.gpuHistories[gi2].length > 0) {
                                                        var vend = sysRes.gpuVendors[gi2] || ""
                                                        var gc = vend === "nvidia" ? "#50fa7b" : vend === "amd" ? "#ff79c6" : "#6272a4"
                                                        drawLine(sysRes.gpuHistories[gi2], gc)
                                                    }
                                                }
                                            }
                                        }
                                    } // Canvas

                                    // Legend top-right
                                    Row {
                                        anchors { top: parent.top; right: parent.right; margins: 8 }
                                        spacing: 10
                                        Row { spacing: 4
                                            Rectangle { width: 12; height: 3; radius: 2; color: "#ff5555"; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: "CPU"; color: "#ff5555"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                                        }
                                        Row { spacing: 4
                                            Rectangle { width: 12; height: 3; radius: 2; color: "#8be9fd"; anchors.verticalCenter: parent.verticalCenter }
                                            Text { text: "RAM"; color: "#8be9fd"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                                        }
                                        Repeater {
                                            model: sysRes.gpuDetected ? sysRes.gpuCount : 0
                                            Row {
                                                required property int index; spacing: 4
                                                readonly property string legClr: {
                                                    var v = sysRes.gpuVendors[index] || ""
                                                    return v === "nvidia" ? "#50fa7b" : v === "amd" ? "#ff79c6" : "#6272a4"
                                                }
                                                Rectangle { width: 12; height: 3; radius: 2; color: parent.legClr; anchors.verticalCenter: parent.verticalCenter }
                                                Text { text: sysRes.gpuCount > 1 ? ("GPU " + index) : "GPU"; color: parent.legClr; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                                            }
                                        }
                                    }
                                } // inner rect
                            } // chart rect

                            // Controls bar (height 48) — copia exacta de ambxst
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                color: topPanel.clrSurface
                                radius: 12
                                border.width: 1
                                border.color: topPanel.clrBorder

                                Rectangle {
                                    anchors { fill: parent; margins: 4 }
                                    color: "#080808"
                                    radius: 8

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                        spacing: 8

                                        // Zoom-out icon
                                        Text { text: "\ue30e"; font.family: "Phosphor-Bold"; font.pixelSize: 16; color: topPanel.clrSubtext }

                                        // Zoom slider
                                        Slider {
                                            id: zoomSlider
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 40
                                            from: 0.2; to: 3.0; stepSize: 0.1
                                            live: true

                                            // Sin binding declarativo — se inicializa una vez y el usuario lo controla
                                            Component.onCompleted: value = metricsPane2.chartZoom

                                            onMoved: {
                                                metricsPane2.chartZoom = value
                                                metricChart.requestPaint()
                                            }

                                            background: Rectangle {
                                                x: zoomSlider.leftPadding
                                                y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                                                width: zoomSlider.availableWidth; height: 4; radius: 2
                                                color: topPanel.clrBorder
                                                Rectangle {
                                                    width: zoomSlider.visualPosition * parent.width
                                                    height: parent.height; radius: 2; color: "#8be9fd"
                                                }
                                            }
                                            handle: Rectangle {
                                                x: zoomSlider.leftPadding + zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                                                y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                                                width: 16; height: 16; radius: 8
                                                color: zoomSlider.pressed ? "#6272a4" : "#8be9fd"
                                                border.color: topPanel.clrBorder; border.width: 1
                                                Behavior on color { ColorAnimation { duration: 80 } }
                                            }
                                        }

                                        // Zoom-in icon
                                        Text { text: "\ue310"; font.family: "Phosphor-Bold"; font.pixelSize: 16; color: topPanel.clrSubtext }

                                        Rectangle { width: 1; height: 24; color: topPanel.clrBorder }

                                        // Interval − button
                                        Rectangle {
                                            width: 28; height: 28; radius: 6
                                            color: mIntDec.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                                            border.width: 1; border.color: topPanel.clrBorder
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: "\ue32a"; font.family: "Phosphor-Bold"; font.pixelSize: 13; color: topPanel.clrText }
                                            MouseArea { id: mIntDec; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: sysRes.intervalMs = Math.max(200, sysRes.intervalMs - 100) }
                                        }

                                        Text {
                                            text: sysRes.intervalMs + "ms"
                                            color: topPanel.clrText; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
                                            Layout.preferredWidth: 54; horizontalAlignment: Text.AlignHCenter
                                        }

                                        // Interval + button
                                        Rectangle {
                                            width: 28; height: 28; radius: 6
                                            color: mIntInc.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                                            border.width: 1; border.color: topPanel.clrBorder
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: "\ue3d4"; font.family: "Phosphor-Bold"; font.pixelSize: 13; color: topPanel.clrText }
                                            MouseArea { id: mIntInc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: sysRes.intervalMs = Math.min(5000, sysRes.intervalMs + 100) }
                                        }
                                    } // RowLayout controls
                                } // inner rect
                            } // controls rect
                        } // Right ColumnLayout
                    } // RowLayout main
                } // Tab 2

                // ── Tab 3: Asistente IA (Ollama) — layout idéntico a ambxst AssistantTab ──
                TabPane {
                    id: aiTab
                    paneIndex: 3

                    // ── Estado de la conversación ──────────────────────────────
                    property var    messages:        []
                    property bool   isLoading:       false
                    property var    ollamaModels:    []
                    property string selectedModel:   ""
                    property bool   ollamaOnline:    false
                    property string streamBuf:       ""
                    property int    pendingAssIdx:   -1
                    property bool   sidebarExpanded: false
                    readonly property real sidebarMaxWidth: 250
                    property string username: ""

                    // ── Proceso: leer username ─────────────────────────────────
                    Process {
                        running: true
                        command: ["whoami"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                var u = text.trim()
                                if (u) aiTab.username = u.charAt(0).toUpperCase() + u.slice(1)
                            }
                        }
                    }

                    // ── Proceso: obtener modelos disponibles ───────────────────
                    Process {
                        id: aiCheckProc
                        property string buf: ""
                        command: ["curl", "-s", "--max-time", "4", "http://127.0.0.1:11434/api/tags"]
                        stdout: SplitParser { splitMarker: ""; onRead: d => aiCheckProc.buf += d }
                        onExited: code => {
                            if (code !== 0 || aiCheckProc.buf === "") {
                                aiTab.ollamaOnline = false
                                aiCheckProc.buf = ""
                                return
                            }
                            try {
                                var obj = JSON.parse(aiCheckProc.buf)
                                var ms = obj.models || []
                                var names = ms.map(function(m) { return m.name || m.model || "" })
                                              .filter(function(n) { return n !== "" })
                                aiTab.ollamaModels = names
                                if (aiTab.selectedModel === "" && names.length > 0) aiTab.selectedModel = names[0]
                                aiTab.ollamaOnline = names.length > 0
                            } catch(e) { aiTab.ollamaOnline = false }
                            aiCheckProc.buf = ""
                        }
                    }

                    // ── Proceso: escribir body JSON al archivo temporal ────────
                    Process {
                        id: aiWriteProc
                        property string bodyPath: "/tmp/qs_ai_body.json"
                        property string jsonBody: ""
                        onJsonBodyChanged: {
                            if (jsonBody !== "") {
                                aiWriteProc.command = ["bash", "-c",
                                    "printf '%s' " + JSON.stringify(jsonBody) + " > " + aiWriteProc.bodyPath]
                                aiWriteProc.running = true
                            }
                        }
                        onExited: {
                            if (aiWriteProc.jsonBody !== "") {
                                aiWriteProc.jsonBody = ""
                                aiChatProc.buf = ""
                                aiChatProc.running = true
                            }
                        }
                    }

                    // ── Proceso: enviar al API de Ollama ──────────────────────
                    Process {
                        id: aiChatProc
                        property string buf: ""
                        command: ["curl", "-s", "--no-buffer", "--max-time", "120",
                            "-X", "POST", "http://127.0.0.1:11434/api/chat",
                            "-H", "Content-Type: application/json",
                            "-d", "@" + aiWriteProc.bodyPath]
                        stdout: SplitParser {
                            splitMarker: "\n"
                            onRead: data => {
                                if (!data.trim()) return
                                try {
                                    var obj = JSON.parse(data)
                                    var token = ""
                                    if (obj.message && obj.message.content) token = obj.message.content
                                    if (token !== "") {
                                        aiTab.streamBuf += token
                                        // Update existing assistant message in-place
                                        if (aiTab.pendingAssIdx >= 0 && aiTab.pendingAssIdx < aiTab.messages.length) {
                                            var updated = aiTab.messages.slice()
                                            updated[aiTab.pendingAssIdx] = { role: "assistant", content: aiTab.streamBuf }
                                            aiTab.messages = updated
                                        }
                                    }
                                } catch(e) {}
                            }
                        }
                        onExited: {
                            aiTab.isLoading    = false
                            aiTab.streamBuf    = ""
                            aiTab.pendingAssIdx = -1
                        }
                    }

                    // ── Activar: cargar modelos si aún no se han cargado ──────
                    onActiveChanged: {
                        if (active && aiTab.ollamaModels.length === 0 && !aiCheckProc.running)
                            aiCheckProc.running = true
                        if (active)
                            Qt.callLater(function() { aiInputField.forceActiveFocus() })
                    }

                    // ── Función: enviar mensaje ───────────────────────────────
                    function sendMessage(text) {
                        var t = text.trim()
                        if (!t || aiTab.isLoading || aiTab.selectedModel === "") return

                        // Añadir mensaje del usuario
                        var withUser = aiTab.messages.slice()
                        withUser.push({ role: "user", content: t })

                        // Añadir slot vacío de asistente
                        aiTab.pendingAssIdx = withUser.length
                        withUser.push({ role: "assistant", content: "" })
                        aiTab.messages = withUser
                        aiTab.isLoading = true
                        aiTab.streamBuf = ""

                        // Construir request
                        var apiMsgs = withUser.slice(0, aiTab.pendingAssIdx).map(function(m) {
                            return { role: m.role, content: m.content }
                        })
                        var body = JSON.stringify({ model: aiTab.selectedModel, messages: apiMsgs, stream: true })
                        aiWriteProc.jsonBody = body
                    }

                    // ── UI — idéntico visualmente a ambxst AssistantTab ───────
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ── Sidebar colapsable (= ambxst) ─────────────────────
                        Item {
                            id: aiSidebar
                            Layout.fillHeight: true
                            Layout.preferredWidth: aiTab.sidebarExpanded ? aiTab.sidebarMaxWidth : 56
                            Layout.maximumWidth: aiTab.sidebarMaxWidth
                            Layout.minimumWidth: 56
                            clip: true

                            Behavior on Layout.preferredWidth {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                color: topPanel.clrSurface
                                radius: aiTab.sidebarExpanded ? 8 : 0
                                border.width: 1
                                border.color: topPanel.clrBorder
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4

                                    // Botón toggle (≡)
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 6
                                        color: tglHov.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        RowLayout { anchors.fill: parent; spacing: 0
                                            Item { Layout.preferredWidth: 40; Layout.fillHeight: true
                                                Text { anchors.centerIn: parent; text: "\ue2f0"
                                                    font.family: "Phosphor-Bold"; font.pixelSize: 16; color: topPanel.clrText } }
                                            Text { text: "Menu"; color: topPanel.clrText
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                                visible: aiTab.sidebarExpanded
                                                opacity: aiTab.sidebarExpanded ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                                Layout.fillWidth: true }
                                        }
                                        MouseArea { id: tglHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: aiTab.sidebarExpanded = !aiTab.sidebarExpanded }
                                    }

                                    // Botón nueva conversación
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 6
                                        color: ncHov2.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        RowLayout { anchors.fill: parent; spacing: 0
                                            Item { Layout.preferredWidth: 40; Layout.fillHeight: true
                                                Text { anchors.centerIn: parent; text: "\ue3b2"
                                                    font.family: "Phosphor-Bold"; font.pixelSize: 16; color: "#8be9fd" } }
                                            Text { text: "New Chat"; color: topPanel.clrText
                                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                                                visible: aiTab.sidebarExpanded
                                                opacity: aiTab.sidebarExpanded ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                                Layout.fillWidth: true }
                                        }
                                        MouseArea { id: ncHov2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { aiTab.messages = []; aiTab.isLoading = false; aiTab.streamBuf = ""
                                                if (aiTab.sidebarExpanded) aiTab.sidebarExpanded = false } }
                                    }

                                    // Separador (solo visible en expandido)
                                    Rectangle { Layout.fillWidth: true; height: 1; color: topPanel.clrBorder; visible: aiTab.sidebarExpanded }

                                    // Lista de modelos — visible solo en expandido
                                    ListView {
                                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                                        visible: aiTab.sidebarExpanded && aiTab.ollamaOnline
                                        opacity: aiTab.sidebarExpanded ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        model: aiTab.ollamaModels; spacing: 3

                                        delegate: Rectangle {
                                            required property string modelData; required property int index
                                            width: ListView.view.width; height: 36; radius: 6
                                            property bool sel: aiTab.selectedModel === modelData
                                            property bool hov: mdlHov.containsMouse
                                            color: sel ? Qt.rgba(1,1,1,0.15) : (hov ? Qt.rgba(1,1,1,0.07) : "transparent")
                                            border.width: sel ? 1 : 0; border.color: topPanel.clrText
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            RowLayout { anchors { fill: parent; leftMargin: 8; rightMargin: 4 } spacing: 6
                                                Text { text: "\ue762"; font.family: "Phosphor-Bold"; font.pixelSize: 13
                                                    color: sel ? "#8be9fd" : topPanel.clrSubtext }
                                                Text { Layout.fillWidth: true; text: modelData; font.pixelSize: 12
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    color: sel ? topPanel.clrText : topPanel.clrSubtext; elide: Text.ElideRight }
                                            }
                                            MouseArea { id: mdlHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { aiTab.selectedModel = parent.modelData; aiTab.sidebarExpanded = false } }
                                        }
                                    }

                                    // Spacer cuando colapsado
                                    Item { Layout.fillHeight: true; visible: !aiTab.sidebarExpanded }

                                    // Botón estado / reintentar (abajo)
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 6
                                        color: stsHov.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        RowLayout { anchors.fill: parent; spacing: 0
                                            Item { Layout.preferredWidth: 40; Layout.fillHeight: true
                                                Text { anchors.centerIn: parent
                                                    text: aiTab.ollamaOnline ? "\ue272" : "\ue32c"
                                                    font.family: "Phosphor-Bold"; font.pixelSize: 16
                                                    color: aiTab.ollamaOnline ? topPanel.clrSubtext : "#ff5555" } }
                                            Text { Layout.fillWidth: true
                                                text: aiTab.ollamaOnline ? "Connected" : (aiCheckProc.running ? "Connecting..." : "Retry")
                                                color: topPanel.clrText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                                                visible: aiTab.sidebarExpanded
                                                opacity: aiTab.sidebarExpanded ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: 200 } } }
                                        }
                                        MouseArea { id: stsHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (!aiTab.ollamaOnline && !aiCheckProc.running) aiCheckProc.running = true }
                                    }
                                } // ColumnLayout sidebar
                            } // Rectangle sidebar bg
                        } // Item sidebar

                        // ── Área principal (= ambxst mainChatArea) ────────────
                        Item {
                            id: aiMainArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            property bool isWelcome: aiTab.messages.length === 0

                            // Pantalla de bienvenida (centrada, = ambxst)
                            ColumnLayout {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -50
                                visible: aiMainArea.isWelcome
                                spacing: 8

                                Text {
                                    text: "Hello, <b><font color='#8be9fd'>" + (aiTab.username || "User") + "</font></b>."
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 28; font.weight: Font.Bold
                                    textFormat: Text.StyledText; Layout.alignment: Qt.AlignHCenter
                                    color: topPanel.clrText
                                }
                                Text {
                                    text: aiTab.ollamaOnline ? "How can I help you today?" : "Start Ollama to begin."
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                                    color: topPanel.clrSubtext; Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // ColumnLayout: header invisible + lista de mensajes
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8

                                // ListView de mensajes (= ambxst chatView)
                                ListView {
                                    id: aiMsgView
                                    visible: !aiMainArea.isWelcome
                                    cacheBuffer: 1000
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    clip: true; spacing: 16
                                    model: aiTab.messages
                                    displayMarginBeginning: 40; displayMarginEnd: 40
                                    bottomMargin: aiMainArea.isWelcome ? 0 : aiFloatInput.height + 28

                                    onCountChanged: Qt.callLater(function() { positionViewAtEnd() })

                                    delegate: Item {
                                        required property var modelData; required property int index
                                        property bool isUser: modelData.role === "user"
                                        width: ListView.view.width
                                        height: dRow.implicitHeight + 8

                                        Row {
                                            id: dRow
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 10
                                            layoutDirection: isUser ? Qt.RightToLeft : Qt.LeftToRight
                                            spacing: 12

                                            // Avatar
                                            Item { width: 32; height: 32
                                                Rectangle { anchors.fill: parent; radius: 16
                                                    color: isUser ? Qt.rgba(1,1,1,0.18) : "#8be9fd"
                                                    Text { anchors.centerIn: parent; text: isUser ? "\ue4c2" : "\ue762"
                                                        font.family: "Phosphor-Bold"; font.pixelSize: 16
                                                        color: isUser ? topPanel.clrText : "#0d0d0d" }
                                                }
                                            }

                                            // Burbuja
                                            Rectangle {
                                                id: aBubble
                                                width: Math.min(Math.max(aBubText.implicitWidth + 32, 80), aiMsgView.width * 0.70)
                                                height: aBubText.implicitHeight + 24; radius: 8
                                                color: isUser ? Qt.rgba(1,1,1,0.10) : "#161616"
                                                border.width: 1
                                                border.color: isUser ? Qt.rgba(1,1,1,0.22) : topPanel.clrBorder

                                                Text {
                                                    id: aBubText
                                                    anchors { fill: parent; margins: 12 }
                                                    text: modelData.content !== ""
                                                          ? modelData.content
                                                          : (modelData.role === "assistant" && aiTab.isLoading ? "…" : "")
                                                    color: topPanel.clrText; wrapMode: Text.Wrap
                                                    font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                                                }
                                            }
                                        }
                                    }

                                    // Tres puntos de carga (= ambxst footer)
                                    footer: Item {
                                        width: aiMsgView.width; height: 40
                                        visible: aiTab.isLoading
                                        Row {
                                            anchors { left: parent.left; leftMargin: 54; verticalCenter: parent.verticalCenter }
                                            spacing: 6
                                            Repeater {
                                                model: 3
                                                Rectangle {
                                                    required property int index
                                                    width: 8; height: 8; radius: 4; color: "#8be9fd"; opacity: 0.5
                                                    SequentialAnimation on opacity {
                                                        loops: Animation.Infinite; running: aiTab.isLoading
                                                        PauseAnimation { duration: index * 200 }
                                                        PropertyAnimation { to: 1; duration: 400 }
                                                        PropertyAnimation { to: 0.5; duration: 400 }
                                                        PauseAnimation { duration: 400 - (index * 200) }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } // ListView mensajes
                            } // ColumnLayout principal

                            // Input flotante (= ambxst inputContainer)
                            Item {
                                id: aiFloatInput
                                height: 52
                                anchors.bottom: parent.bottom
                                property real centerMargin: (parent.height / 2) - (height / 2)
                                anchors.bottomMargin: aiMainArea.isWelcome ? centerMargin : 20
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(600, parent.width - 40)

                                Behavior on anchors.bottomMargin {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: topPanel.clrSurface; radius: 12
                                    border.width: 1
                                    border.color: aiInputField.activeFocus ? "#8be9fd" : topPanel.clrBorder
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    RowLayout {
                                        anchors { fill: parent; margins: 8; leftMargin: 16; rightMargin: 12 }
                                        spacing: 8

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            TextInput {
                                                id: aiInputField
                                                anchors.fill: parent
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: topPanel.clrText; clip: true
                                                font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                                                enabled: !aiTab.isLoading && aiTab.ollamaOnline
                                                Keys.onReturnPressed: e => {
                                                    if (!(e.modifiers & Qt.ShiftModifier)) {
                                                        if (text.trim().length > 0) {
                                                            aiTab.sendMessage(text.trim()); text = ""
                                                        }
                                                        e.accepted = true
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                text: aiMainArea.isWelcome ? "Ask AI anything..." : "Message AI..."
                                                color: topPanel.clrSubtext; font.pixelSize: 13
                                                font.family: "JetBrainsMono Nerd Font"
                                                visible: aiInputField.text === "" && !aiInputField.activeFocus
                                            }
                                        }

                                        // Botón enviar
                                        Rectangle {
                                            Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                                            visible: aiInputField.text.length > 0
                                            color: sndHov.containsMouse ? Qt.rgba(0.54,0.91,0.99,0.2) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: "\ue396"
                                                font.family: "Phosphor-Bold"; font.pixelSize: 18; color: "#8be9fd" }
                                            MouseArea { id: sndHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (aiInputField.text.trim().length > 0) { aiTab.sendMessage(aiInputField.text.trim()); aiInputField.text = "" } } }
                                        }

                                        // Botón detener
                                        Rectangle {
                                            Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                                            visible: aiTab.isLoading
                                            color: stpHov.containsMouse ? Qt.rgba(1,0.3,0.3,0.2) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Text { anchors.centerIn: parent; text: "\ue46c"
                                                font.family: "Phosphor-Bold"; font.pixelSize: 16; color: "#ff5555" }
                                            MouseArea { id: stpHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { aiChatProc.running = false; aiTab.isLoading = false; aiTab.streamBuf = "" } }
                                        }
                                    }
                                }
                            } // aiFloatInput

                            // Nombre del modelo debajo del input (bienvenida, = ambxst)
                            Text {
                                anchors.top: aiFloatInput.bottom; anchors.topMargin: 8
                                anchors.horizontalCenter: aiFloatInput.horizontalCenter
                                text: aiTab.selectedModel
                                color: topPanel.clrSubtext; font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11; font.weight: Font.Medium
                                visible: aiMainArea.isWelcome && aiTab.ollamaOnline
                                opacity: visible ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                    onClicked: aiTab.sidebarExpanded = !aiTab.sidebarExpanded }
                            }
                        } // aiMainArea
                    } // RowLayout UI
                } // Tab 3

                // ── Tab 4: Notas + Volumen (la que ya tenías) ─────────────────
                TabPane {
                    paneIndex: 4

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        NotesWidget {
                            Layout.fillWidth:  true
                            Layout.fillHeight: true
                            panelVisible: topPanel.currentTab === 4 && root.topPanelVisible
                            autoHeight:   false
                            expanded:     true
                        }

                        Rectangle {
                            width:  1
                            Layout.fillHeight: true
                            Layout.topMargin:    8
                            Layout.bottomMargin: 8
                            color: topPanel.clrBorder
                        }

                        AppVolumeWidget {
                            Layout.preferredWidth: 288
                            Layout.fillHeight: true
                        }
                    }
                }

            } // contentArea
        } // Row
    } // Rectangle
}
