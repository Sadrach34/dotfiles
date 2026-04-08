pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: watcher

    readonly property string wallpaperDir: Config.wallpaperDir
    readonly property string videoDir: Config.videoDir
    readonly property string weDir: Config.weDir
    readonly property bool steamEnabled: Config.steamEnabled
    property bool watching: false

    // Known filenames — the in-memory set that prevents re-processing
    property var _known: ({})
    property var _knownVid: ({})
    property var _knownWe: ({})

    // Suppressed filenames — files being replaced by optimization; skip events for these
    property var _suppressed: ({})

    signal fileAdded(string name, string path, string type)
    signal fileRemoved(string name, string type)
    signal weItemAdded(string weId, string weDir)
    signal weItemRemoved(string weId)

    // --- Public API ---

    function start() {
        if (watching || !Config.configLoaded || !wallpaperDir) return
        _startWatching()
    }

    // Process renamed a file (e.g. png→webp): update known set so we don't re-emit it
    function notifyRenamed(oldName, newName) {
        if (_known[oldName]) { delete _known[oldName]; _known[newName] = true }
        if (_knownVid[oldName]) { delete _knownVid[oldName]; _knownVid[newName] = true }
    }

    // Process added a file we should track without emitting
    function notifyAdded(name) {
        _known[name] = true
    }

    // Suppress/unsuppress watcher events for files being swapped by optimization
    function suppressFile(name) {
        _suppressed[name] = true
    }
    function unsuppressFile(name) {
        delete _suppressed[name]
    }

    // --- Extension lookups ---

    readonly property var _imageExts: {
        var o = {}
        ImageService.imageExtensions.forEach(function(e) { o[e] = 1 })
        return o
    }
    readonly property var _videoExts: {
        var o = {}
        ImageService.videoExtensions.forEach(function(e) { o[e] = 1 })
        return o
    }

    function _fileType(filename) {
        var dot = filename.lastIndexOf(".")
        if (dot < 0) return ""
        var ext = filename.substring(dot + 1).toLowerCase()
        if (_imageExts[ext]) return "static"
        if (_videoExts[ext]) return "video"
        return ""
    }

    // --- Config-ready gate ---
    // Use Qt.callLater to defer start() so all Config bindings
    // (_data, wallpaperDir, etc.) have settled after _rawText changes.

    property var _configReadyConn: Connections {
        target: Config
        function onConfigLoadedChanged() {
            if (Config.configLoaded && !watcher.watching)
                Qt.callLater(watcher.start)
        }
    }

    // --- Internal ---

    property bool _initialised: false

    function _startWatching() {
        _known = {}; _knownVid = {}; _knownWe = {}
        _initialised = false
        watching = true
        _monitor.command = _buildCommand()
        _monitor.running = true
    }

    function _sq(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function _buildCommand() {
        var dirs = [wallpaperDir]
        var vidSep = videoDir && videoDir !== wallpaperDir
        if (vidSep) dirs.push(videoDir)
        if (steamEnabled && weDir) dirs.push(weDir)

        var script = "shopt -s nullglob\n"

        // Scan wallpaperDir (all files — extension filtering done in QML)
        script += "for f in " + _sq(wallpaperDir) + "/*; do"
        script += " [ -f \"$f\" ] && printf 'SCAN\\t%s\\t%s\\n' " + _sq(wallpaperDir + "/") + " \"$(basename \"$f\")\";"
        script += " done\n"

        // Scan videoDir if separate
        if (vidSep) {
            script += "for f in " + _sq(videoDir) + "/*; do"
            script += " [ -f \"$f\" ] && printf 'SCAN\\t%s\\t%s\\n' " + _sq(videoDir + "/") + " \"$(basename \"$f\")\";"
            script += " done\n"
        }

        // Scan weDir for subdirectories
        if (steamEnabled && weDir) {
            script += "for d in " + _sq(weDir) + "/*/; do"
            script += " printf 'SCAN_DIR\\t%s\\t%s\\n' " + _sq(weDir + "/") + " \"$(basename \"$d\")\";"
            script += " done\n"
        }

        script += "printf 'SCAN_DONE\\t.\\t.\\n'\n"

        // Build watch list, filtering out directories that don't exist
        script += "_watch_dirs=()\n"
        for (var i = 0; i < dirs.length; i++)
            script += "[ -d " + _sq(dirs[i]) + " ] && _watch_dirs+=(" + _sq(dirs[i]) + ")\n"
        script += "[ ${#_watch_dirs[@]} -eq 0 ] && exit 0\n"

        // Long-running inotifywait monitor (stdbuf -oL forces line buffering on pipe)
        script += "exec stdbuf -oL inotifywait -m -e close_write,moved_to,moved_from,delete,create"
        script += " --format $'%e\\t%w\\t%f'"
        script += " \"${_watch_dirs[@]}\"\n"

        return ["bash", "-c", script]
    }

    // --- inotifywait process ---

    property var _monitor: Process {
        stdout: SplitParser {
            onRead: data => watcher._handleLine(data)
        }
        onExited: (code, status) => {
            watcher.watching = false
            watcher._initialised = false
        }
    }

    function _handleLine(line) {
        var parts = line.split("\t")
        if (parts.length < 3) return
        var event = parts[0]
        var dir = parts[1]
        var name = parts[2]

        if (event === "SCAN") {
            _handleScan(dir, name)
        } else if (event === "SCAN_DIR") {
            _knownWe[name] = true
        } else if (event === "SCAN_DONE") {
            _initialised = true
        } else {
            _handleEvent(event, dir, name)
        }
    }

    function _handleScan(dir, name) {
        if (name === "wallpaper.jpg") return
        var type = _fileType(name)
        if (!type) return
        var normDir = dir.replace(/\/$/, "")
        if (videoDir && videoDir !== wallpaperDir && normDir === videoDir) {
            _knownVid[name] = true
        } else {
            _known[name] = true
        }
    }

    function _handleEvent(event, dir, name) {
        if (!name || name === "wallpaper.jpg") return
        var normDir = dir.replace(/\/$/, "")
        var isDir = event.indexOf("ISDIR") >= 0

        // WE directory: only care about subdirectories
        if (steamEnabled && weDir && normDir === weDir) {
            if (!isDir) return
            if (event.indexOf("CREATE") >= 0 || event.indexOf("MOVED_TO") >= 0) {
                if (!_knownWe[name]) {
                    _knownWe[name] = true
                    if (_initialised) weItemAdded(name, weDir + "/" + name + "/")
                }
            } else if (event.indexOf("DELETE") >= 0 || event.indexOf("MOVED_FROM") >= 0) {
                if (_knownWe[name]) {
                    delete _knownWe[name]
                    if (_initialised) weItemRemoved(name)
                }
            }
            return
        }

        // Regular file directories — skip directory events and CREATE (wait for CLOSE_WRITE)
        if (isDir) return
        if (event.indexOf("CREATE") >= 0 && event.indexOf("CLOSE_WRITE") < 0) return

        var type = _fileType(name)
        if (!type) return

        // Skip events for files being swapped during optimization
        if (_suppressed[name]) return

        // Determine which known set and base dir
        var known = _known
        var fullDir = wallpaperDir
        if (videoDir && videoDir !== wallpaperDir && normDir === videoDir) {
            known = _knownVid
            fullDir = videoDir
        }

        if (event.indexOf("CLOSE_WRITE") >= 0 || event.indexOf("MOVED_TO") >= 0) {
            if (!known[name]) {
                known[name] = true
                if (_initialised) {
                    fileAdded(name, fullDir + "/" + name, type)
                }
            }
        } else if (event.indexOf("DELETE") >= 0 || event.indexOf("MOVED_FROM") >= 0) {
            if (known[name]) {
                delete known[name]
                if (_initialised) {
                    fileRemoved(name, type)
                }
            }
        }
    }
}
