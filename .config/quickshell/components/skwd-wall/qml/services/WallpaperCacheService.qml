pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: service

    readonly property string wallpaperDir: Config.wallpaperDir
    readonly property string videoDir: Config.videoDir
    readonly property string weDir: Config.weDir
    readonly property bool steamEnabled: Config.steamEnabled
    readonly property string cacheDir: Config.cacheDir
    readonly property string thumbsDir: cacheDir + "/wallpaper/thumbs"
    readonly property string thumbsSmDir: cacheDir + "/wallpaper/thumbs-sm"
    readonly property string weCacheDir: cacheDir + "/wallpaper/we-thumbs"
    readonly property string videoCacheDir: cacheDir + "/wallpaper/video-thumbs"
    readonly property int maxJobs: 4

    property bool running: false
    property int progress: 0
    property int total: 0
    property string status: ""

    signal cacheReady(string result)
    signal fileProcessed(string key, var entry)
    signal fileRemoved(string key)

    property int incrementalPending: 0
    property var _incrementalQueue: []
    property int _incrementalActive: 0
    property var _deferredFiles: []

    property var _passedWallpaperData: null

    function rebuild(wallpaperData) {
        if (running) return
        _passedWallpaperData = wallpaperData || null
        running = true
        progress = 0
        total = 0
        status = ""
        _mkdirs.running = true
    }

    function processFiles(files) {
        if (!files || files.length === 0) return
        if (running) {
            _deferredFiles = _deferredFiles.concat(files)
            return
        }
        for (var i = 0; i < files.length; i++) {
            var f = files[i]
            var thumbName = f.name.replace(/\//g, "--").replace(/\.[^.]*$/, ".jpg")
            var thumbDir = f.type === "video" ? videoCacheDir : thumbsDir
            var item = {
                type: f.type, src: f.src, name: f.name,
                mtime: "0", thumbPath: thumbDir + "/" + thumbName, title: ""
            }
            _launchIncrementalWorker(item)
        }
    }

    function processWeItem(weId, weItemDir) {
        if (!steamEnabled) return
        var dir = weItemDir.replace(/\/$/, "")
        var cmd = "cd " + DbService.shellQuote(dir) + " && " +
            "title=$(jq -r '.title // \"Unknown\"' project.json 2>/dev/null || echo Unknown); " +
            "preview=''; for p in preview.jpg preview.png preview.gif; do [ -f \"$p\" ] && preview=\"$p\" && break; done; " +
            "echo \"$title\"; echo \"$preview\""
        var proc = _weProbeComponent.createObject(service, {
            command: ["sh", "-c", cmd],
            _weId: weId,
            _weDir: dir
        })
        proc.running = true
    }

    property var _weProbeComponent: Component {
        Process {
            id: weProbe
            property string _weId
            property string _weDir
            property string _stdout: ""
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => weProbe._stdout += data
            }
            onExited: {
                var lines = weProbe._stdout.trim().split("\n")
                var title = lines[0] || "Unknown"
                var preview = lines[1] || ""
                if (!preview) { destroy(); return }
                var src = weProbe._weDir + "/" + preview
                var item = {
                    type: "we", src: src, name: weProbe._weId,
                    mtime: "0", thumbPath: service.weCacheDir + "/" + weProbe._weId + ".jpg",
                    title: title
                }
                service._launchIncrementalWorker(item)
                destroy()
            }
        }
    }

    function removeFiles(files) {
        if (!files || files.length === 0) return
        var keys = []
        for (var i = 0; i < files.length; i++) {
            var f = files[i]
            var dot = f.name.lastIndexOf(".")
            var key = dot > 0 ? f.name.substring(0, dot) : f.name
            keys.push(key)
        }
        DbService.exec("DELETE FROM meta WHERE key IN (" +
            keys.map(function(k) { return DbService.sqlStr(k) }).join(",") + ");")
        for (var j = 0; j < keys.length; j++) {
            fileRemoved(keys[j])
        }
    }

    function _launchIncrementalWorker(item) {
        incrementalPending++
        _incrementalQueue.push(item)
        _drainIncrementalQueue()
    }

    function _drainIncrementalQueue() {
        while (_incrementalActive < maxJobs && _incrementalQueue.length > 0) {
            var item = _incrementalQueue.shift()
            _incrementalActive++
            var cmd = _buildIncrementalCmd(item)
            var proc = _incrementalWorkerComponent.createObject(service, { command: cmd, _item: item })
            proc.running = true
        }
    }

    function _buildIncrementalCmd(item) {
        var src = DbService.shellQuote(item.src)
        var thumb = DbService.shellQuote(item.thumbPath)
        var thumbSmPath = ImageService.smallThumbPath(item.thumbPath)
        var thumbSm = DbService.shellQuote(thumbSmPath)

        var statCmd = "stat -c '%Y' " + src + " 2>/dev/null || echo 0"
        var thumbCmd
        if (item.type === "static") {
            thumbCmd = ImageService.thumbnailCmd(src, thumb) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.thumbnailCmd(thumb, thumbSm, ImageService.smallThumbWidth, ImageService.smallThumbHeight, ImageService.smallThumbQuality) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.hueExtractCmd(thumb)
        } else if (item.type === "we") {
            var weD = DbService.shellQuote(item.src.replace(/\/preview\.[^/]+$/, ""))
            thumbCmd =
                "we_dir=" + weD + "; " +
                "video_file=$(find \"$we_dir\" -maxdepth 1 \\( -iname '*.mp4' -o -iname '*.webm' \\) ! -iname 'preview.*' -print -quit 2>/dev/null); " +
                "if [ -n \"$video_file\" ]; then " +
                "  " + ImageService.videoThumbnailCmd('"$video_file"', thumb, 2) + "; " +
                "fi; " +
                "[ ! -f " + thumb + " ] || [ ! -s " + thumb + " ] && " +
                ImageService.thumbnailCmd(src, thumb) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.thumbnailCmd(thumb, thumbSm, ImageService.smallThumbWidth, ImageService.smallThumbHeight, ImageService.smallThumbQuality) + "; " +
                "echo \"VIDEOFILE:$video_file\"; " +
                "[ -f " + thumb + " ] && " + ImageService.hueExtractCmd(thumb)
        } else {
            thumbCmd = ImageService.videoThumbnailCmd(src, thumb, 0) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.thumbnailCmd(thumb, thumbSm, ImageService.smallThumbWidth, ImageService.smallThumbHeight, ImageService.smallThumbQuality) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.hueExtractCmd(thumb)
        }
        return ["sh", "-c", statCmd + "; " + thumbCmd]
    }

    property var _incrementalWorkerComponent: Component {
        Process {
            id: incWorker
            property var _item
            property string _stdout: ""
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => incWorker._stdout += data
            }
            onExited: (code, status) => {
                service.incrementalPending--
                service._incrementalActive--
                var lines = incWorker._stdout.trim().split("\n")
                var mtime = parseInt(lines[0]) || 0
                var hueSat = lines.length > 1 ? lines[lines.length - 1].trim() : "0 0"
                incWorker._item.mtime = String(mtime)
                var result = service._parseWorkerOutput(hueSat, incWorker._item)
                if (result) {
                    result.mtime = mtime
                    service._writeOneResult(result)
                    var key = DbService.cacheKey(result.thumb)
                    service.fileProcessed(key, result)
                } else {
                }
                service._drainIncrementalQueue()
                destroy()
            }
        }
    }

    property var _mkdirs: Process {
        command: ["mkdir", "-p", service.thumbsDir, service.thumbsSmDir, service.weCacheDir, service.videoCacheDir]
        onExited: service._scanFiles()
    }
    
    property var _scanStdout: []

    function _scanFiles() {
        _scanStdout = []
        _scanProcess.command = ["sh", "-c", _buildScanScript()]
        _scanProcess.running = true
    }

    property var _scanProcess: Process {
        stdout: SplitParser {
            onRead: data => service._scanStdout.push(data)
        }
        onExited: service._processScanResult()
    }

    function _buildScanScript() {
        var wallDir = DbService.shellQuote(wallpaperDir)
        var vidDir = DbService.shellQuote(videoDir)
        var weD = (steamEnabled && weDir) ? DbService.shellQuote(weDir) : ""
        var thumbD = DbService.shellQuote(thumbsDir)
        var weCache = DbService.shellQuote(weCacheDir)
        var vidCache = DbService.shellQuote(videoCacheDir)

        return 'set -e\n' +
            'wall_dir=' + wallDir + '\n' +
            'vid_dir=' + vidDir + '\n' +
            'we_dir=' + (weD || '""') + '\n' +
            'thumb_dir=' + thumbD + '\n' +
            'we_cache=' + weCache + '\n' +
            'vid_cache=' + vidCache + '\n' +
            'mkdir -p "$vid_dir"\n' +
            'find "$wall_dir" -type f ' + ImageService.findExtPattern(ImageService.imageExtensions) + ' ! -name "wallpaper.jpg" -print0 2>/dev/null | sort -z | while IFS= read -r -d "" img; do\n' +
            '  name="${img#$wall_dir/}"\n' +
            '  mtime=$(stat -c "%Y" "$img" 2>/dev/null || echo 0)\n' +
            '  thumb_name=$(echo "$name" | sed "s|/|--|g" | sed "s|\\.[^.]*$|.jpg|")\n' +
            '  echo "static\t$img\t$name\t$mtime\t$thumb_dir/$thumb_name"\n' +
            'done\n' +
            'find "$vid_dir" -type f ' + ImageService.findExtPattern(ImageService.videoExtensions) + ' -print0 2>/dev/null | sort -z | while IFS= read -r -d "" vid; do\n' +
            '  name="${vid#$vid_dir/}"\n' +
            '  mtime=$(stat -c "%Y" "$vid" 2>/dev/null || echo 0)\n' +
            '  thumb_name=$(echo "$name" | sed "s|/|--|g" | sed "s|\\.[^.]*$|.jpg|")\n' +
            '  echo "video\t$vid\t$name\t$mtime\t$vid_cache/$thumb_name"\n' +
            'done\n' +
            'if [ -n "$we_dir" ] && [ -d "$we_dir" ]; then\n' +
            '  for d in "$we_dir"/*/; do\n' +
            '    [ -d "$d" ] || continue\n' +
            '    id=$(basename "$d")\n' +
            '    mtime=$(stat -c "%Y" "$d" 2>/dev/null || echo 0)\n' +
            '    preview=""\n' +
            '    for p in "${d}preview.jpg" "${d}preview.png" "${d}preview.gif"; do [ -f "$p" ] && preview="$p" && break; done\n' +
            '    [ -z "$preview" ] && continue\n' +
            '    title=$(jq -r ".title // \\"Unknown\\"" "$d/project.json" 2>/dev/null)\n' +
            '    echo "we\t$preview\t$id\t$mtime\t$we_cache/$id.jpg\t$title"\n' +
            '  done\n' +
            'fi\n'
    }

    function _processScanResult() {
        if (_scanStdout.length === 0) { _finish("cached"); return }
        var lines = _scanStdout.join("\n").split("\n").filter(function(l) { return l.trim() !== "" })

        var workItems = []
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("\t")
            if (parts.length >= 5) {
                workItems.push({
                    type: parts[0], src: parts[1], name: parts[2],
                    mtime: parts[3], thumbPath: parts[4],
                    title: parts[5] || ""
                })
            }
        }

        if (workItems.length === 0) { _finish("cached"); return }

        _existingCache = {}
        _pendingWorkItems = workItems

        if (_passedWallpaperData && _passedWallpaperData.length > 0) {
            for (var j = 0; j < _passedWallpaperData.length; j++) {
                var w = _passedWallpaperData[j]
                var ck = w.type + ":" + (w.weId || w.name)
                var key = w.weId || DbService.cacheKey(w.thumb)
                _existingCache[ck] = { key: key, mtime: w.mtime }
            }
            _passedWallpaperData = null
            _filterWorkItems()
        } else {
            _passedWallpaperData = null
            var rows = DbService.query("SELECT key,type,name,thumb,thumb_sm,video_file,we_id,mtime,hue,sat FROM meta WHERE type IS NOT NULL")
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var cacheKey = row.type + ":" + (row.we_id || row.name)
                _existingCache[cacheKey] = {
                    key: row.key, type: row.type, name: row.name, thumb: row.thumb,
                    thumbSm: row.thumb_sm || "", videoFile: row.video_file || "",
                    id: row.we_id || "", mtime: row.mtime || 0,
                    group: row.hue, sat: row.sat || 0
                }
            }
            _filterWorkItems()
        }
    }

    property var _pendingWorkItems: []

    function _filterWorkItems() {
        var workItems = _pendingWorkItems
        _pendingWorkItems = []

        _workQueue = []
        total = workItems.length
        progress = 0

        var seenKeys = {}
        var unchanged = 0
        for (var k = 0; k < workItems.length; k++) {
            var item = workItems[k]
            var cacheKey = item.type + ":" + item.name
            seenKeys[cacheKey] = true
            var cached = _existingCache[cacheKey]
            if (cached && String(cached.mtime) === String(item.mtime)) {
                progress++
                unchanged++
            } else {
                _workQueue.push(item)
            }
        }

        var staleKeys = []
        for (var ek in _existingCache) {
            if (!seenKeys[ek]) staleKeys.push(_existingCache[ek].key)
        }
        if (staleKeys.length > 0) {
            DbService.exec("DELETE FROM meta WHERE key IN (" +
                staleKeys.map(function(k) { return DbService.sqlStr(k) }).join(",") + ");")
        }

        if (_workQueue.length === 0) {
            _finish("cached")
            return
        }

        _activeJobs = 0
        _workIndex = 0
        _startWorkers()
    }

    property var _existingCache: ({})
    property var _workQueue: []
    property int _activeJobs: 0
    property int _workIndex: 0

    function _startWorkers() {
        while (_activeJobs < maxJobs && _workIndex < _workQueue.length) {
            _launchWorker(_workQueue[_workIndex])
            _workIndex++
            _activeJobs++
        }
        if (_activeJobs === 0 && _workIndex >= _workQueue.length) {
            _finish("regenerated")
        }
    }

    function _launchWorker(item) {
        var cmd = _buildItemCmd(item)
        var proc = _workerComponent.createObject(service, { command: cmd, _item: item })
        proc.running = true
    }

    property var _workerComponent: Component {
        Process {
            id: workerProc
            property var _item
            property string _stdout: ""
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => workerProc._stdout += data
            }
            onExited: {
                var result = service._parseWorkerOutput(_stdout.trim(), _item)
                if (result) service._writeOneResult(result)
                service.progress++
                service._activeJobs--
                service._startWorkers()
                destroy()
            }
        }
    }

    function _buildItemCmd(item) {
        if (!item.src || item.src === "-" || item.src.indexOf("/") !== 0) {
            return ["sh", "-c", "echo '0 0'"]
        }
        var src = DbService.shellQuote(item.src)
        var thumb = DbService.shellQuote(item.thumbPath)
        var thumbSmPath = ImageService.smallThumbPath(item.thumbPath)
        var thumbSm = DbService.shellQuote(thumbSmPath)

        if (item.type === "static") {
            return ["sh", "-c",
                ImageService.thumbnailCmd(src, thumb) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.thumbnailCmd(thumb, thumbSm, ImageService.smallThumbWidth, ImageService.smallThumbHeight, ImageService.smallThumbQuality) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.hueExtractCmd(thumb)]
        } else if (item.type === "video") {
            return ["sh", "-c",
                ImageService.videoThumbnailCmd(src, thumb, 0) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.thumbnailCmd(thumb, thumbSm, ImageService.smallThumbWidth, ImageService.smallThumbHeight, ImageService.smallThumbQuality) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.hueExtractCmd(thumb)]
        } else if (item.type === "we") {
            var weD = DbService.shellQuote(item.src.replace(/\/preview\.[^/]+$/, ""))
            return ["sh", "-c",
                "we_dir=" + weD + "; " +
                "video_file=$(find \"$we_dir\" -maxdepth 1 \\( -iname '*.mp4' -o -iname '*.webm' \\) ! -iname 'preview.*' -print -quit 2>/dev/null); " +
                "if [ -n \"$video_file\" ]; then " +
                "  " + ImageService.videoThumbnailCmd('"$video_file"', thumb, 2) + "; " +
                "fi; " +
                "[ ! -f " + thumb + " ] || [ ! -s " + thumb + " ] && " +
                ImageService.thumbnailCmd(src, thumb) + "; " +
                "[ -f " + thumb + " ] && " + ImageService.thumbnailCmd(thumb, thumbSm, ImageService.smallThumbWidth, ImageService.smallThumbHeight, ImageService.smallThumbQuality) + "; " +
                "echo \"VIDEOFILE:$video_file\"; " +
                "[ -f " + thumb + " ] && " + ImageService.hueExtractCmd(thumb)]
        }
        return ["true"]
    }

    function _parseWorkerOutput(stdout, item) {
        var lines = stdout.trim().split("\n")
        var hueLine = lines[lines.length - 1].trim()
        var parts = hueLine.split(/\s+/)
        var hue = parseFloat(parts[0]) || 0
        var sat = parseInt(parts[1]) || 0
        var group = ImageService.hueBucket(hue, sat)

        var thumbSmPath = ImageService.smallThumbPath(item.thumbPath)

        var entry = {
            group: group, sat: sat, mtime: parseInt(item.mtime) || 0,
            type: item.type, name: item.name, thumb: item.thumbPath,
            thumbSm: thumbSmPath
        }

        if (item.type === "we") {
            entry.id = item.name
            entry.name = item.title || item.name
            var videoLine = stdout.split("\n").find(function(l) { return l.indexOf("VIDEOFILE:") === 0 })
            entry.videoFile = videoLine ? videoLine.substring(10).trim() : ""
        } else {
            entry.id = ""
            entry.videoFile = (item.type === "video") ? item.src : ""
        }
        return entry
    }

    function _writeOneResult(e) {
        var key = DbService.cacheKey(e.thumb)
        DbService.exec(
            "INSERT INTO meta(key,type,name,thumb,thumb_sm,video_file,we_id,mtime,hue,sat) VALUES(" +
            DbService.sqlStr(key) + "," + DbService.sqlStr(e.type) + "," + DbService.sqlStr(e.name) + "," +
            DbService.sqlStr(e.thumb) + "," + DbService.sqlStr(e.thumbSm || "") + "," +
            DbService.sqlStr(e.videoFile || "") + "," + DbService.sqlStr(e.id || "") + "," +
            (parseInt(e.mtime) || 0) + "," + (e.group != null ? parseInt(e.group) : 99) + "," + (parseInt(e.sat) || 0) +
            ") ON CONFLICT(key) DO UPDATE SET type=excluded.type,name=excluded.name,thumb=excluded.thumb,thumb_sm=excluded.thumb_sm,video_file=excluded.video_file,we_id=excluded.we_id,mtime=excluded.mtime,hue=excluded.hue,sat=excluded.sat;")
    }

    function _finish(result) {
        status = result
        running = false
        DbService.exec("INSERT OR REPLACE INTO state(key,val) VALUES('last_rebuild','" + Date.now() + "')")
        cacheReady(result)
        if (_deferredFiles.length > 0) {
            var deferred = _deferredFiles
            _deferredFiles = []
            processFiles(deferred)
        }
    }
}
