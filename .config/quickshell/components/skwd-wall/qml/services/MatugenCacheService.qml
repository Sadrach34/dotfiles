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
    readonly property string wallpaperDir: Config.wallpaperDir
    readonly property int maxJobs: 4

    property bool running: false
    property int progress: 0
    property int total: 0

    signal cacheReady()
    signal oneReady(string key, var colors)

    property var _cache: ({})

    function processOne(path, key) {
        if (_cache[key]) return
        var proc = _workerComponent.createObject(service, {
            command: ["matugen", "image", path, "--dry-run", "--json", "hex", "--source-color-index", "0"],
            _item: { path: path, key: key, single: true }
        })
        proc.running = true
    }

    function removeOne(key) {
        delete _cache[key]
    }

    function rebuild() {
        if (running) return
        running = true
        progress = 0
        total = 0
        _unsavedKeys = []
        _loadCache()
    }

    function rebuildWithCache(existingCache) {
        if (running) return
        running = true
        progress = 0
        total = 0
        _unsavedKeys = []
        _cache = existingCache || {}
        _collectWallpapers()
    }

    property var _unsavedKeys: []

    function _loadCache() {
        _cache = {}
        var rows = DbService.query("SELECT key,matugen FROM meta WHERE matugen IS NOT NULL")
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].matugen) {
                try { _cache[rows[i].key] = JSON.parse(rows[i].matugen) } catch(e) {}
            }
        }
        _collectWallpapers()
    }

    property var _scanStdout: []

    function _collectWallpapers() {
        _scanStdout = []
        _scanProcess.running = true
    }

    property var _scanProcess: Process {
        command: ["sh", "-c", service._buildScanScript()]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line) service._scanStdout.push(line)
            }
        }
        onExited: service._buildQueue()
    }

    function _buildScanScript() {
        var wallDir = DbService.shellQuote(wallpaperDir)
        var thumbD = DbService.shellQuote(thumbsDir)
        var weThumbD = DbService.shellQuote(weThumbsDir)
        return 'find ' + wallDir + ' -type f ' + ImageService.findExtPattern(ImageService.imageExtensions.concat(["gif"])) + ' ! -name "wallpaper.jpg" 2>/dev/null | sort\n' +
            'find ' + weThumbD + ' -name "*.jpg" 2>/dev/null | sort\n' +
            'find ' + thumbD + ' -name "*.jpg" 2>/dev/null | sort\n'
    }

    property var _workQueue: []
    property int _workIndex: 0
    property int _activeJobs: 0

    function _buildQueue() {
        var files = _scanStdout
        var queue = []
        var seen = {}

        for (var i = 0; i < files.length; i++) {
            var path = files[i]
            var key = DbService.cacheKey(path)
            if (seen[key] || _cache[key]) continue
            seen[key] = true
            queue.push({ path: path, key: key })
        }

        if (queue.length === 0) {
            _finish()
            return
        }

        _workQueue = queue
        _workIndex = 0
        _activeJobs = 0
        total = queue.length
        progress = 0
        _startWorkers()
    }

    function _startWorkers() {
        while (_activeJobs < maxJobs && _workIndex < _workQueue.length) {
            _launchWorker(_workQueue[_workIndex])
            _workIndex++
            _activeJobs++
        }
        if (_activeJobs === 0 && _workIndex >= _workQueue.length)
            _finish()
    }

    function _launchWorker(item) {
        var proc = _workerComponent.createObject(service, {
            command: ["matugen", "image", item.path, "--dry-run", "--json", "hex", "--source-color-index", "0"],
            _item: item
        })
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
                service._processMatugenOutput(_stdout, _item)
                if (_item.single) {
                    service._saveCache()
                    if (service._cache[_item.key])
                        service.oneReady(_item.key, service._cache[_item.key])
                } else {
                    service.progress++
                    service._activeJobs--
                    if (service.progress % 50 === 0) service._saveCache()
                    service._startWorkers()
                }
                destroy()
            }
        }
    }

    function _processMatugenOutput(stdout, item) {
        if (!stdout.trim()) return
        try {
            var data = JSON.parse(stdout)
            var colors = data.colors || {}
            var extracted = {}

            for (var key in colors) {
                var parts = key.split("_")
                var camelKey = parts[0]
                for (var j = 1; j < parts.length; j++)
                    camelKey += parts[j].charAt(0).toUpperCase() + parts[j].substring(1)

                var value = colors[key]
                if (typeof value === "object" && value !== null) {
                    var dark = value.dark || value["default"] || "#888888"
                    if (typeof dark === "object") dark = dark.color || "#888888"
                    extracted[camelKey] = dark
                } else {
                    extracted[camelKey] = value
                }
            }

            if (Object.keys(extracted).length > 0) {
                _cache[item.key] = extracted
                _unsavedKeys.push(item.key)
            }
        } catch(e) {}
    }

    function _saveCache() {
        var keys = _unsavedKeys
        if (keys.length === 0) return
        _unsavedKeys = []
        var sqlArray = []
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            sqlArray.push("INSERT INTO meta(key,matugen) VALUES(" + DbService.sqlStr(k) + "," + DbService.sqlStr(JSON.stringify(_cache[k])) + ") ON CONFLICT(key) DO UPDATE SET matugen=excluded.matugen;")
        }
        DbService.execBatch(sqlArray)
    }

    function _finish() {
        _saveCache()
        running = false
        cacheReady()
    }

}
