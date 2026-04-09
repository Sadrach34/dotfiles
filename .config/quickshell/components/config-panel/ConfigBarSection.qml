import QtQuick
import "../skwd-wall/qml"

Column {
  id: root
  property var panel
  property var colors
  property bool barEnabledUi: panel.getNested(panel.configData, ["components", "bar", "enabled"], true)
  width: parent.width
  spacing: 8

  function syncBarEnabledFromConfig() {
    barEnabledUi = panel.getNested(panel.configData, ["components", "bar", "enabled"], true)
  }

  Component.onCompleted: syncBarEnabledFromConfig()

  Connections {
    target: panel
    function onConfigDataChanged() {
      root.syncBarEnabledFromConfig()
    }
  }

  ConfigSectionTitle { text: "BAR (WAYBAR)"; colors: root.colors }

  ConfigTextField {
    label: "Backend"
    value: panel.getNested(panel.configData, ["components", "bar", "backend"], "waybar")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "backend"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Waybar config"
    value: panel.getNested(panel.configData, ["components", "bar", "waybarConfig"], "~/.config/waybar/config")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "waybarConfig"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Waybar style"
    value: panel.getNested(panel.configData, ["components", "bar", "waybarStyle"], "~/.config/waybar/style.css")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "waybarStyle"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Bar enabled"
    checked: root.barEnabledUi
    onToggled: v => {
      root.barEnabledUi = v
      panel.setNested(panel.configData, ["components", "bar", "enabled"], v)
      panel.configDataChanged()
    }
    colors: root.colors
  }

  ConfigSectionTitle { text: "WIDGETS"; topPad: 12; colors: root.colors }

  Text {
    text: "Bluetooth: feature (proximamente)"
    font.family: Style.fontFamily
    font.pixelSize: 12
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.6) : Qt.rgba(1, 1, 1, 0.6)
  }

  ConfigToggle {
    label: "TopPanel: volumen por aplicacion"
    checked: panel.getNested(panel.configData, ["components", "bar", "volume"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "volume"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "TopPanel: calendario"
    checked: panel.getNested(panel.configData, ["components", "bar", "calendar"], true)
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "calendar"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "MUSIC"; topPad: 12; colors: root.colors }

  ConfigToggle {
    label: "TopPanel / Dashboard / RofiBeats"
    checked: {
      var m = panel.getNested(panel.configData, ["components", "bar", "music"], undefined)
      return m !== undefined && m !== false && m?.enabled !== false
    }
    onToggled: v => { panel.setNested(panel.configData, ["components", "bar", "music", "enabled"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Fuente (yt-dlp/link)"
    value: panel.getNested(panel.configData, ["components", "bar", "music", "preferredPlayer"], "")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "music", "preferredPlayer"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigTextField {
    label: "Visualizer"
    value: panel.getNested(panel.configData, ["components", "bar", "music", "visualizer"], "")
    onEdited: v => { panel.setNested(panel.configData, ["components", "bar", "music", "visualizer"], v); panel.configDataChanged() }
    colors: root.colors
  }

  Text {
    text: "Visualizer top: feature (proximamente)"
    font.family: Style.fontFamily
    font.pixelSize: 12
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.6) : Qt.rgba(1, 1, 1, 0.6)
  }

  Text {
    text: "Visualizer bottom: feature (proximamente)"
    font.family: Style.fontFamily
    font.pixelSize: 12
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.6) : Qt.rgba(1, 1, 1, 0.6)
  }
}
