pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: svc

    readonly property int maxJobs: 4

    readonly property var presets: ({
        "light":    { label: "Light",    quality: 82, formats: ["png", "jpg", "jpeg", "gif"] },
        "balanced": { label: "Balanced", quality: 88, formats: ["png", "jpg", "jpeg", "gif"] },
        "quality":  { label: "Quality",  quality: 94, formats: ["png", "jpg", "jpeg", "gif"] }
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

    signal finished(int optimized, int skippedCount, int failed)

    readonly property string _trashDir: Config.cacheDir + "/wallpaper/trash/images"
    readonly property string _stagingDir: Config.cacheDir + "/wallpaper/staging"

    property var _queue: []
    property int _activeJobs: 0
    property int _optimized: 0
    property int _failed: 0

    property var _scanStdout: []

    function optimize(presetKey, resolutionKey) {
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
        _optimized = 0
        _failed = 0
        _currentPreset = presetKey
        _currentPresetData = preset
        _currentResolution = res
        _scanImages()
    }

    function cancel() {
        if (!running) return
        _queue = []
    }

    property string _currentPreset: "balanced"
    property var _currentPresetData: presets["balanced"]
    property var _currentResolution: resolutions["2k"]

    function _scanImages() {
        _scanStdout = []
        var wallDir = DbService.shellQuote(Config.wallpaperDir)
        var findPattern = ImageService.findExtPattern(_currentPresetData.formats)

        var script = 'mkdir -p ' + DbService.shellQuote(_trashDir) + ' ' + DbService.shellQuote(_stagingDir) + '\n' +
            'find ' + wallDir + ' -type f ' + findPattern + ' 2>/dev/null'
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
        var rows = DbService.query("SELECT src,preset,format FROM image_optimize")
        var already = {}
        for (var i = 0; i < rows.length; i++)
            already[rows[i].src] = { preset: rows[i].preset, format: rows[i].format }

        var allFiles = _scanStdout.filter(function(l) { return l.trim() !== "" })
        var queue = []
        var skippedCount = 0

        for (var j = 0; j < allFiles.length; j++) {
            var src = allFiles[j].trim()
            if (!src) continue
            var rec = already[src]
            if (rec && rec.preset === _currentPreset && rec.format !== "skip") {
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
        var finalDest = src.replace(/\.[^.]*$/, ".webp")
        var isGif = /\.gif$/i.test(src)
        var srcName = src.split("/").pop()
        var destName = finalDest.split("/").pop()
        var stagingDest = svc._stagingDir + "/" + destName

        WatcherService.suppressFile(srcName)
        if (srcName !== destName)
            WatcherService.suppressFile(destName)

        var cmd =
            "src=" + DbService.shellQuote(src) + "\n" +
            "dest=" + DbService.shellQuote(stagingDest) + "\n" +
            "final_dest=" + DbService.shellQuote(finalDest) + "\n" +
            "trash=" + DbService.shellQuote(svc._trashDir) + "\n" +
            "orig_size=$(stat -c '%s' \"$src\" 2>/dev/null || echo 0)\n" +
            "trash_name=$(echo \"$src\" | md5sum | cut -c1-8)_$(basename \"$src\")\n" +
            "if [ -f \"$final_dest\" ] && [ \"$src\" != \"$final_dest\" ]; then\n" +
            "  mv \"$src\" \"$trash/$trash_name\"\n" +
            "  touch \"$trash/$trash_name\"\n" +
            "  dims=$(magick identify -limit memory 512MiB -limit map 1GiB -format '%w %h' \"$final_dest\" 2>/dev/null | head -1)\n" +
            "  width=${dims%% *}; height=${dims##* }\n" +
            "  dest_size=$(stat -c '%s' \"$final_dest\" 2>/dev/null || echo 0)\n" +
            "  echo \"OK:$orig_size:$dest_size:${width:-0}:${height:-0}\"\n" +
            "  exit 0\n" +
            "fi\n" +
            "rm -f \"$dest\" 2>/dev/null\n"

        if (isGif) {
            var maxW = svc._currentResolution.maxW
            var maxH = svc._currentResolution.maxH
            cmd +=
                "dims=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 \"$src\" 2>/dev/null)\n" +
                "width=${dims%%,*}; height=${dims##*,}\n" +
                "if [ -z \"$width\" ] || [ \"$width\" = \"0\" ]; then\n" +
                "  echo \"FAIL:$orig_size:0:0\"\n" +
                "  exit 0\n" +
                "fi\n" +
                "ffmpeg -y -i \"$src\" -vf \"scale=min'(" + maxW + ",iw)':min'(" + maxH + ",ih)':force_original_aspect_ratio=decrease\" " +
                "-c:v libwebp_anim -quality " + preset.quality + " -loop 0 -an \"$dest\" 2>/dev/null\n" +
                "rc=$?\n" +
                "if [ $rc -eq 0 ] && [ -f \"$dest\" ]; then\n" +
                "  new_size=$(stat -c '%s' \"$dest\" 2>/dev/null || echo 0)\n" +
                "  new_dims=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 \"$dest\" 2>/dev/null)\n" +
                "  new_width=${new_dims%%,*}; new_height=${new_dims##*,}\n" +
                "  mv \"$src\" \"$trash/$trash_name\"\n" +
                "  touch \"$trash/$trash_name\"\n" +
                "  mv \"$dest\" \"$final_dest\"\n" +
                "  echo \"OK:$orig_size:$new_size:${new_width:-0}:${new_height:-0}\"\n" +
                "else\n" +
                "  rm -f \"$dest\" 2>/dev/null\n" +
                "  echo \"FAIL:$orig_size:${width:-0}:${height:-0}\"\n" +
                "fi\n"
        } else {
            // Static image path
            cmd +=
                "dims=$(magick identify -limit memory 512MiB -limit map 1GiB -format '%w %h' \"$src\" 2>/dev/null | head -1)\n" +
                "width=${dims%% *}\n" +
                "height=${dims##* }\n" +
                "if [ -z \"$width\" ] || [ \"$width\" = \"0\" ]; then\n" +
                "  echo \"FAIL:$orig_size:0:0\"\n" +
                "  exit 0\n" +
                "fi\n" +
                "magick -limit memory 512MiB -limit map 1GiB \"$src\" -resize '" + svc._currentResolution.maxW + "x" + svc._currentResolution.maxH + ">' " +
                "-quality " + preset.quality + " \"$dest\" 2>/dev/null\n" +
                "rc=$?\n" +
                "if [ $rc -eq 0 ] && [ -f \"$dest\" ]; then\n" +
                "  new_size=$(stat -c '%s' \"$dest\" 2>/dev/null || echo 0)\n" +
                "  new_dims=$(magick identify -limit memory 512MiB -limit map 1GiB -format '%w %h' \"$dest\" 2>/dev/null | head -1)\n" +
                "  new_width=${new_dims%% *}\n" +
                "  new_height=${new_dims##* }\n" +
                "  mv \"$src\" \"$trash/$trash_name\"\n" +
                "  touch \"$trash/$trash_name\"\n" +
                "  mv \"$dest\" \"$final_dest\"\n" +
                "  echo \"OK:$orig_size:$new_size:$new_width:$new_height\"\n" +
                "else\n" +
                "  rm -f \"$dest\" 2>/dev/null\n" +
                "  echo \"FAIL:$orig_size:$width:$height\"\n" +
                "fi\n"
        }

        currentFile = src.split("/").pop()
        var proc = _workerComponent.createObject(svc, {
            command: ["sh", "-c", cmd],
            _src: src,
            _dest: finalDest,
            _srcName: srcName,
            _destName: destName
        })
        proc.running = true
    }

    property var _workerComponent: Component {
        Process {
            id: optimizeWorker
            property string _src
            property string _dest
            property string _srcName
            property string _destName
            property string _stdout: ""
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => optimizeWorker._stdout += data
            }
            onExited: {
                WatcherService.unsuppressFile(optimizeWorker._srcName)
                if (optimizeWorker._srcName !== optimizeWorker._destName)
                    WatcherService.unsuppressFile(optimizeWorker._destName)

                var output = optimizeWorker._stdout.trim()
                var lines = output.split("\n")
                var resultLine = lines[lines.length - 1] || ""

                if (resultLine.indexOf("OK:") === 0) {
                    var p = resultLine.split(":")
                    if (optimizeWorker._srcName !== optimizeWorker._destName)
                        WatcherService.notifyRenamed(optimizeWorker._srcName, optimizeWorker._destName)
                    svc._recordOptimization(optimizeWorker._src, optimizeWorker._dest, p)
                    svc._optimized++
                } else if (resultLine.indexOf("SKIP:") === 0) {
                    var sp = resultLine.split(":")
                    svc._recordSkip(optimizeWorker._src, sp)
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

    function _recordOptimization(src, dest, parts) {
        var origSize = parts[1] || "0"
        var newSize = parts[2] || "0"
        var newW = parts[3] || "0"
        var newH = parts[4] || "0"
        var now = Math.floor(Date.now() / 1000)
        DbService.exec(
            "INSERT INTO image_optimize(src,dest,preset,format,width,height,orig_size,new_size,optimized_at) VALUES(" +
            DbService.sqlStr(src) + "," + DbService.sqlStr(dest) + "," +
            DbService.sqlStr(_currentPreset) + ",'webp'," +
            newW + "," + newH + "," + origSize + "," + newSize + "," + now +
            ") ON CONFLICT(src) DO UPDATE SET dest=excluded.dest,preset=excluded.preset,format=excluded.format," +
            "width=excluded.width,height=excluded.height,orig_size=excluded.orig_size,new_size=excluded.new_size,optimized_at=excluded.optimized_at;")
        if (src !== dest) {
            var oldKey = DbService.cacheKey(src)
            var newKey = DbService.cacheKey(dest)
            DbService.exec(
                "UPDATE meta SET key=" + DbService.sqlStr(newKey) + "," +
                "name=" + DbService.sqlStr(dest.split("/").pop()) +
                " WHERE key=" + DbService.sqlStr(oldKey) + ";")
        }
    }

    function _recordSkip(src, parts) {
        var origSize = parts[1] || "0"
        var w = parts[2] || "0"
        var h = parts[3] || "0"
        var now = Math.floor(Date.now() / 1000)
        DbService.exec(
            "INSERT INTO image_optimize(src,dest,preset,format,width,height,orig_size,new_size,optimized_at) VALUES(" +
            DbService.sqlStr(src) + "," + DbService.sqlStr(src) + "," +
            DbService.sqlStr(_currentPreset) + ",'skip'," +
            w + "," + h + "," + origSize + "," + origSize + "," + now +
            ") ON CONFLICT(src) DO UPDATE SET preset=excluded.preset,optimized_at=excluded.optimized_at;")
    }

    function _finish() {
        currentFile = ""
        running = false
        finished(_optimized, skipped, _failed)
    }

    function cleanTrash() {
        if (!Config.autoDeleteImageTrash) return
        _trashCleanProcess.command = ["sh", "-c",
            "find " + DbService.shellQuote(_trashDir) + " -type f -mtime +" + Config.imageTrashDays + " -delete 2>/dev/null"]
        _trashCleanProcess.running = true
    }

    property var _trashCleanProcess: Process {
        onExited: console.log("ImageOptimizeService: trash cleanup finished")
    }
}
