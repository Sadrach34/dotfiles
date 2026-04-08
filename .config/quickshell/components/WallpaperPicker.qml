import Quickshell
import Quickshell.Io
import QtQuick
import "./skwd-wall/qml"
import "./skwd-wall/qml/services" as SkwdServices

Scope {
  id: wallpaperPicker

  readonly property string _autoMode: (Config.wallpaperAutoChangeMode === "next") ? "next" : "random"
  readonly property int _autoIntervalMs: Math.max(1, Config.wallpaperAutoChangeIntervalMinutes) * 60000

  function _autoScriptPath() {
    var base = Config.homeDir + "/.config/hypr/UserScripts"
    return base + (_autoMode === "next" ? "/WallpaperNext.sh" : "/WallpaperRandom.sh")
  }

  function _runAutoChangeNow() {
    if (!Config.wallpaperAutoChangeEnabled || autoChangeProc.running) return
    var script = _autoScriptPath()
    autoChangeProc.command = ["sh", "-c", "[ -x " + JSON.stringify(script) + " ] && " + JSON.stringify(script) + " || true"]
    autoChangeProc.running = true
  }

  Component.onCompleted: {
    // Restore the last wallpaper on session startup even if the selector UI stays closed.
    SkwdServices.WallpaperApplyService.restore()
  }

  Timer {
    id: autoChangeTimer
    running: Config.wallpaperAutoChangeEnabled
    repeat: true
    interval: wallpaperPicker._autoIntervalMs
    onTriggered: wallpaperPicker._runAutoChangeNow()
    onIntervalChanged: {
      if (running) restart()
    }
  }

  Process {
    id: autoChangeProc
    onExited: function(code) {
      if (code !== 0) {
        console.log("WallpaperPicker auto-change failed with code", code)
      }
    }
  }

  Colors {
    id: skwdColors
  }

  Loader {
    id: selectorLoader
    active: root.wallpaperPickerVisible
    source: "./skwd-wall/qml/wallpaper/WallpaperSelector.qml"

    onLoaded: {
      if (!item) return
      item.colors = Qt.binding(function() { return skwdColors })
      item.showing = true
      if (item.wallpaperChanged) {
        item.wallpaperChanged.connect(function() {
          root.wallpaperPickerVisible = false
        })
      }
    }
  }

  Connections {
    target: selectorLoader.item
    ignoreUnknownSignals: true
    function onShowingChanged() {
      if (selectorLoader.item && !selectorLoader.item.showing && root.wallpaperPickerVisible) {
        root.wallpaperPickerVisible = false
      }
    }
  }

  Connections {
    target: root
    function onWallpaperPickerVisibleChanged() {
      if (!root.wallpaperPickerVisible && selectorLoader.item) {
        selectorLoader.item.showing = false
      }
    }
  }
}
