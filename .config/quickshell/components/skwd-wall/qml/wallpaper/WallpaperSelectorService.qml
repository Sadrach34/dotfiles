import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../services"

QtObject {
  id: service


  required property string scriptsDir
  required property string homeDir
  required property string wallpaperDir
  required property string videoDir
  required property string cacheBaseDir
  required property string weDir
  required property string weAssetsDir
  required property bool showing

  readonly property string clockPositionsFile: homeDir + "/.config/quickshell/components/ModernClockWidget/positions.json"

  property string thumbsCacheDir: cacheBaseDir + "/wallpaper/thumbs"
  property string weCache: cacheBaseDir + "/wallpaper/we-thumbs"

  property bool cacheReady: false
  property string cacheResult: ""
  property int cacheProgress: 0
  property int cacheTotal: 0
  property bool cacheLoading: false

  property int selectedColorFilter: -1
  property string selectedTypeFilter: ""
  property string sortMode: "color"
  property var selectedTags: []
  property int selectedTagIndex: -1
  property var popularTags: []

  property var tagsDb: ({})
  property var colorsDb: ({})
  property var matugenDb: ({})
  property var favouritesDb: ({})
  property bool favouriteFilterActive: false
  property bool _favouritesLoaded: false
  property bool _matugenRebuildPending: false
  property bool _uiRebuildTriggered: false
  property bool _clockSyncQueued: false
  property string _clockSyncKeysJson: "[]"

  property string _postListLoadAction: ""
  property bool _countReconcileInProgress: false
  property string _countScanOutput: ""

  function _loadListFile() {
    var rows = DbService.query("SELECT type,name,thumb,video_file,we_id,mtime,hue,sat FROM meta WHERE type IS NOT NULL")
    var items = []
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      var type = r.type, name = r.name, thumb = r.thumb
      var videoFile = r.video_file || "", weId = r.we_id || ""
      var mtime = r.mtime || 0, hue = r.hue, sat = r.sat || 0
      items.push({
        name: name, type: type, thumb: thumb,
        path: type === "static" ? service.wallpaperDir + "/" + name : (type === "video" ? service.videoDir + "/" + name : ""),
        weId: weId, videoFile: videoFile,
        mtime: mtime, hue: hue, saturation: sat
      })
    }
    if (items.length > 0) {
      _wallpaperData = items
      _syncClockPositionsFromWallpaperData()
    }
    if (_postListLoadAction === "quickstart") {
      _postListLoadAction = ""
      if (_wallpaperData.length > 0) {
        cacheReady = true
        cacheLoading = false
        cacheResult = "cached"
        _runCountReconcile()
        _deferredStartTimer.restart()
      } else {
        cacheLoading = true
        _daemonWaitTimer.restart()
      }
      return false
    }
    if (_postListLoadAction === "regenerated") {
      _postListLoadAction = ""
      _matugenRebuildPending = Config.matugenEnabled
      reloadMetadata()
    } else {
      _postListLoadAction = ""
      _deferredStartTimer.restart()
    }
    return false
  }

  function _syncClockPositionsFromWallpaperData() {
    if (!_wallpaperData || _wallpaperData.length === 0) return

    var unique = {}
    var keys = []
    for (var i = 0; i < _wallpaperData.length; i++) {
      var item = _wallpaperData[i]
      if (!item || !item.name) continue
      var file = String(item.name)
      var stem = file.replace(/\.(jpg|jpeg|png|webp|gif|mp4|mkv|mov|webm|avi)$/i, "")
      if (stem && !unique[stem]) {
        unique[stem] = true
        keys.push(stem)
      }
    }

    if (keys.length === 0) return

    _clockSyncKeysJson = JSON.stringify(keys)
    if (_clockSyncProc.running) {
      _clockSyncQueued = true
      return
    }
    _clockSyncProc.running = true
  }

  // Public utility: remove position entries for wallpapers that no longer exist.
  function pruneMissingClockPositions() {
    _syncClockPositionsFromWallpaperData()
  }

  function reloadMetadata() {
    var rows = DbService.query("SELECT key,tags,colors,matugen,favourite FROM meta")
    var newTags = {}, newColors = {}, newMatugen = {}, newFavs = {}
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (r.tags) try { newTags[r.key] = JSON.parse(r.tags) } catch(e) {}
      if (r.colors) try { newColors[r.key] = JSON.parse(r.colors) } catch(e) {}
      if (r.matugen) try { newMatugen[r.key] = JSON.parse(r.matugen) } catch(e) {}
      if (r.favourite === 1) newFavs[r.key] = true
    }
    tagsDb = newTags
    colorsDb = newColors
    matugenDb = newMatugen
    if (!_favouritesLoaded) {
      favouritesDb = newFavs
      _favouritesLoaded = true
    }
    _rebuildPopularTags()
    updateFilteredModel()
    if (_matugenRebuildPending) {
      _matugenRebuildPending = false
      MatugenCacheService.rebuildWithCache(matugenDb)
    }
  }

  function refreshFromDb() {
    _postListLoadAction = "start"
    _loadListFile()
  }

  function isFavourite(name, weId) {
    var key = weId ? weId : name
    return !!favouritesDb[key]
  }

  function toggleFavourite(name, weId) {
    var key = weId ? weId : name
    var db = JSON.parse(JSON.stringify(favouritesDb))
    if (db[key]) {
      delete db[key]
    } else {
      db[key] = true
    }
    favouritesDb = db
    _saveFavToDb(key, !!db[key])
    if (favouriteFilterActive) updateFilteredModel()
  }

  function getWallpaperTags(name, weId) {
    if (weId) return tagsDb[weId] || []
    var dot = name.lastIndexOf(".")
    var key = dot > 0 ? name.substring(0, dot) : name
    return tagsDb[key] || []
  }

  function setWallpaperTags(name, weId, tags) {
    var key = weId ? weId : (function() { var d = name.lastIndexOf("."); return d > 0 ? name.substring(0, d) : name }())
    var db = JSON.parse(JSON.stringify(tagsDb))
    db[key] = tags
    tagsDb = db
    _rebuildPopularTags()
    _saveTagToDb(key, tags)
    if (selectedTags.length > 0) updateFilteredModel()
  }

  function _rebuildPopularTags() {
    var tagCounts = {}
    for (var name in tagsDb) {
      var tags = tagsDb[name]
      for (var i = 0; i < tags.length; i++) {
        tagCounts[tags[i]] = (tagCounts[tags[i]] || 0) + 1
      }
    }
    var tagArray = []
    for (var t in tagCounts) tagArray.push({tag: t, count: tagCounts[t]})
    tagArray.sort(function(a, b) { return b.count - a.count })
    popularTags = tagArray
  }

  function _saveTagToDb(key, tags) {
    DbService.exec("INSERT INTO meta(key,tags) VALUES(" + DbService.sqlStr(key) + "," + DbService.sqlStr(JSON.stringify(tags)) + ") ON CONFLICT(key) DO UPDATE SET tags=excluded.tags;")
  }

  function _saveFavToDb(key, isFav) {
    DbService.exec("INSERT INTO meta(key,favourite) VALUES(" + DbService.sqlStr(key) + "," + (isFav ? "1" : "0") + ") ON CONFLICT(key) DO UPDATE SET favourite=excluded.favourite;")
  }

  onFavouriteFilterActiveChanged: _debouncedUpdate.restart()

  property bool ollamaTaggingActive: false
  property bool ollamaColorsActive: false
  property bool ollamaActive: ollamaTaggingActive || ollamaColorsActive
  property int ollamaTotalThumbs: 0
  property int ollamaTaggedCount: 0
  property int ollamaColoredCount: 0
  property string ollamaEta: ""
  property string ollamaLogLine: ""

  property var _wallpaperData: []
  property var filteredModel: ListModel {}

  signal modelUpdated()
  signal wallpaperApplied()

  function updateFilteredModel(skipCrossfade) {
    _skipCrossfade = !!skipCrossfade

    var items = []
    for (var i = 0; i < _wallpaperData.length; i++) {
      var item = _wallpaperData[i]
      var lookupKey = item.weId ? item.weId : ImageService.thumbKey(item.thumb)
      var ollamaColor = colorsDb[lookupKey]
      var useOllama = Config.colorSource === "ollama" && ollamaColor
      var hue = useOllama ? ollamaColor.hue : item.hue
      var saturation = useOllama ? (ollamaColor.saturation || 0) : (item.saturation || 0)
      var effectiveType = (item.type === "we" && item.videoFile) ? "video" : item.type
      if (selectedTypeFilter !== "" && effectiveType !== selectedTypeFilter) continue
      if (selectedColorFilter !== -1 && hue !== selectedColorFilter) continue
      if (favouriteFilterActive && !isFavourite(item.name, item.weId)) continue

      if (selectedTags.length > 0) {
        var wallpaperTags = tagsDb[lookupKey]
        if (!wallpaperTags) continue
        var allTagsMatch = true
        for (var t = 0; t < selectedTags.length; t++) {
          if (wallpaperTags.indexOf(selectedTags[t]) === -1) { allTagsMatch = false; break }
        }
        if (!allTagsMatch) continue
      }

      items.push({
        name: item.name, type: item.type, thumb: item.thumb, path: item.path,
        weId: item.weId, videoFile: item.videoFile, mtime: item.mtime,
        hue: hue, saturation: saturation
      })
    }

    if (sortMode === "date") {
      items.sort(function(a, b) { return b.mtime - a.mtime })
    } else {
      items.sort(function(a, b) {
        var hueA = a.hue === 99 ? 100 : a.hue
        var hueB = b.hue === 99 ? 100 : b.hue
        if (hueA !== hueB) return hueA - hueB
        return b.saturation - a.saturation
      })
    }

    _pendingItems = items
    requestFilterUpdate()
  }

  signal requestFilterUpdate()
  property var _pendingItems: []
  property bool filterTransitioning: false
  property bool _skipCrossfade: false

  function commitFilteredModel() {
    filteredModel.clear()
    if (_pendingItems.length > 0) filteredModel.append(_pendingItems)
    _pendingItems = []
    modelUpdated()
  }

  onSelectedColorFilterChanged: _debouncedUpdate.restart()

  property var _debouncedUpdate: Timer {
    interval: 0
    onTriggered: service.updateFilteredModel()
  }
  onSelectedTypeFilterChanged: updateFilteredModel()

  function startCacheCheck() {
    ollamaTaggingActive = false
    ollamaColorsActive = false
    ollamaEta = ""
    ollamaLogLine = ""
    cacheResult = ""
    cacheProgress = 0
    cacheTotal = 0
    _uiRebuildTriggered = false
    _postListLoadAction = "quickstart"
    _loadListFile()
  }

  function reloadDatabaseNow() {
    if (WallpaperCacheService.running) return
    cacheReady = false
    cacheLoading = true
    cacheResult = ""
    _uiRebuildTriggered = false
    _postListLoadAction = "regenerated"
    WallpaperCacheService.rebuild(_wallpaperData)
  }

  function _buildCountScanScript() {
    var wallDir = DbService.shellQuote(wallpaperDir)
    var vidDir = DbService.shellQuote(videoDir)
    var weD = (Config.steamEnabled && weDir) ? DbService.shellQuote(weDir) : ""
    return 'wall_dir=' + wallDir + '\n' +
      'vid_dir=' + vidDir + '\n' +
      'we_dir=' + (weD || '""') + '\n' +
      'img_count=$(find "$wall_dir" -type f ' + ImageService.findExtPattern(ImageService.imageExtensions) + ' ! -name "wallpaper.jpg" 2>/dev/null | wc -l)\n' +
      'vid_count=$(find "$vid_dir" -type f ' + ImageService.findExtPattern(ImageService.videoExtensions) + ' 2>/dev/null | wc -l)\n' +
      'we_count=0\n' +
      'if [ -n "$we_dir" ] && [ -d "$we_dir" ]; then\n' +
      '  for d in "$we_dir"/*/; do\n' +
      '    [ -d "$d" ] || continue\n' +
      '    for p in "${d}preview.jpg" "${d}preview.png" "${d}preview.gif"; do\n' +
      '      if [ -f "$p" ]; then we_count=$((we_count + 1)); break; fi\n' +
      '    done\n' +
      '  done\n' +
      'fi\n' +
      'echo $((img_count + vid_count + we_count))\n'
  }

  function _runCountReconcile() {
    if (_countReconcileInProgress || WallpaperCacheService.running) return
    _countReconcileInProgress = true
    _countScanOutput = ""
    _countScanProc.command = ["sh", "-c", _buildCountScanScript()]
    _countScanProc.running = true
  }

  property var _deferredStartTimer: Timer {
    interval: 0
    onTriggered: service.reloadMetadata()
  }

  property var _countScanProc: Process {
    command: ["sh", "-c", "echo 0"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => { service._countScanOutput += data }
    }
    onExited: {
      service._countReconcileInProgress = false
      var expected = parseInt((service._countScanOutput || "").trim())
      if (isNaN(expected) || expected < 0) return
      if (expected !== service._wallpaperData.length && !WallpaperCacheService.running) {
        service.cacheLoading = true
        WallpaperCacheService.rebuild(service._wallpaperData)
      }
    }
  }

  property var _daemonWaitTimer: Timer {
    interval: 1000
    repeat: true
    onTriggered: {
      var rows = DbService.query("SELECT COUNT(*) AS cnt FROM meta WHERE type IS NOT NULL")
      if (rows.length > 0 && parseInt(rows[0].cnt) > 0) {
        _daemonWaitTimer.stop()
        service.startCacheCheck()
        return
      }
      if (!service.cacheReady) {
        if (!_uiRebuildTriggered && !WallpaperCacheService.running) {
          _uiRebuildTriggered = true
          cacheLoading = true
          WallpaperCacheService.rebuild(service._wallpaperData)
          return
        }
        var state = DbService.query("SELECT val FROM state WHERE key='last_rebuild'")
        if (state.length > 0) {
          cacheReady = true
          cacheLoading = false
          cacheResult = "cached"
          _deferredStartTimer.restart()
        }
      }
    }
  }

  function applyStatic(path) {
    WallpaperApplyService.applyStatic(path)
    service.wallpaperApplied()
  }

  function applyWE(id) {
    WallpaperApplyService.applyWE(id)
  }

  function applyVideo(path) {
    WallpaperApplyService.applyVideo(path)
  }

  function deleteWallpaperItem(type, name, weId) {
    for (var i = filteredModel.count - 1; i >= 0; i--) {
      var fi = filteredModel.get(i)
      if (fi.name === name && (fi.weId || "") === (weId || "")) {
        filteredModel.remove(i)
        break
      }
    }

    for (var j = _wallpaperData.length - 1; j >= 0; j--) {
      var wi = _wallpaperData[j]
      if (wi.name === name && (wi.weId || "") === (weId || "")) {
        _wallpaperData.splice(j, 1)
        _wallpaperData = _wallpaperData
        break
      }
    }

    DbService.exec("DELETE FROM meta WHERE name=" + DbService.sqlStr(name))

    if (type === "we") {
      _deleteWallpaper.command = ["rm", "-rf", weDir + "/" + weId]
    } else if (type === "video") {
      _deleteWallpaper.command = ["rm", "-f", videoDir + "/" + name]
    } else {
      _deleteWallpaper.command = ["rm", "-f", wallpaperDir + "/" + name]
    }
    _deleteWallpaper.running = true
  }

  function openSteamPage(weId) {
    _unsubscribeWE.command = ["xdg-open", "steam://url/CommunityFilePage/" + weId]
    _unsubscribeWE.running = true
  }

  property var _pendingNewItems: []
  property var _pendingMatugenItems: []

  property var _batchUpdateTimer: Timer {
    interval: 500
    onTriggered: {
      if (service._pendingNewItems.length === 0) return
      var items = service._pendingNewItems
      var matugenItems = service._pendingMatugenItems
      service._pendingNewItems = []
      service._pendingMatugenItems = []
      for (var i = 0; i < items.length; i++)
        service._wallpaperData.push(items[i])
      service._wallpaperData = service._wallpaperData
      service._syncClockPositionsFromWallpaperData()
      service.updateFilteredModel(true)
      if (Config.matugenEnabled) {
        for (var j = 0; j < matugenItems.length; j++)
          MatugenCacheService.processOne(matugenItems[j].path, matugenItems[j].key)
      }
    }
  }

  property var _checkCacheConn: Connections {
    target: WallpaperCacheService
    function onCacheReady(result) {
      if (service._pendingNewItems.length > 0)
        service._batchUpdateTimer.triggered()
      service.cacheResult = result || "regenerated"
      service.cacheReady = true
      service.cacheLoading = false
      service._postListLoadAction = (result === "regenerated") ? "regenerated" : "start"
      service._loadListFile()
    }
    function onFileProcessed(key, entry) {
      var newItem = {
        name: entry.name, type: entry.type, thumb: entry.thumb,
        path: entry.type === "static" ? service.wallpaperDir + "/" + entry.name : (entry.type === "video" ? service.videoDir + "/" + entry.name : ""),
        weId: entry.id || "", videoFile: entry.videoFile || "",
        mtime: entry.mtime || 0, hue: entry.group != null ? entry.group : 99, saturation: entry.sat || 0
      }
      service._pendingNewItems.push(newItem)
      var matugenPath = (entry.type === "static") ? service.wallpaperDir + "/" + entry.name : entry.thumb
      service._pendingMatugenItems.push({ path: matugenPath, key: key })
      service._batchUpdateTimer.restart()
    }
    function onFileRemoved(key) {
      MatugenCacheService.removeOne(key)
      var data = service._wallpaperData
      for (var i = data.length - 1; i >= 0; i--) {
        var dot = data[i].name.lastIndexOf(".")
        var itemKey = dot > 0 ? data[i].name.substring(0, dot) : data[i].name
        if (itemKey === key) {
          data.splice(i, 1)
          service._wallpaperData = data
          service.updateFilteredModel(true)
          return
        }
      }
    }
  }

  property var _watcherConn: Connections {
    target: WatcherService
    function onFileAdded(name, path, type) {
      WallpaperCacheService.processFiles([{name: name, src: path, type: type}])
    }
    function onFileRemoved(name, type) {
      WallpaperCacheService.removeFiles([{name: name, type: type}])
    }
    function onWeItemAdded(weId, weDir) {
      WallpaperCacheService.processWeItem(weId, weDir)
    }
    function onWeItemRemoved(weId) {
      WallpaperCacheService.removeFiles([{name: weId, type: "we"}])
    }
  }

  property var _wcProgressBinding: Binding {
    target: service
    property: "cacheProgress"
    value: WallpaperCacheService.progress
    when: WallpaperCacheService.running
  }
  property var _wcTotalBinding: Binding {
    target: service
    property: "cacheTotal"
    value: WallpaperCacheService.total
    when: WallpaperCacheService.running
  }
  property var _deleteWallpaper: Process {
    command: ["bash", "-c", "true"]
  }

  property var _clearCache: Process {
    id: clearCache
    command: ["bash", "-c", "true"]
    onExited: {
      service.cacheReady = false
      service._wallpaperData = []
    }
  }

  property var _unsubscribeWE: Process { command: ["bash", "-c", "true"] }

  property var _analysisConn: Connections {
    target: WallpaperAnalysisService
    function onProgressUpdated() {
      service.ollamaTaggingActive = WallpaperAnalysisService.running
      service.ollamaColorsActive = WallpaperAnalysisService.running
      service.ollamaTotalThumbs = WallpaperAnalysisService.totalThumbs
      service.ollamaTaggedCount = WallpaperAnalysisService.taggedCount
      service.ollamaColoredCount = WallpaperAnalysisService.coloredCount
      service.ollamaLogLine = WallpaperAnalysisService.lastLog
      service.ollamaEta = WallpaperAnalysisService.eta
    }
    function onItemAnalyzed(key, tags, colors) {
      service.tagsDb[key] = tags
      service.colorsDb[key] = colors
      service._analysisItemsDirty = true
    }
    function onAnalysisComplete() {
      service.ollamaTaggingActive = false
      service.ollamaColorsActive = false
      service.ollamaEta = ""
      service.ollamaLogLine = ""
      if (service._analysisItemsDirty) {
        service._analysisItemsDirty = false
        service.tagsDb = service.tagsDb
        service.colorsDb = service.colorsDb
        service._rebuildPopularTags()
        service.updateFilteredModel()
      }
    }
  }

  property bool _analysisItemsDirty: false

  property var _optimizeConn: Connections {
    target: ImageOptimizeService
    function onFinished(optimized, skipped, failed) {
      if (optimized > 0)
        service.refreshFromDb()
    }
  }

  property var _videoConvertConn: Connections {
    target: VideoConvertService
  }

  property var _clockSyncProc: Process {
    id: clockSyncProc
    command: ["bash", "-lc",
      "set -e\n" +
      "file=\"$1\"\n" +
      "keys_json=\"$2\"\n" +
      "mkdir -p \"$(dirname \"$file\")\"\n" +
      "if [ ! -s \"$file\" ]; then\n" +
      "  cat > \"$file\" <<'JSON'\n" +
      "{\"default\":{\"enabled\":false,\"centerOnScreen\":false,\"centerX\":false,\"centerY\":false,\"x\":0,\"y\":0,\"daySize\":90,\"dateSize\":20,\"timeSize\":17}}\n" +
      "JSON\n" +
      "fi\n" +
      "command -v jq >/dev/null 2>&1 || exit 0\n" +
      "tmp=\"$(mktemp)\"\n" +
      "jq --argjson keys \"$keys_json\" 'def defaults: {enabled:false,centerOnScreen:false,centerX:false,centerY:false,x:0,y:0,daySize:90,dateSize:20,timeSize:17}; def normalize($d): defaults + $d; ((if (type == \"object\") then . else {} end) as $root | ($keys | map(select((type==\"string\") and (length>0))) | unique) as $valid | ($root.default // {} | normalize(.)) as $d | ($root + {default:$d}) as $seed | ($seed | with_entries(select(.key == \"default\" or (.key as $k | ($valid | index($k)) != null)))) | reduce $valid[] as $k (. ; .[$k] = ((.[ $k ] // $d) | normalize(.))))' \"$file\" > \"$tmp\"\n" +
      "mv \"$tmp\" \"$file\"\n",
      "_", service.clockPositionsFile, service._clockSyncKeysJson]
    onExited: {
      if (service._clockSyncQueued) {
        service._clockSyncQueued = false
        clockSyncProc.running = true
      }
    }
  }

  property var _liveReloadTimer: Timer {
    interval: 30000
    running: service.showing && service.ollamaActive
    repeat: true
    onTriggered: {
      if (service._analysisItemsDirty) {
        service._analysisItemsDirty = false
        service.tagsDb = service.tagsDb
        service.colorsDb = service.colorsDb
        service._rebuildPopularTags()
        service.updateFilteredModel()
      }
    }
  }
}
