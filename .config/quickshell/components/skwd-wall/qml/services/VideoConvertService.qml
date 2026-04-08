pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: svc

    readonly property int maxJobs: 2

    readonly property var presets: ({
        "light":    { label: "Light",    crf: 28, maxrate: "6M",  bufsize: "12M" },
        "balanced": { label: "Balanced", crf: 26, maxrate: "10M", bufsize: "20M" },
        "quality":  { label: "Quality",  crf: 23, maxrate: "16M", bufsize: "32M" }
    })

    readonly property var resolutions: ({
        "1080p": { label: "1080p", maxW: 1920, maxH: 1080 },
        "2k":    { label: "2K",    maxW: 2560, maxH: 1440 },
        "4k":    { label: "4K",    maxW: 3840, maxH: 2160 }
    })

    property bool running: false
    property int progress: 0
    property int total: 0
    property int skipped: 0
    property string currentFile: ""

    signal finished(int converted, int skippedCount, int failed)

    readonly property string _convertedDir: Config.cacheDir + "/wallpaper/converted-videos"
    readonly property string _trashDir: Config.cacheDir + "/wallpaper/trash/videos"

    property var _queue: []
    property int _activeJobs: 0
    property int _converted: 0
    property int _failed: 0

    property var _scanStdout: []

    function convert(presetKey, resolutionKey) {
        if (running) return
        var preset = presets[presetKey]
        var res = resolutions[resolutionKey || "2k"]
        if (!preset || !res) return
        running = true
        progress = 0
        total = 0
        skipped = 0
        currentFile = ""
        _queue = []
        _activeJobs = 0
        _converted = 0
        _failed = 0
        _currentPreset = presetKey
        _currentPresetData = preset
        _currentResolution = res
        _mkdirs.running = true
    }

    function cancel() {
        if (!running) return
        _queue = []
        // Active jobs will finish but no new ones will start
    }

    property string _currentPreset: "balanced"
    property var _currentPresetData: presets["balanced"]
    property var _currentResolution: resolutions["2k"]

    property var _mkdirs: Process {
        command: ["sh", "-c", "mkdir -p " + DbService.shellQuote(svc._convertedDir) + " " + DbService.shellQuote(svc._trashDir) + " " + DbService.shellQuote(Config.videoDir)]
        onExited: svc._scanVideos()
    }

    function _scanVideos() {
        _scanStdout = []
        var vidDir = DbService.shellQuote(Config.videoDir)
        var weDir = Config.weDir ? DbService.shellQuote(Config.weDir) : '""'

        var script =
            'find ' + vidDir + ' -type f ' + ImageService.findExtPattern(ImageService.videoExtensions.filter(function(e) { return e !== "gif" })) + ' 2>/dev/null\n' +
            'if [ -d ' + weDir + ' ]; then\n' +
            '  find ' + weDir + ' -maxdepth 2 -type f ' + ImageService.findExtPattern(ImageService.videoExtensions.filter(function(e) { return e !== "gif" })) + ' ! -iname "preview.*" 2>/dev/null\n' +
            'fi\n'

        _scanProcess.command = ["sh", "-c", script]
        _scanProcess.running = true
    }

    property var _scanProcess: Process {
        stdout: SplitParser {
            onRead: data => svc._scanStdout.push(data)
        }
        onExited: svc._buildQueue()
    }

    function _buildQueue() {
        var rows = DbService.query("SELECT src,preset FROM video_convert")
        var already = {}
        for (var i = 0; i < rows.length; i++)
            already[rows[i].src] = rows[i].preset

        var allFiles = _scanStdout.filter(function(l) { return l.trim() !== "" })
        var queue = []
        var skippedCount = 0

        for (var j = 0; j < allFiles.length; j++) {
            var src = allFiles[j].trim()
            if (!src) continue
            // Skip if already converted with same or higher quality preset
            if (already[src] === _currentPreset) {
                skippedCount++
                continue
            }
            queue.push(src)
        }

        _queue = queue
        total = queue.length + skippedCount
        skipped = skippedCount
        progress = skippedCount

        if (queue.length === 0) {
            _finish()
            return
        }

        _startWorkers()
    }

    function _startWorkers() {
        while (_activeJobs < maxJobs && _queue.length > 0) {
            var src = _queue.shift()
            _activeJobs++
            _launchWorker(src)
        }
        if (_activeJobs === 0) _finish()
    }

    function _launchWorker(src) {
        var preset = _currentPresetData
        var destName = src.split("/").pop().replace(/\.[^.]*$/, ".mp4")
        var dest = _convertedDir + "/" + destName

        // Avoid collisions by appending hash of source path
        var hash = 0
        for (var c = 0; c < src.length; c++) {
            hash = ((hash << 5) - hash + src.charCodeAt(c)) | 0
        }
        var hashStr = Math.abs(hash).toString(36)
        dest = _convertedDir + "/" + destName.replace(/\.mp4$/, "-" + hashStr + ".mp4")

        // WE videos get relocated to videoDir after conversion
        var isWE = Config.weDir && src.indexOf(Config.weDir + "/") === 0
        var finalDest = isWE
            ? Config.videoDir + "/" + destName.replace(/\.mp4$/, "-" + hashStr + ".mp4")
            : src

        var vf = "scale='min(" + svc._currentResolution.maxW + "\\,iw)':'min(" + svc._currentResolution.maxH + "\\,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2"
        var cmd =
            "src=" + DbService.shellQuote(src) + "\n" +
            "dest=" + DbService.shellQuote(dest) + "\n" +
            "final_dest=" + DbService.shellQuote(finalDest) + "\n" +
            "orig_size=$(stat -c '%s' \"$src\" 2>/dev/null || echo 0)\n" +
            "width=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 \"$src\" 2>/dev/null || echo 0)\n" +
            "height=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 \"$src\" 2>/dev/null || echo 0)\n" +
            "codec=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 \"$src\" 2>/dev/null || echo unknown)\n" +
            // Skip if already HEVC and within resolution limits
            "if [ \"$codec\" = \"hevc\" ] && [ \"$width\" -le " + svc._currentResolution.maxW + " ] && [ \"$height\" -le " + svc._currentResolution.maxH + " ]; then\n" +
            "  echo \"SKIP:$orig_size:$width:$height:$codec\"\n" +
            "  exit 0\n" +
            "fi\n" +
            "ffmpeg -y -i \"$src\" " +
            "-c:v libx265 -preset medium -crf " + preset.crf + " -maxrate " + preset.maxrate + " -bufsize " + preset.bufsize + " " +
            "-vf '" + vf + "' " +
            "-an -movflags +faststart -tag:v hvc1 " +
            "\"$dest\" 2>/dev/null\n" +
            "rc=$?\n" +
            "if [ $rc -eq 0 ] && [ -f \"$dest\" ]; then\n" +
            "  new_size=$(stat -c '%s' \"$dest\" 2>/dev/null || echo 0)\n" +
            "  new_width=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of csv=p=0 \"$dest\" 2>/dev/null || echo 0)\n" +
            "  new_height=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of csv=p=0 \"$dest\" 2>/dev/null || echo 0)\n" +
            // Move original to trash, then place converted at final destination
            "  trash_name=$(echo \"$src\" | md5sum | cut -c1-8)_$(basename \"$src\")\n" +
            "  mv \"$src\" " + DbService.shellQuote(svc._trashDir) + "/\"$trash_name\"\n" +
            "  touch " + DbService.shellQuote(svc._trashDir) + "/\"$trash_name\"\n" +
            "  mv \"$dest\" \"$final_dest\"\n" +
            "  echo \"OK:$orig_size:$new_size:$new_width:$new_height:$codec\"\n" +
            "else\n" +
            "  rm -f \"$dest\" 2>/dev/null\n" +
            "  echo \"FAIL:$orig_size:$width:$height:$codec\"\n" +
            "fi\n"

        currentFile = src.split("/").pop()
        var proc = _workerComponent.createObject(svc, {
            command: ["sh", "-c", cmd],
            _src: src,
            _finalDest: finalDest
        })
        proc.running = true
    }

    property var _workerComponent: Component {
        Process {
            id: convertWorker
            property string _src
            property string _finalDest: ""
            property string _stdout: ""
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => convertWorker._stdout += data
            }
            onExited: {
                var output = convertWorker._stdout.trim()
                var lines = output.split("\n")
                var resultLine = lines[lines.length - 1] || ""

                if (resultLine.indexOf("OK:") === 0) {
                    var p = resultLine.split(":")
                    svc._recordConversion(convertWorker._src, p, convertWorker._finalDest)
                    svc._converted++
                } else if (resultLine.indexOf("SKIP:") === 0) {
                    var sp = resultLine.split(":")
                    svc._recordSkip(convertWorker._src, sp)
                    svc.skipped++
                } else {
                    svc._failed++
                }

                svc.progress++
                svc._activeJobs--
                svc._startWorkers()
                destroy()
            }
        }
    }

    function _recordConversion(src, parts, finalDest) {
        var dest = finalDest || src
        var origSize = parts[1] || "0"
        var newSize = parts[2] || "0"
        var newW = parts[3] || "0"
        var newH = parts[4] || "0"
        var now = Math.floor(Date.now() / 1000)
        // Record with final destination as key so future scans skip it
        DbService.exec(
            "INSERT INTO video_convert(src,dest,preset,codec,width,height,orig_size,new_size,converted_at) VALUES(" +
            DbService.sqlStr(dest) + "," + DbService.sqlStr(dest) + "," +
            DbService.sqlStr(_currentPreset) + ",'hevc'," +
            newW + "," + newH + "," + origSize + "," + newSize + "," + now +
            ") ON CONFLICT(src) DO UPDATE SET dest=excluded.dest,preset=excluded.preset,codec=excluded.codec," +
            "width=excluded.width,height=excluded.height,orig_size=excluded.orig_size,new_size=excluded.new_size,converted_at=excluded.converted_at;")
        // Clean up WE meta entry — video has been relocated to wallpaperDir
        if (dest !== src && Config.weDir) {
            var weId = src.replace(Config.weDir + "/", "").split("/")[0]
            if (weId) DbService.exec("DELETE FROM meta WHERE we_id=" + DbService.sqlStr(weId))
        }
    }

    function _recordSkip(src, parts) {
        var origSize = parts[1] || "0"
        var w = parts[2] || "0"
        var h = parts[3] || "0"
        var codec = parts[4] || "hevc"
        var now = Math.floor(Date.now() / 1000)
        DbService.exec(
            "INSERT INTO video_convert(src,dest,preset,codec,width,height,orig_size,new_size,converted_at) VALUES(" +
            DbService.sqlStr(src) + "," + DbService.sqlStr(src) + "," +
            DbService.sqlStr(_currentPreset) + "," + DbService.sqlStr(codec) + "," +
            w + "," + h + "," + origSize + "," + origSize + "," + now +
            ") ON CONFLICT(src) DO UPDATE SET preset=excluded.preset,converted_at=excluded.converted_at;")
    }

    function _finish() {
        currentFile = ""
        running = false
        finished(_converted, skipped, _failed)
    }

    function cleanTrash() {
        if (!Config.autoDeleteVideoTrash) return
        _trashCleanProcess.command = ["sh", "-c",
            "find " + DbService.shellQuote(_trashDir) + " -type f -mtime +" + Config.videoTrashDays + " -delete 2>/dev/null"]
        _trashCleanProcess.running = true
    }

    property var _trashCleanProcess: Process {
        onExited: console.log("VideoConvertService: trash cleanup finished")
    }
}
