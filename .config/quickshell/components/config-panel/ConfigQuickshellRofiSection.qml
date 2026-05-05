import QtQuick
import "../skwd-wall/qml"

Column {
  id: root
  property var panel
  property var colors
  width: parent.width
  spacing: 8

  ConfigSectionTitle { text: "QUICKSHELL vs ROFI"; colors: root.colors }

  Text {
    text: "Elige el backend para cada componente"
    font.family: Style.fontFamily
    font.pixelSize: 12
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.7) : Qt.rgba(1, 1, 1, 0.7)
  }

  ConfigSectionTitle { text: "APP LAUNCHER"; topPad: 12; colors: root.colors }

  ConfigToggle {
    label: "App Launcher habilitado"
    checked: {
      var al = panel.getNested(panel.configData, ["components", "appLauncher"], true)
      if (typeof al === "boolean") return al
      return al?.enabled !== false
    }
    onToggled: v => {
      panel.setNested(panel.configData, ["components", "appLauncher", "enabled"], v)
      panel.configDataChanged()
    }
    colors: root.colors
  }

  ConfigToggle {
    label: "Usar Rofi para App Launcher"
    checked: panel.getNested(panel.configData, ["components", "appLauncher", "backend"], "quickshell") === "rofi"
    onToggled: v => {
      panel.setNested(panel.configData, ["components", "appLauncher", "backend"], v ? "rofi" : "quickshell")
      panel.configDataChanged()
    }
    colors: root.colors
  }

  ConfigSectionTitle { text: "WALLPAPER SELECTOR"; topPad: 12; colors: root.colors }

  ConfigToggle {
    label: "Wallpaper Selector habilitado"
    checked: {
      var ws = panel.getNested(panel.configData, ["components", "wallpaperSelector"], undefined)
      return ws !== false && ws?.enabled !== false
    }
    onToggled: v => {
      panel.setNested(panel.configData, ["components", "wallpaperSelector", "enabled"], v)
      panel.configDataChanged()
    }
    colors: root.colors
  }

  ConfigToggle {
    label: "Usar Rofi para Wallpaper Selector"
    checked: panel.getNested(panel.configData, ["components", "wallpaperSelector", "backend"], "quickshell") === "rofi"
    onToggled: v => {
      panel.setNested(panel.configData, ["components", "wallpaperSelector", "backend"], v ? "rofi" : "quickshell")
      panel.configDataChanged()
    }
    colors: root.colors
  }

  ConfigSectionTitle { text: "WAYBAR MODULES"; topPad: 12; colors: root.colors }

  ConfigToggle {
    label: "Top Panel (QS)"
    checked: panel.getNested(panel.configData, ["components", "bar", "topPanel"], true)
    onToggled: v => {
      panel.setNested(panel.configData, ["components", "bar", "topPanel"], v)
      panel.configDataChanged()
    }
    colors: root.colors
  }

  ConfigToggle {
    label: "Dashboard (QS)"
    checked: panel.getNested(panel.configData, ["components", "bar", "dashboard"], true)
    onToggled: v => {
      panel.setNested(panel.configData, ["components", "bar", "dashboard"], v)
      panel.configDataChanged()
    }
    colors: root.colors
  }

  Text {
    text: "Cuando Dashboard está desactivado, aparecerá un botón de Power Menu en su lugar."
    font.family: Style.fontFamily
    font.pixelSize: 11
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.6) : Qt.rgba(1, 1, 1, 0.6)
    wrapMode: Text.Wrap
  }

  ConfigSectionTitle { text: "AUTO-START"; topPad: 16; colors: root.colors }

  Text {
    text: "Quickshell se inicia automáticamente al arrancar solo si al menos uno de sus componentes está habilitado."
    font.family: Style.fontFamily
    font.pixelSize: 11
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.6) : Qt.rgba(1, 1, 1, 0.6)
    wrapMode: Text.Wrap
  }
}
