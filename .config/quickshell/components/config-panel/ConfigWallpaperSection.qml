import QtQuick
import "../skwd-wall/qml"

Column {
  id: root
  property var panel
  property var colors
  width: parent.width
  spacing: 8

  ConfigSectionTitle { text: "WALLPAPER"; colors: root.colors }

  ConfigToggle {
    label: "Mute wallpaper audio"
    checked: panel.getNested(panel.configData, ["wallpaperMute"], true)
    onToggled: v => { panel.setNested(panel.configData, ["wallpaperMute"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Wallpaper selector"
    checked: {
      var ws = panel.getNested(panel.configData, ["components", "wallpaperSelector"], undefined)
      return ws !== false && ws?.enabled !== false
    }
    onToggled: v => { panel.setNested(panel.configData, ["components", "wallpaperSelector", "enabled"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Wallpaper color dots"
    checked: panel.getNested(panel.configData, ["components", "wallpaperSelector", "showColorDots"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "wallpaperSelector", "showColorDots"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "PATHS"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "Wallpaper"
    value: panel.getNested(panel.configData, ["paths", "wallpaper"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "wallpaper"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Steam workshop"
    value: panel.getNested(panel.configData, ["paths", "steamWorkshop"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "steamWorkshop"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Steam WE assets"
    value: panel.getNested(panel.configData, ["paths", "steamWeAssets"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "steamWeAssets"], v); panel.configDataChanged() }
    colors: root.colors
  }
}
