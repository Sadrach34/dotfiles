import QtQuick
import "../skwd-wall/qml"

Column {
  id: root
  property var panel
  property var colors

  width: parent.width
  spacing: 8

  function _saveNumber(path, value, fallback) {
    var n = parseInt(value)
    if (!isFinite(n)) n = fallback
    panel.setNested(panel.configData, path, n)
    panel.configDataChanged()
  }

  ConfigSectionTitle { text: "ADVANCED OPTIONS (WALLPAPER+)"; colors: root.colors }

  ConfigTextField {
    label: "Display mode"
    value: panel.getNested(panel.configData, ["components", "wallpaperSelector", "displayMode"], "slices")
    placeholder: "slices | hex | wall"
    onEdited: v => { panel.setNested(panel.configData, ["components", "wallpaperSelector", "displayMode"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Auto mode"
    value: panel.getNested(panel.configData, ["components", "wallpaperSelector", "autoChangeMode"], "random")
    placeholder: "random | next"
    onEdited: v => { panel.setNested(panel.configData, ["components", "wallpaperSelector", "autoChangeMode"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Auto interval (min)"
    value: String(panel.getNested(panel.configData, ["components", "wallpaperSelector", "autoChangeIntervalMinutes"], 10))
    onEdited: v => _saveNumber(["components", "wallpaperSelector", "autoChangeIntervalMinutes"], v, 10)
    colors: root.colors
  }

  ConfigToggle {
    label: "Auto change enabled"
    checked: panel.getNested(panel.configData, ["components", "wallpaperSelector", "autoChangeEnabled"], false)
    onToggled: v => { panel.setNested(panel.configData, ["components", "wallpaperSelector", "autoChangeEnabled"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Filter bar BG"
    value: panel.getNested(panel.configData, ["components", "wallpaperSelector", "filterBarBgColor"], "")
    placeholder: "#1e2430 o #cc1e2430"
    onEdited: v => { panel.setNested(panel.configData, ["components", "wallpaperSelector", "filterBarBgColor"], v.trim()); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "WALLHAVEN GRID"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "Columns"
    value: String(panel.getNested(panel.configData, ["components", "wallpaperSelector", "wallhavenColumns"], 6))
    onEdited: v => _saveNumber(["components", "wallpaperSelector", "wallhavenColumns"], v, 6)
    colors: root.colors
  }

  ConfigTextField {
    label: "Rows"
    value: String(panel.getNested(panel.configData, ["components", "wallpaperSelector", "wallhavenRows"], 3))
    onEdited: v => _saveNumber(["components", "wallpaperSelector", "wallhavenRows"], v, 3)
    colors: root.colors
  }

  ConfigTextField {
    label: "Thumb width"
    value: String(panel.getNested(panel.configData, ["components", "wallpaperSelector", "wallhavenThumbWidth"], 300))
    onEdited: v => _saveNumber(["components", "wallpaperSelector", "wallhavenThumbWidth"], v, 300)
    colors: root.colors
  }

  ConfigTextField {
    label: "Thumb height"
    value: String(panel.getNested(panel.configData, ["components", "wallpaperSelector", "wallhavenThumbHeight"], 169))
    onEdited: v => _saveNumber(["components", "wallpaperSelector", "wallhavenThumbHeight"], v, 169)
    colors: root.colors
  }

  ConfigSectionTitle { text: "FEATURES"; topPad: 16; colors: root.colors }

  ConfigToggle {
    label: "Wallhaven browser"
    checked: panel.getNested(panel.configData, ["features", "wallhaven"], true)
    onToggled: v => { panel.setNested(panel.configData, ["features", "wallhaven"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Steam browser"
    checked: panel.getNested(panel.configData, ["features", "steam"], true)
    onToggled: v => { panel.setNested(panel.configData, ["features", "steam"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Video preview"
    checked: panel.getNested(panel.configData, ["features", "videoPreview"], true)
    onToggled: v => { panel.setNested(panel.configData, ["features", "videoPreview"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Ollama"
    checked: panel.getNested(panel.configData, ["features", "ollama"], false)
    onToggled: v => { panel.setNested(panel.configData, ["features", "ollama"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "API"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "Wallhaven API"
    value: panel.getNested(panel.configData, ["wallhaven", "apiKey"], "")
    placeholder: "WALLHAVEN_API_KEY"
    onEdited: v => panel.saveApiKey(["wallhaven", "apiKey"], v, "WALLHAVEN_API_KEY")
    colors: root.colors
  }

  ConfigTextField {
    label: "Steam API"
    value: panel.getNested(panel.configData, ["steam", "apiKey"], "")
    placeholder: "STEAM_API_KEY"
    onEdited: v => panel.saveApiKey(["steam", "apiKey"], v, "STEAM_API_KEY")
    colors: root.colors
  }

  ConfigTextField {
    label: "Ollama URL"
    value: panel.getNested(panel.configData, ["ollama", "url"], "http://localhost:11434")
    placeholder: "SKWD_OLLAMA_URL"
    onEdited: v => panel.saveApiKey(["ollama", "url"], v, "SKWD_OLLAMA_URL")
    colors: root.colors
  }

  ConfigTextField {
    label: "Ollama model"
    value: panel.getNested(panel.configData, ["ollama", "model"], "gemma3:4b")
    onEdited: v => { panel.setNested(panel.configData, ["ollama", "model"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "EXTRA PATHS"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "Video wallpapers"
    value: panel.getNested(panel.configData, ["paths", "videoWallpaper"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "videoWallpaper"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Steam path"
    value: panel.getNested(panel.configData, ["paths", "steam"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "steam"], v); panel.configDataChanged() }
    colors: root.colors
  }
}
