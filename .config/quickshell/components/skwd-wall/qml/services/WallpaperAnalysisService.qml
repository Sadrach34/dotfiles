pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: service

    readonly property string cacheDir: Config.cacheDir + "/wallpaper"
    readonly property string thumbsDir: cacheDir + "/thumbs"
    readonly property string weThumbsDir: cacheDir + "/we-thumbs"
    readonly property string videoThumbsDir: cacheDir + "/video-thumbs"
    readonly property string triggerFile: cacheDir + "/analysis-trigger"
    readonly property string lastRunFile: cacheDir + "/analysis-lastrun"
    readonly property string ollamaUrl: Config.ollamaUrl
    readonly property string ollamaModel: Config.ollamaModel

    property bool running: false
    property int progress: 0
    property int total: 0
    property int taggedCount: 0
    property int coloredCount: 0
    property int totalThumbs: 0
    property string lastLog: ""
    property string eta: ""

    signal analysisComplete()
    signal progressUpdated()
    signal itemAnalyzed(string key, var tags, var colors)

    property var colorsDb: ({})
    property var tagsDb: ({})

    readonly property string _prompt:
        "First line: dominant color from [red, orange, yellow, lime, green, teal, cyan, sky blue, blue, indigo, violet, pink, neutral] and saturation 0-100. Format: COLOR|NUMBER\n" +
        "Color tips: dark blue/navy=indigo, brown/sepia/earth=orange, purple=violet, light blue=sky blue. Use neutral ONLY for pure grayscale.\n" +
        "Second line: 8-12 comma-separated single-word tags for what you see.\n" +
        "Two lines only, nothing else."

    function start() {
        if (running || !ollamaUrl || !ollamaModel) return
        if (!Config.ollamaEnabled) return
        console.log("WallpaperAnalysis: starting scan, model:", ollamaModel, "url:", ollamaUrl)
        _reachCheck.command = ["sh", "-c",
            "curl -s -o /dev/null -w '%{http_code}' --max-time 3 '" + ollamaUrl + "/api/tags'"]
        _reachCheck.running = true
    }

    property string _reachStdout: ""
    property var _reachCheck: Process {
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => service._reachStdout += data
        }
        onExited: function(code, status) {
            var out = service._reachStdout.trim()
            service._reachStdout = ""
            if (code === 0 && out === "200") {
                service._loadDatabases()
            } else {
                service.lastLog = "Ollama not available, skipping analysis"
                console.log("WallpaperAnalysisService: Ollama not reachable at", ollamaUrl, "(HTTP", out + ", exit", code + ")")
            }
        }
    }

    function stop() {
        console.log("WallpaperAnalysis: stopped at", progress + "/" + total)
        running = false
        _workQueue = []
    }

    function regenerate() {
        colorsDb = {}
        tagsDb = {}
        DbService.exec("UPDATE meta SET tags=NULL,colors=NULL")
        _clearTrigger.running = true
    }

    function resetAll() {
        stop()
        _resetProcess.running = true
    }

    property var _clearTrigger: Process {
        command: ["rm", "-f", service.lastRunFile]
        onExited: service.start()
    }

    property var _resetProcess: Process {
        command: ["find", service.cacheDir, "-type", "f", "-delete"]
        onExited: {
            service.colorsDb = {}
            service.tagsDb = {}
            service.taggedCount = 0
            service.coloredCount = 0
            service.totalThumbs = 0
        }
    }

    function _loadDatabases() {
        if (Object.keys(colorsDb).length > 0 || Object.keys(tagsDb).length > 0) {
            console.log("WallpaperAnalysis: using in-memory databases:", Object.keys(colorsDb).length, "colors,", Object.keys(tagsDb).length, "tags")
            coloredCount = Object.keys(colorsDb).length
            taggedCount = Object.keys(tagsDb).length
            _collectThumbnails()
            return
        }
        var rows = DbService.query("SELECT key,tags,colors FROM meta WHERE analyzed_by=" + DbService.sqlStr(ollamaModel))
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            if (r.tags) try { tagsDb[r.key] = JSON.parse(r.tags) } catch(e) {}
            if (r.colors) try { colorsDb[r.key] = JSON.parse(r.colors) } catch(e) {}
        }
        console.log("WallpaperAnalysis: loaded", Object.keys(colorsDb).length, "colors,", Object.keys(tagsDb).length, "tags from db")
        coloredCount = Object.keys(colorsDb).length
        taggedCount = Object.keys(tagsDb).length
        _collectThumbnails()
    }

    property var _workQueue: []
    property int _workIndex: 0
    property double _startTime: 0
    property int _startProcessed: 0

    function _collectThumbnails() {
        _thumbStdout = []
        _thumbCollector.running = true
    }

    property var _thumbStdout: []

    property var _thumbCollector: Process {
        command: ["sh", "-c",
            "find " + DbService.shellQuote(service.thumbsDir) + " " +
            DbService.shellQuote(service.weThumbsDir) + " " +
            DbService.shellQuote(service.videoThumbsDir) +
            " -name '*.jpg' 2>/dev/null | sort"
        ]
        stdout: SplitParser {
            onRead: data => service._thumbStdout.push(data.trim())
        }
        onExited: service._buildQueue()
    }

    function _buildQueue() {
        var thumbs = _thumbStdout.filter(function(t) { return t.length > 0 })
        totalThumbs = thumbs.length

        var queue = []
        for (var i = 0; i < thumbs.length; i++) {
            var path = thumbs[i]
            var name = DbService.cacheKey(path)
            if (!colorsDb[name] || !tagsDb[name] || (tagsDb[name] && tagsDb[name].length === 0))
                queue.push({ path: path, name: name })
        }

        console.log("WallpaperAnalysis: buildQueue:", thumbs.length, "total thumbs,", queue.length, "need processing,", (thumbs.length - queue.length), "already cached")

        if (queue.length === 0) {
            lastLog = "All wallpapers analyzed"
            return
        }

        _workQueue = queue
        _workIndex = 0
        total = queue.length
        progress = 0
        running = true
        _startTime = Date.now() / 1000
        _startProcessed = 0
        eta = "starting..."

        _processNext()
    }

    function _processNext() {
        if (!running || _workIndex >= _workQueue.length) {
            _finishAnalysis()
            return
        }

        var item = _workQueue[_workIndex]
        lastLog = "[" + (_workIndex + 1) + "/" + total + "] " + item.name
        progressUpdated()

        _currentItem = item
        _encodeStdout = ""
        _encodeProcess.command = ["sh", "-c",
            ImageService.encodeBase64Cmd(DbService.shellQuote(item.path))
        ]
        _encodeProcess.running = true
    }

    property var _currentItem: null
    property string _encodeStdout: ""

    property var _encodeProcess: Process {
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => service._encodeStdout += data
        }
        onExited: function(code) {
            if (code !== 0) console.log("WallpaperAnalysis: base64 encode failed, exit", code)
            service._sendToOllama()
        }
    }

    property string _ollamaStdout: ""

    property var _ollamaProcess: Process {
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => service._ollamaStdout += data
        }
        onExited: function(code) {
            if (code === 0) {
                try {
                    var resp = JSON.parse(service._ollamaStdout.trim())
                    var text = (resp.response || "").trim()
                    console.log("WallpaperAnalysis: ollama response for", service._currentItem.name + ":", text.substring(0, 120))
                    service._parseOllamaResponse(text, service._currentItem)
                } catch(e) {
                    console.log("WallpaperAnalysis: ollama JSON parse error:", e, "raw:", service._ollamaStdout.substring(0, 200))
                    service._advanceQueue()
                }
            } else {
                console.log("WallpaperAnalysis: curl failed, exit", code, "stdout:", service._ollamaStdout.substring(0, 200))
                service.lastLog = "Ollama unavailable (curl exit " + code + ")"
                service.stop()
            }
        }
    }

    function _sendToOllama() {
        var b64 = _encodeStdout.trim()
        if (!b64) {
            console.log("WallpaperAnalysis: empty base64 for", _currentItem.name + ", skipping")
            _advanceQueue()
            return
        }
        console.log("WallpaperAnalysis: sending to ollama:", _currentItem.name, "(" + Math.round(b64.length / 1024) + "KB b64)")

        var payload = JSON.stringify({
            model: ollamaModel,
            prompt: _prompt,
            images: [b64],
            stream: false
        })

        _ollamaStdout = ""
        _ollamaProcess.command = ["sh", "-c",
            "curl -s --max-time 120 -X POST -H 'Content-Type: application/json' " +
            "-d " + DbService.shellQuote(payload) + " " +
            DbService.shellQuote(ollamaUrl + "/api/generate")
        ]
        _ollamaProcess.running = true
    }

    function _parseOllamaResponse(text, item) {
        var lines = text.split("\n").filter(function(l) { return l.trim().length > 0 })
        if (lines.length === 0) {
            console.log("WallpaperAnalysis: empty response for", item.name)
        }

        var hueBucket = 99
        var saturation = 0
        var tags = []
        var colorLine = null
        var tagLine = null

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.indexOf("|") !== -1 && colorLine === null) colorLine = line
            else if (line.indexOf(",") !== -1 && tagLine === null) tagLine = line
        }

        if (colorLine) {
            var parts = colorLine.split("|")
            var colorName = parts[0].trim().toLowerCase()
            try { saturation = parseInt(parts[1].trim()) } catch(e) { saturation = 50 }
            hueBucket = ColorMapping.colorToHue(colorName)
        }

        if (hueBucket === 99) {
            _pendingItem = item
            _pendingTags = tags
            _pendingSaturation = saturation
            _hueFallbackStdout = ""
            _hueFallbackProcess.command = ["sh", "-c",
                ImageService.hueExtractCmd(DbService.shellQuote(item.path))
            ]
            _hueFallbackProcess.running = true
            _needsFallbackResolution = true
        } else {
            _needsFallbackResolution = false
        }

        if (tagLine) {
            tags = tagLine.split(",").map(function(t) {
                return t.trim().toLowerCase().replace(/\.$/, "").trim()
            }).filter(function(t) {
                return t.length > 0 && t.length < 25 && t.indexOf(" ") === -1 && t.charAt(0) !== "-"
            }).slice(0, 20)

            tags = ColorMapping.mergeSynonyms(tags)
        }

        if (!_needsFallbackResolution) {
            saturation = Math.min(100, Math.max(0, saturation))
            colorsDb[item.name] = { hue: hueBucket, saturation: saturation }
            tagsDb[item.name] = tags
            _writeOneResult(item.name)
            coloredCount = Object.keys(colorsDb).length
            taggedCount = Object.keys(tagsDb).length
            itemAnalyzed(item.name, tags, colorsDb[item.name])
            _advanceQueue()
        } else {
            _pendingTags = tags
        }
    }

    property bool _needsFallbackResolution: false
    property var _pendingItem: null
    property var _pendingTags: []
    property int _pendingSaturation: 0
    property string _hueFallbackStdout: ""

    property var _hueFallbackProcess: Process {
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => service._hueFallbackStdout += data
        }
        onExited: service._applyFallback()
    }

    function _applyFallback() {
        var parts = _hueFallbackStdout.trim().split(/\s+/)
        var hue = parseFloat(parts[0]) || 0
        var sat = parseInt(parts[1]) || 0
        var bucket = ImageService.hueBucket(hue, sat)
        var saturation = (bucket !== 99) ? sat : _pendingSaturation
        saturation = Math.min(100, Math.max(0, saturation))

        colorsDb[_pendingItem.name] = { hue: bucket, saturation: saturation }
        tagsDb[_pendingItem.name] = _pendingTags
        _writeOneResult(_pendingItem.name)
        coloredCount = Object.keys(colorsDb).length
        taggedCount = Object.keys(tagsDb).length
        itemAnalyzed(_pendingItem.name, _pendingTags, colorsDb[_pendingItem.name])
        _advanceQueue()
    }

    function _advanceQueue() {
        progress++
        _workIndex++
        _startProcessed++

        var now = Date.now() / 1000
        var elapsed = now - _startTime
        if (elapsed > 8 && _startProcessed > 0) {
            var rate = _startProcessed / elapsed
            var remaining = total - progress
            if (remaining > 0) {
                var etaSec = remaining / rate
                if (etaSec < 60) eta = "~" + Math.round(etaSec) + "s"
                else if (etaSec < 3600) eta = "~" + Math.round(etaSec / 60) + "m"
                else {
                    var h = Math.floor(etaSec / 3600)
                    var m = Math.round((etaSec % 3600) / 60)
                    eta = "~" + h + "h" + m + "m"
                }
            } else {
                eta = "finishing..."
            }
        }

        progressUpdated()
        _processNext()
    }

    function _finishAnalysis() {
        running = false
        eta = ""
        lastLog = "Done! " + Object.keys(colorsDb).length + " colors, " + Object.keys(tagsDb).length + " tags"
        console.log("WallpaperAnalysis:", lastLog)
        analysisComplete()
    }

    function _writeOneResult(k) {
        var t = tagsDb[k] ? DbService.sqlStr(JSON.stringify(tagsDb[k])) : "NULL"
        var c = colorsDb[k] ? DbService.sqlStr(JSON.stringify(colorsDb[k])) : "NULL"
        var m = DbService.sqlStr(ollamaModel)
        DbService.exec(
            "INSERT INTO meta(key,tags,colors,analyzed_by) VALUES(" + DbService.sqlStr(k) + "," + t + "," + c + "," + m +
            ") ON CONFLICT(key) DO UPDATE SET tags=excluded.tags,colors=excluded.colors,analyzed_by=excluded.analyzed_by;")
    }
    
}
