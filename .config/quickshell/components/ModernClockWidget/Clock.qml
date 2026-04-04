import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    PanelWindow {
    id: clockPanel

        // ┌─────────────────────────────────────┐
        // │           Widget position           │
        // ├─────────────────────────────────────┤
        // │  active side (true/false)           │
            anchors.top: true                  
            anchors.right: true                
            anchors.left: true                 
            anchors.bottom: true               
        //  Position     
            margins.top: 0                   
            margins.right: 0                    
            margins.left: 0                   
            margins.bottom: 0                   
        // └─────────────────────────────────────┘

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "clock-widget"
        WlrLayershell.exclusiveZone: -1
        color: "transparent"

        // Auto-contrast: white by default, switch to black on bright wallpapers.
        property color clockTextColor: "#ffffff"
        property string wallpaperPath: ""
        readonly property real brightThreshold: 0.5
        property var wallpaperPositions: ({})
        property bool useCustomPosition: false
        property bool centerOnScreen: false
        property bool centerX: false
        property bool centerY: false
        property real customPosX: 0
        property real customPosY: 0
        property real dayFontSize: 90
        property real dateFontSize: 20
        property real timeFontSize: 17
        property string forcedTextColor: ""
        property int moveAnimMs: 320
        readonly property string positionsFilePath: Quickshell.env("HOME") + "/.config/quickshell/components/ModernClockWidget/positions.json"

        function shellQuote(s) {
            return "'" + String(s).replace(/'/g, "'\"'\"'") + "'"
        }

        function isStaticImage(path) {
            var p = (path || "").toLowerCase()
            return p.endsWith(".png") || p.endsWith(".jpg") || p.endsWith(".jpeg") || p.endsWith(".webp")
        }

        function refreshWallpaperState() {
            loadPositionsProc.running = false
            loadPositionsProc.running = true
        }

        function basename(path) {
            var p = String(path || "")
            var parts = p.split("/")
            return parts.length > 0 ? parts[parts.length - 1] : ""
        }

        function stripExt(name) {
            return String(name || "").replace(/\.[^/.]+$/, "")
        }

        function positiveNumberOr(value, fallback) {
            var n = Number(value)
            return (isFinite(n) && n > 0) ? n : fallback
        }

        function normalizeTextColor(value) {
            var c = String(value || "").trim().toLowerCase()
            if (c === "white" || c === "#ffffff") return "#ffffff"
            if (c === "black" || c === "#000000") return "#000000"
            return ""
        }

        function applyPositionFromPath(path) {
            var full = String(path || "")
            var file = basename(full)
            var stem = stripExt(file)
            var cfg = wallpaperPositions[full] || wallpaperPositions[file] || wallpaperPositions[stem] || wallpaperPositions.default || null
            var defaultCfg = wallpaperPositions.default && typeof wallpaperPositions.default === "object"
                ? wallpaperPositions.default
                : ({})

            // Typography controls (global in default + per-wall override)
            dayFontSize = positiveNumberOr(cfg && cfg.daySize, positiveNumberOr(defaultCfg.daySize, 90))
            dateFontSize = positiveNumberOr(cfg && cfg.dateSize, positiveNumberOr(defaultCfg.dateSize, 20))
            timeFontSize = positiveNumberOr(cfg && cfg.timeSize, positiveNumberOr(defaultCfg.timeSize, 17))
            forcedTextColor = normalizeTextColor((cfg && cfg.textColor) || defaultCfg.textColor)

            // Position mode: exact center when centerOnScreen=true, otherwise use x/y.
            centerOnScreen = (cfg && cfg.centerOnScreen !== undefined)
                ? cfg.centerOnScreen === true
                : defaultCfg.centerOnScreen === true

            // Axis-specific centering; centerOnScreen forces both axes centered.
            centerX = centerOnScreen || ((cfg && cfg.centerX !== undefined)
                ? cfg.centerX === true
                : defaultCfg.centerX === true)
            centerY = centerOnScreen || ((cfg && cfg.centerY !== undefined)
                ? cfg.centerY === true
                : defaultCfg.centerY === true)

            if (!cfg || typeof cfg !== "object") {
                customPosX = 0
                customPosY = 0
                useCustomPosition = true
                return
            }

            var x = Number(cfg.x)
            var y = Number(cfg.y)
            // QoL: if x/y were edited and are non-zero, apply position even when enabled=false.
            var enabled = cfg.enabled === true || (cfg.enabled !== true && (x !== 0 || y !== 0))
            if (enabled && isFinite(x) && isFinite(y)) {
                customPosX = x
                customPosY = y
                useCustomPosition = true
            } else {
                customPosX = 0
                customPosY = 0
                useCustomPosition = true
            }
        }

        function updateContrastFromPath(path) {
            wallpaperPath = path || ""
            applyPositionFromPath(wallpaperPath)

            if (forcedTextColor !== "") {
                clockTextColor = forcedTextColor
                return
            }

            if (!isStaticImage(wallpaperPath)) {
                clockTextColor = "#ffffff"
                return
            }

            measureBrightnessProc.command = [
                "bash",
                "-lc",
                "magick identify -format '%[fx:mean]' " + shellQuote(wallpaperPath) + " 2>/dev/null"
            ]
            measureBrightnessProc.running = false
            measureBrightnessProc.running = true
        }

        Process {
            id: loadPositionsProc
            command: ["cat", clockPanel.positionsFilePath]

            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var raw = text.trim()
                    if (!raw) {
                        clockPanel.wallpaperPositions = ({})
                        return
                    }
                    try {
                        var parsed = JSON.parse(raw)
                        clockPanel.wallpaperPositions = parsed && typeof parsed === "object" ? parsed : ({})
                    } catch (e) {
                        clockPanel.wallpaperPositions = ({})
                    }
                }
            }

            onExited: {
                resolveWallpaperProc.running = false
                resolveWallpaperProc.running = true
            }
        }

        Process {
            id: resolveWallpaperProc
            command: ["readlink", "-f", Quickshell.env("HOME") + "/.config/hypr/wallpaper_effects/.wallpaper_current"]

            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    clockPanel.updateContrastFromPath(text.trim())
                }
            }

            onExited: code => {
                if (code !== 0) {
                    clockPanel.clockTextColor = "#ffffff"
                }
            }
        }

        Process {
            id: measureBrightnessProc
            command: ["true"]

            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    var value = parseFloat(text.trim())
                    if (isNaN(value)) {
                        clockPanel.clockTextColor = "#ffffff"
                        return
                    }
                    clockPanel.clockTextColor = value >= clockPanel.brightThreshold ? "#000000" : "#ffffff"
                }
            }

            onExited: code => {
                if (code !== 0) {
                    clockPanel.clockTextColor = "#ffffff"
                }
            }
        }

        Timer {
            interval: 2500
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clockPanel.refreshWallpaperState()
        }

        // --- Fonts ---
         FontLoader {
             id: font_anurati
             source: Qt.resolvedUrl("Anurati.otf")
}

         FontLoader {
             id: font_poppins
		         source: Qt.resolvedUrl("Poppins.ttf")
}

        // --- Time ---
 		SystemClock {
 			id: clock
 			precision: SystemClock.Seconds
}

        // --- Content ---
        Column {
            id: container
                x: clockPanel.centerX
                    ? Math.round((clockPanel.width - width) / 2)
                    : Math.max(0, Math.min(clockPanel.customPosX, Math.max(0, clockPanel.width - width)))
                y: clockPanel.centerY
                    ? Math.round((clockPanel.height - height) / 2)
                    : Math.max(0, Math.min(clockPanel.customPosY, Math.max(0, clockPanel.height - height)))
            Behavior on x {
                NumberAnimation {
                    duration: clockPanel.moveAnimMs
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: clockPanel.moveAnimMs
                    easing.type: Easing.OutCubic
                }
            }
            spacing: 4

// ── Days of the week ──────────────────────────
            Item {
                implicitWidth: clock_day.implicitWidth
                implicitHeight: clock_day.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                // shadow
                Text {
                    x: 2; y: 2
                    text: clock_day.text
                    font: clock_day.font
                    color: "#55000000"
                }
                // Main text
                Text {
                    id: clock_day
                    text: Qt.formatDate(clock.date, "dddd").toUpperCase()
                    font.family: font_anurati.name
                    font.pixelSize: clockPanel.dayFontSize
                    color: clockPanel.clockTextColor
                    font.letterSpacing: 10
                }
            }

            // ── Date ────────────────────────────────
            Item {
                implicitWidth: clock_date.implicitWidth
                implicitHeight: clock_date.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                // shadow
                Text {
                    x: 1; y: 1
                    text: clock_date.text
                    font: clock_date.font
                    color: "#55000000"
                }
                // Main text
                Text {
                    id: clock_date
                    text: Qt.formatDate(clock.date, "dd MMM yyyy").toUpperCase()
                    font.family: font_poppins.name
                    font.pixelSize: clockPanel.dateFontSize
                    color: clockPanel.clockTextColor
                }
            }

            // ── Time  ─────────────────────────────────
            Item {
                implicitWidth: clock_time.implicitWidth
                implicitHeight: clock_time.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                // shadow
                Text {
                    x: 1; y: 1
                    text: clock_time.text
                    font: clock_time.font
                    color: "#55000000"
                }
                // Main text
                Text {
                    id: clock_time
                    text: "- " + Qt.formatTime(clock.date, "hh:mm AP") + " -"
                    font.family: font_poppins.name
                    font.pixelSize: clockPanel.timeFontSize
                    color: clockPanel.clockTextColor
                }
            }
        }
    }
}
