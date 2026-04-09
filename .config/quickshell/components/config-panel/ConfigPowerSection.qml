import QtQuick
import Quickshell.Io
import "../skwd-wall/qml"

Column {
  id: root
  property var panel
  property var colors
  property bool hasBattery: false
  property bool powerCtlAvailable: false
  property string activeProfile: ""
  property string statusMessage: ""

  width: parent.width
  spacing: 8

  function _refreshPowerState() {
    powerStateProc.command = ["bash", "-lc", "has=0; ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && has=1; ctl=0; command -v powerprofilesctl >/dev/null 2>&1 && ctl=1; prof=''; [ \"$ctl\" = 1 ] && prof=$(powerprofilesctl get 2>/dev/null || true); printf 'hasBattery=%s\n' \"$has\"; printf 'powerCtl=%s\n' \"$ctl\"; printf 'profile=%s\n' \"$prof\";"]
    powerStateProc.rawOutput = ""
    powerStateProc.running = true
  }

  function _isLaptopMode() {
    var mode = panel.getNested(panel.configData, ["power", "deviceType"], "auto")
    return mode === "laptop"
  }

  function _effectiveLaptopMode() {
    var mode = panel.getNested(panel.configData, ["power", "deviceType"], "auto")
    if (mode === "laptop") return true
    if (mode === "desktop") return false
    return hasBattery
  }

  function _setMode(mode) {
    panel.setNested(panel.configData, ["power", "deviceType"], mode)
    panel.configDataChanged()

    if (!_effectiveLaptopMode()) {
      _applyProfile("performance")
    } else {
      var target = panel.getNested(panel.configData, ["power", "profile"], "balanced")
      _applyProfile(target)
    }
  }

  function _applyProfile(profile) {
    panel.setNested(panel.configData, ["power", "profile"], profile)
    panel.configDataChanged()

    if (!powerCtlAvailable) {
      statusMessage = "powerprofilesctl no disponible"
      return
    }

    applyProfileProc.command = ["bash", "-lc", "powerprofilesctl set " + profile + " >/dev/null 2>&1 || true"]
    applyProfileProc.running = true
  }

  onVisibleChanged: if (visible) _refreshPowerState()

  ConfigSectionTitle { text: "POWER"; colors: root.colors }

  Text {
    text: statusMessage !== "" ? statusMessage : (_effectiveLaptopMode() ? "Modo laptop/auto con batería: puedes elegir ahorro, balanceado o performance" : "Modo desktop/auto sin batería: se fuerza performance")
    font.family: Style.fontFamily
    font.pixelSize: 11
    color: colors ? Qt.rgba(colors.surfaceText.r, colors.surfaceText.g, colors.surfaceText.b, 0.8) : "#cfcfcf"
  }

  Row {
    spacing: 10

    Repeater {
      model: [
        { key: "auto", label: "AUTO" },
        { key: "laptop", label: "LAPTOP" },
        { key: "desktop", label: "DESKTOP" }
      ]

      Rectangle {
        width: 120
        height: 30
        radius: 6
        property bool selected: panel.getNested(panel.configData, ["power", "deviceType"], "auto") === modelData.key
        color: selected
          ? (colors ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.9) : "#4fc3f7")
          : (colors ? Qt.rgba(colors.surfaceContainer.r, colors.surfaceContainer.g, colors.surfaceContainer.b, 0.7) : "#30343d")

        Text {
          anchors.centerIn: parent
          text: modelData.label
          font.family: Style.fontFamily
          font.pixelSize: 11
          font.weight: Font.Bold
          color: parent.selected
            ? (colors ? colors.primaryText : "#101010")
            : (colors ? colors.surfaceText : "#dcdcdc")
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root._setMode(modelData.key)
        }
      }
    }
  }

  Row {
    spacing: 10
    visible: _effectiveLaptopMode()

    Repeater {
      model: [
        { key: "power-saver", label: "AHORRO" },
        { key: "balanced", label: "BALANCEADO" },
        { key: "performance", label: "PERFORMANCE" }
      ]

      Rectangle {
        width: 150
        height: 32
        radius: 6
        enabled: powerCtlAvailable
        opacity: enabled ? 1 : 0.6
        property bool selected: activeProfile === modelData.key
        color: selected
          ? (colors ? Qt.rgba(colors.primary.r, colors.primary.g, colors.primary.b, 0.9) : "#4fc3f7")
          : (colors ? Qt.rgba(colors.surfaceContainer.r, colors.surfaceContainer.g, colors.surfaceContainer.b, 0.7) : "#30343d")

        Text {
          anchors.centerIn: parent
          text: modelData.label
          font.family: Style.fontFamily
          font.pixelSize: 11
          font.weight: Font.Bold
          color: parent.selected
            ? (colors ? colors.primaryText : "#101010")
            : (colors ? colors.surfaceText : "#dcdcdc")
        }

        MouseArea {
          anchors.fill: parent
          enabled: parent.enabled
          cursorShape: Qt.PointingHandCursor
          onClicked: root._applyProfile(modelData.key)
        }
      }
    }
  }

  Text {
    text: "Perfil activo: " + (activeProfile || "(desconocido)")
    font.family: Style.fontFamilyCode
    font.pixelSize: 11
    color: colors ? colors.tertiary : "#8bceff"
  }

  Process {
    id: powerStateProc
    property string rawOutput: ""
    command: ["bash", "-lc", "true"]

    stdout: SplitParser {
      onRead: data => powerStateProc.rawOutput += data + "\n"
    }

    onExited: {
      var out = powerStateProc.rawOutput
      var hasMatch = out.match(/hasBattery=(\d)/)
      var ctlMatch = out.match(/powerCtl=(\d)/)
      var profileMatch = out.match(/profile=([^\n]*)/)

      hasBattery = hasMatch ? hasMatch[1] === "1" : false
      powerCtlAvailable = ctlMatch ? ctlMatch[1] === "1" : false
      activeProfile = profileMatch ? profileMatch[1].trim() : ""

      if (!powerCtlAvailable) {
        statusMessage = "powerprofilesctl no está instalado o no responde"
      } else if (!_effectiveLaptopMode()) {
        statusMessage = "Modo desktop/auto sin batería: performance automático"
      } else {
        statusMessage = ""
      }
    }
  }

  Process {
    id: applyProfileProc
    command: ["bash", "-lc", "true"]
    onExited: root._refreshPowerState()
  }
}
