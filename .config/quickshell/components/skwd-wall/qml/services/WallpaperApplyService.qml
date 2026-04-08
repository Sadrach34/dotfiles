pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: service

    readonly property string wallpaperDir: Config.wallpaperDir
    readonly property string videoDir: Config.videoDir
    readonly property string weDir: Config.weDir
    readonly property string weAssetsDir: Config.weAssetsDir
    readonly property string weBinary: Config.weBinary
    readonly property string cacheDir: Config.cacheDir
    readonly property string mainMonitor: Config.mainMonitor
    readonly property string ollamaUrl: Config.ollamaUrl
    readonly property string ollamaModel: Config.ollamaModel
    property string matugenScheme: "scheme-fidelity"
    property bool wallpaperMute: true
    readonly property string _matugenConfig: cacheDir + "/matugen-config.toml"
    readonly property var _transitionCfg: Config._data && Config._data.wallpaperTransition ? Config._data.wallpaperTransition : ({})
    property bool _stateFileLoaded: false
    property var _stateFile: FileView {
        path: service.cacheDir + "/last-wallpaper.json"
        preload: true
        watchChanges: true
        onLoaded: {
            service._stateFileLoaded = true
            service._tryRestore()
        }
        onFileChanged: {
            _stateFile.reload()
            service._handleExternalStateChange()
        }
    }

    Component.onCompleted: {
        var data = Config._data
        if (data.matugen) {
            if (data.matugen.schemeType) matugenScheme = data.matugen.schemeType
        }
        if (data.wallpaperMute !== undefined) wallpaperMute = data.wallpaperMute

        // Ensure last wallpaper is restored after session startup.
        _restoreRequested = true
        _tryRestore()
    }

    signal wallpaperApplied(string type, string name)

    function _transitionArgs() {
        var type = _transitionCfg.type || "grow"
        var fps = parseInt(_transitionCfg.fps || 90)
        var duration = Number(_transitionCfg.duration || 0.9)
        var angle = parseInt(_transitionCfg.angle || 30)
        var bezier = _transitionCfg.bezier || ".22,1,.36,1"
        var pos = _transitionCfg.pos || "0.5,0.5"

        if (!isFinite(fps) || fps <= 0) fps = 90
        if (!isFinite(duration) || duration <= 0) duration = 0.9
        if (!isFinite(angle)) angle = 30

        return " --transition-type " + JSON.stringify(type) +
               " --transition-fps " + fps +
               " --transition-duration " + duration +
               " --transition-angle " + angle +
               " --transition-bezier " + JSON.stringify(bezier) +
               " --transition-pos " + JSON.stringify(pos)
    }

    function applyStatic(path) {
        console.log("WallpaperApplyService.applyStatic:", path, "wallpaperDir:", wallpaperDir)
        _saveState("static", path, "")
        awwwProcess.command = ["sh", "-c",
            "pkill mpvpaper 2>/dev/null; " +
            "pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null; " +
            "rm -f " + JSON.stringify(videoDir + "/lockscreen-video.mp4") + "; " +
            "if ! pgrep -x awww-daemon >/dev/null; then " +
            "  setsid awww-daemon >/dev/null 2>&1 & disown; " +
            "  for i in 1 2 3 4 5; do sleep 0.3; pgrep -x awww-daemon >/dev/null && break; done; " +
            "fi; " +
            "awww img " + JSON.stringify(path) + service._transitionArgs()]
        awwwProcess.running = true
        _extractAndTheme(path)
        wallpaperApplied("static", _basename(path))
    }

    function applyVideo(path) {
        _saveState("video", path, "")
        mpvProcess.command = ["sh", "-c",
            "pkill awww 2>/dev/null; pkill awww-daemon 2>/dev/null; " +
            "pkill mpvpaper 2>/dev/null; " +
            "pkill -9 -f '[l]inux-wallpaperengine' 2>/dev/null; " +
            "rm -f " + JSON.stringify(videoDir + "/lockscreen-video.mp4") + "; " +
            "nohup setsid mpvpaper -o " + (wallpaperMute ? "'loop --mute=yes'" : "'loop'") + " '*' " + JSON.stringify(path) + " </dev/null >/dev/null 2>&1 &"]
        mpvProcess.running = true
        _extractVideoThumb(path)
        wallpaperApplied("video", _basename(path))
    }

    function applyWE(weId) {
        _saveState("we", "", weId)
        _weRetryCount = 0
        _lastWeId = weId
        _reclaimOllamaVram()
        _pendingAction = function() {
            _launchWE(weId)
            _extractWEThumb(weId)
            wallpaperApplied("we", weId)
        }
        _killAll()
    }

    property bool _restoreRequested: false

    function restore() {
        _restoreRequested = true
        _tryRestore()
    }

    function _tryRestore() {
        if (!_restoreRequested || !_stateFileLoaded) return
        _restoreRequested = false
        var text = _stateFile.text().trim()
        if (!text) return
        try {
            var state = JSON.parse(text)
            if (state.type === "static" && state.path)
                applyStatic(state.path)
            else if (state.type === "video" && state.path)
                applyVideo(state.path)
            else if (state.type === "we" && state.we_id)
                applyWE(state.we_id)
        } catch(e) {
            console.log("WallpaperApplyService: restore failed:", e)
        }
    }

    function _saveState(type, path, weId) {
        var obj = { type: type }
        if (path) obj.path = path
        if (weId) obj.we_id = weId
        _stateFile.setText(JSON.stringify(obj))
    }

    function _readStateSafe() {
        var text = _stateFile.text().trim()
        if (!text) return null
        try { return JSON.parse(text) }
        catch (e) { return null }
    }

    function _shouldRetryWE(weId) {
        if (!weId) return false
        var st = _readStateSafe()
        return !!(st && st.type === "we" && String(st.we_id || "") === String(weId))
    }

    function _handleExternalStateChange() {
        var st = _readStateSafe()
        if (!st || st.type !== "we") {
            _weRetryCount = 0
            _lastWeId = ""
            weRetryTimer.stop()
        }
    }

    property var _pendingAction: null
    property var _killProcess: Process {
        id: killProcess
        onExited: {
            if (service._pendingAction) {
                var action = service._pendingAction
                service._pendingAction = null
                action()
            }
        }
    }

    function _killAll() {
        killProcess.command = ["sh", "-c",
            "for p in $(pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' 2>/dev/null); do kill -TERM \"$p\" 2>/dev/null; done; " +
            "for i in $(seq 1 40); do pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' >/dev/null || break; sleep 0.05; done; " +
            "for p in $(pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' 2>/dev/null); do kill -KILL \"$p\" 2>/dev/null; done; " +
            "for i in $(seq 1 20); do pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' >/dev/null || break; sleep 0.05; done; " +
            "pkill mpvpaper 2>/dev/null; " +
            "pkill awww 2>/dev/null; " +
            "pkill awww-daemon 2>/dev/null; " +
            "rm -f " + JSON.stringify(videoDir + "/lockscreen-video.mp4") + "; " +
            "sleep 0.2; true"]
        killProcess.running = true
    }

    property var _awwwStderr: []
    property var _awwwProcess: Process {
        id: awwwProcess
        onExited: function(code, status) {
            console.log("WallpaperApplyService: awww exited code=" + code + " status=" + status)
            if (_awwwStderr.length > 0) console.log("WallpaperApplyService: awww stderr:", _awwwStderr.join(""))
            _awwwStderr = []
        }
        stderr: SplitParser { onRead: data => service._awwwStderr.push(data) }
    }
    property var _mpvProcess: Process { id: mpvProcess }
    property var _awwwDaemonProcess: Process { id: awwwDaemonProcess }

    property var _weStderr: []
    property int _weRetryCount: 0
    property string _lastWeId: ""
    property var _weProcess: Process {
        id: weProcess
        onExited: function(code, status) {
            if (code !== 0 || service._weStderr.length > 0) {
                console.log("WallpaperApplyService: WE exited code=" + code + " status=" + status +
                            (service._weStderr.length > 0 ? " stderr: " + service._weStderr.join("") : ""))
                if (code !== 0 && service._lastWeId) {
                    if (!service._shouldRetryWE(service._lastWeId)) {
                        console.log("WallpaperApplyService: skip WE retry, state no longer requests this WE")
                        service._weRetryCount = 0
                        service._lastWeId = ""
                    } else if (service._weRetryCount < 3) {
                        service._weRetryCount += 1
                        console.log("WallpaperApplyService: WE failed, retry", service._weRetryCount, "for", service._lastWeId)
                        weRetryTimer.restart()
                    } else {
                        console.log("WallpaperApplyService: WE scene failed after retries, falling back to preview image")
                        service._applyWePreviewFallback(service._lastWeId)
                    }
                }
            }
            service._weStderr = []
        }
        stderr: SplitParser { onRead: data => service._weStderr.push(data) }
    }

    property var _weRetryTimer: Timer {
        id: weRetryTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (service._lastWeId && service._shouldRetryWE(service._lastWeId))
                service._launchWEScene(service._lastWeId)
        }
    }

    function _launchWE(weId) {
        _weProjectStdout = []
        _weReadProject.command = ["cat", weDir + "/" + weId + "/project.json"]
        _weReadProject.running = true
        _pendingWeId = weId
    }

    property string _pendingWeId: ""
    property var _weProjectStdout: []
    property var _weReadProject: Process {
        id: weReadProject
        onExited: {
            var text = _weProjectStdout.join("")
            try {
                var proj = JSON.parse(text)
                var weType = (proj.type || "scene").toLowerCase()
                var weFile = proj.file || ""
                var id = service._pendingWeId
                var basePath = service.weDir + "/" + id

                if (weType === "video" && weFile) {
                    var videoPath = basePath + "/" + weFile
                    _symLinkProcess.command = ["ln", "-sf", videoPath,
                                               service.videoDir + "/lockscreen-video.mp4"]
                    _symLinkProcess.running = true
                    var opts = "loop"
                    if (service.wallpaperMute) opts = "loop --mute=yes"
                    weProcess.command = ["sh", "-c",
                        "pkill mpvpaper 2>/dev/null; " +
                        "nohup setsid mpvpaper -o '" + opts + "' '*' " + JSON.stringify(videoPath) + " </dev/null >/dev/null 2>&1 &"]
                    weProcess.running = true
                } else {
                    _launchWEScene(id)
                }
            } catch(e) {
                service._launchWEScene(service._pendingWeId)
            }
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => _weProjectStdout.push(data)
        }
    }

    property var _symLinkProcess: Process { id: symLinkProcess }

    function _launchWEScene(weId) {
        service._lastWeId = weId
        var mons = Quickshell.screens.map(function(s) { return s.name })
        var screenArgs = ""
        for (var i = 0; i < mons.length; i++)
            screenArgs += " --screen-root " + mons[i] + " --scaling fill --clamp border"
        var propArgs = " --set-property bmomode=0"
        if (String(weId) === "3353695150") {
            propArgs += " --set-property showtext=0 --set-property pixelate=0 --set-property displaymode=2 --set-property audioresponsivebackground=0 --set-property audioresponsivebars=0"
        }
        var audioFlag = service.wallpaperMute ? "--silent" : ""
        var assetsArg = service.weAssetsDir ? (" --assets-dir " + JSON.stringify(service.weAssetsDir)) : ""
        var bin = service.weBinary && service.weBinary.length > 0
            ? service.weBinary
            : "linux-wallpaperengine"
        var cmd = "[ -x " + JSON.stringify(bin) + " ] || command -v " + JSON.stringify(bin) + " >/dev/null 2>&1 || exit 127; " +
            "exec " + JSON.stringify(bin) + " " + audioFlag +
            " --no-fullscreen-pause --noautomute" + propArgs + screenArgs +
            assetsArg + " " + JSON.stringify(weId)
        console.log("WallpaperApplyService: launching WE scene:", cmd)
        weProcess.command = ["sh", "-c", cmd]
        weProcess.running = true
    }

    function _applyWePreviewFallback(weId) {
        var basePath = weDir + "/" + weId
        _wePreviewFallbackProc.command = ["sh", "-c",
            "for p in " + JSON.stringify(basePath) + "/preview.jpg " +
            JSON.stringify(basePath) + "/preview.png " +
            JSON.stringify(basePath) + "/preview.gif; do " +
            "[ -f \"$p\" ] && echo \"$p\" && exit 0; done; exit 1"]
        _wePreviewFallbackProc.running = true
    }

    property string _wePreviewStdout: ""
    property var _wePreviewFallbackProc: Process {
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => service._wePreviewStdout += data
        }
        onExited: function(code) {
            var preview = service._wePreviewStdout.trim()
            service._wePreviewStdout = ""
            if (code === 0 && preview) {
                console.log("WallpaperApplyService: applying WE preview fallback:", preview)
                service.applyStatic(preview)
            }
        }
    }

    function _extractAndTheme(path) {
        _copyAndTheme.command = ["sh", "-c",
            "cp " + JSON.stringify(path) + " " + JSON.stringify(wallpaperDir + "/wallpaper.jpg") + " 2>/dev/null; " +
            _matugenCmd(path)]
        _copyAndTheme.running = true
    }

    // Reuse the exact wallpaper theming pipeline for arbitrary images.
    function applyThemeFromImage(path) {
        if (!path || !Config.matugenEnabled) return
        var resolved = String(path)
        if (resolved.startsWith("~")) resolved = Config.homeDir + resolved.substring(1)
        _extractAndTheme(resolved)
    }

    property var _videoThumbStdout: []
    function _extractVideoThumb(videoPath) {
        var name = _basename(videoPath).replace(/\.[^.]+$/, "") + ".jpg"
        var thumbDir = cacheDir + "/wallpaper/video-thumbs"
        var thumbPath = thumbDir + "/" + name
        _videoThumbProcess.command = ["sh", "-c",
            "mkdir -p " + JSON.stringify(thumbDir) + "; " +
            "[ -f " + JSON.stringify(thumbPath) + " ] || " +
            ImageService.videoThumbnailCmd(JSON.stringify(videoPath), JSON.stringify(thumbPath), 0) + "; " +
            "cp " + JSON.stringify(thumbPath) + " " + JSON.stringify(wallpaperDir + "/wallpaper.jpg") + " 2>/dev/null; " +
            _matugenCmd(thumbPath)]
        _videoThumbProcess.running = true
    }
    property var _videoThumbProcess: Process {
        id: videoThumbProcess
        onExited: function(code) {
            if (code === 2) { console.log("WallpaperApplyService: matugen output unchanged, skipping reloads"); return }
            service._propagateColors()
        }
    }

    function _extractWEThumb(weId) {
        _weFindPreviewStdout = []
        _weFindPreview.command = ["find", weDir + "/" + weId, "-maxdepth", "1",
                                  "-iname", "preview.*", "-type", "f"]
        _weFindPreview.running = true
    }

    property var _weFindPreviewStdout: []
    property var _weFindPreview: Process {
        id: weFindPreview
        onExited: {
            var preview = _weFindPreviewStdout.join("").trim().split("\n")[0]
            if (preview) {
                _copyAndTheme.command = ["sh", "-c",
                    "cp " + JSON.stringify(preview) + " " + JSON.stringify(service.wallpaperDir + "/wallpaper.jpg") + " 2>/dev/null; " +
                    service._matugenCmd(preview)]
                _copyAndTheme.running = true
            }
        }
        stdout: SplitParser {
            onRead: data => _weFindPreviewStdout.push(data)
        }
    }

    property var _copyAndTheme: Process {
        id: copyAndThemeProcess
        onExited: function(code) {
            if (code === 2) { console.log("WallpaperApplyService: matugen output unchanged, skipping reloads"); return }
            service._propagateColors()
        }
    }

    function _matugenOutputFiles() {
        var ints = Config.integrations
        var files = []
        for (var i = 0; i < ints.length; i++) {
            var o = ints[i].output
            if (!o) continue
            files.push(o.indexOf("/") >= 0 ? Config._resolve(o) : Config.cacheDir + "/" + o)
        }
        return files
    }

    function _matugenCmd(imagePath) {
        if (!Config.matugenEnabled) return "true"
        var outputs = _matugenOutputFiles()
        var hashFiles = outputs.map(function(f) { return JSON.stringify(f) }).join(" ")
        var before = hashFiles ? "_BEFORE=$(md5sum " + hashFiles + " 2>/dev/null | sort); " : ""
        var matugen = "command -v matugen >/dev/null && matugen -c " +
            JSON.stringify(_matugenConfig) +
            " image -t " + JSON.stringify(matugenScheme) +
            " --source-color-index 0 " + JSON.stringify(imagePath) + " || true"
        if (!hashFiles) return matugen
        var after = "_AFTER=$(md5sum " + hashFiles + " 2>/dev/null | sort); "
        return before + matugen + "; " + after + '[ "$_BEFORE" = "$_AFTER" ] && exit 2; exit 0'
    }

    function _propagateColors() {
        if (!Config.matugenEnabled) return
        var integrations = Config.integrations
        console.log("propagateColors: running", integrations.length, "integrations")
        for (var i = 0; i < integrations.length; i++) {
            var reload = integrations[i].reload
            if (!reload) continue
            var resolved = Config._resolve(reload)
            if (resolved.indexOf("/") >= 0 && resolved.indexOf(" ") < 0)
                _runReload("sh " + JSON.stringify(resolved))
            else
                _runReload(resolved)
        }

        _runReload("command -v notify-send >/dev/null && notify-send 'Wallpaper Changed' || true")
    }

    function _runReload(cmd) {
        console.log("runReload:", cmd)
        var proc = reloadComponent.createObject(service)
        proc.command = ["sh", "-c", cmd]
        proc.exited.connect(function() { proc.destroy() })
        proc.running = true
    }
    property var reloadComponent: Component {
        Process {}
    }

    function _reclaimOllamaVram() {
        if (!ollamaUrl || !ollamaModel) return
        var xhr = new XMLHttpRequest()
        xhr.open("POST", ollamaUrl + "/api/generate")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({model: ollamaModel, keep_alive: 0}))
    }

    function _basename(path) {
        var parts = path.split("/")
        return parts[parts.length - 1]
    }
}
