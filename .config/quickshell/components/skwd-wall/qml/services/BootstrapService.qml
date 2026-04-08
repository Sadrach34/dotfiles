pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: bootstrap

    readonly property bool ready: _done
    property bool _done: false

    readonly property string _markerFile: Config.configDir + "/.bootstrapped"

    readonly property string _sourceDataDir: {
        var url = Qt.resolvedUrl("../../data")
        return url.toString().replace("file://", "")
    }

    property var _markerCheck: Process {
        id: markerCheck
        onExited: function(code, status) {
            if (code === 0) {
                bootstrap._done = true
                console.log("Bootstrap already ran, skipping")
            } else {
                bootstrap._run()
            }
        }
    }

    Component.onCompleted: {
        markerCheck.command = ["test", "-f", _markerFile]
        markerCheck.running = true
    }

    property var _proc: Process {
        id: proc
        onExited: function(code, status) {
            bootstrap._done = true
            if (code === 0)
                console.log("Bootstrap setup complete")
            else
                console.warn("Bootstrap setup finished with errors (exit " + code + ")")
        }
    }

    function _run() {
        var src = _sourceDataDir
        var configDir = Config.configDir
        var cacheDir = Config.cacheDir
        var wpDir = Config.wallpaperDir
        var scriptsDir = Config.scriptsDir
        var templateDir = Config.templateDir

        var script = [
            "set -e",
            "",
            "# Create required directories",
            "mkdir -p " + _q(configDir),
            "mkdir -p " + _q(cacheDir + "/wallpaper"),
            "mkdir -p " + _q(wpDir),
            "mkdir -p " + _q(scriptsDir),
            "mkdir -p " + _q(templateDir),
            "",
            "# Seed config.json if missing",
            "if [ ! -f " + _q(configDir + "/config.json") + " ]; then",
            "  cp " + _q(src + "/config.json.example") + " " + _q(configDir + "/config.json"),
            "  echo 'Bootstrap created default config.json'",
            "fi",
            "",
            "# Seed reload scripts (skip existing — user may have customized)",
            "for f in " + _q(src + "/scripts") + "/*.sh; do",
            "  [ -f \"$f\" ] || continue",
            "  name=$(basename \"$f\")",
            "  if [ ! -f " + _q(scriptsDir) + "/\"$name\" ]; then",
            "    cp \"$f\" " + _q(scriptsDir) + "/",
            "    chmod +x " + _q(scriptsDir) + "/\"$name\"",
            "    echo \"Bootstrap seeded script $name\"",
            "  fi",
            "done",
            "",
            "# Seed default colors.json if missing",
            "if [ ! -f " + _q(cacheDir + "/colors.json") + " ]; then",
            "  echo '{}' > " + _q(cacheDir + "/colors.json"),
            "  echo 'Bootstrap created default colors.json'",
            "fi",
            "",
            "# Seed matugen templates (skip existing — user may have customized)",
            "for f in " + _q(src + "/matugen/templates") + "/*; do",
            "  [ -f \"$f\" ] || continue",
            "  name=$(basename \"$f\")",
            "  if [ ! -f " + _q(templateDir) + "/\"$name\" ]; then",
            "    cp \"$f\" " + _q(templateDir) + "/",
            "    echo \"Bootstrap seeded template $name\"",
            "  fi",
            "done",
            "",
            "# Mark bootstrap as done",
            "date -Iseconds > " + _q(configDir + "/.bootstrapped"),
        ].join("\n")

        proc.command = ["bash", "-c", script]
        proc.running = true
    }

    function _q(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }
}
