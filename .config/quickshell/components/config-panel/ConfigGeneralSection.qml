import QtQuick
import "../skwd-wall/qml"

Column {
  id: root
  property var panel
  property var colors
  width: parent.width
  spacing: 8

  ConfigSectionTitle { text: "GENERAL"; colors: root.colors }

  ConfigTextField {
    label: "Compositor"
    value: panel.getNested(panel.configData, ["compositor"], "")
    onEdited: v => { panel.setNested(panel.configData, ["compositor"], v); panel.configDataChanged() }
    colors: root.colors
  }
  ConfigTextField {
    label: "Terminal"
    value: panel.getNested(panel.configData, ["terminal"], "")
    onEdited: v => { panel.setNested(panel.configData, ["terminal"], v); panel.configDataChanged() }
    colors: root.colors
  }
  ConfigTextField {
    label: "Monitor"
    value: panel.getNested(panel.configData, ["monitor"], "")
    onEdited: v => { panel.setNested(panel.configData, ["monitor"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "PATHS"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "Scripts"
    value: panel.getNested(panel.configData, ["paths", "scripts"], "")
    placeholder: "(default: install dir)"
    onEdited: v => { panel.setNested(panel.configData, ["paths", "scripts"], v); panel.configDataChanged() }
    colors: root.colors
  }
  ConfigTextField {
    label: "Cache"
    value: panel.getNested(panel.configData, ["paths", "cache"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "cache"], v); panel.configDataChanged() }
    colors: root.colors
  }
  ConfigTextField {
    label: "Steam"
    value: panel.getNested(panel.configData, ["paths", "steam"], "")
    onEdited: v => { panel.setNested(panel.configData, ["paths", "steam"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "OLLAMA"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "URL"
    value: panel.getNested(panel.configData, ["ollama", "url"], "")
    onEdited: v => { panel.setNested(panel.configData, ["ollama", "url"], v); panel.configDataChanged() }
    colors: root.colors
  }
  ConfigTextField {
    label: "Model"
    value: panel.getNested(panel.configData, ["ollama", "model"], "")
    onEdited: v => { panel.setNested(panel.configData, ["ollama", "model"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "MATUGEN"; topPad: 16; colors: root.colors }

  ConfigTextField {
    label: "Scheme type"
    value: panel.getNested(panel.configData, ["matugen", "schemeType"], "")
    onEdited: v => { panel.setNested(panel.configData, ["matugen", "schemeType"], v); panel.configDataChanged() }
    colors: root.colors
  }
  ConfigTextField {
    label: "KDE color scheme"
    value: panel.getNested(panel.configData, ["matugen", "kdeColorScheme"], "")
    onEdited: v => { panel.setNested(panel.configData, ["matugen", "kdeColorScheme"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigSectionTitle { text: "OPTIMIZACION"; topPad: 16; colors: root.colors }

  ConfigToggle {
    label: "Optimization mode (solo wallpapers)"
    checked: panel.getNested(panel.configData, ["optimization", "enabled"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "enabled"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar bordes"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableBorders"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableBorders"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar transparencia"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableTransparency"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableTransparency"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar animaciones"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableAnimations"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableAnimations"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar blur"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableBlur"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableBlur"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar sombras"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableShadows"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableShadows"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar redondeado"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableRounding"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableRounding"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar gaps"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableGaps"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableGaps"], v); panel.configDataChanged() }
    colors: root.colors
  }

  ConfigToggle {
    label: "Quitar dim inactive"
    checked: panel.getNested(panel.configData, ["optimization", "toggles", "disableDimInactive"], false)
    onToggled: v => { panel.setNested(panel.configData, ["optimization", "toggles", "disableDimInactive"], v); panel.configDataChanged() }
    colors: root.colors
  }
}
