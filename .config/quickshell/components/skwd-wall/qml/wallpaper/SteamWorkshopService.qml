import Quickshell
import Quickshell.Io
import QtQuick
import ".."
QtObject {
  id: swService

  required property string weDir
  property string query: ""
  property string sorting: "trend"
  property string requiredTag: ""
  property string requiredType: "Video"
  property var excludedTags: ["Mature", "Questionable", "NSFW", "Partial Nudity", "Nudity", "Gore"]
  property int currentPage: 1
  property int lastPage: 1
  property string apiKey: ""
  property int numPerPage: 24

  property var results: []
  property bool loading: false
  property string errorText: ""

  property var downloadStatus: ({})
  property var downloadProgress: ({})
  property var localWorkshopIds: ({})

  readonly property int _appId: 431960

  signal resultsUpdated()
  signal downloadFinished(string workshopId)

  function scanLocalDirs() {
    _localScanOutput = ""
    if (!weDir) return
    _localScanProc.running = true
  }

  property string _localScanOutput: ""
  property var _localScanProc: Process {
    command: ["find", swService.weDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-printf", "%f\n"]
    stdout: SplitParser {
      onRead: data => { swService._localScanOutput += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      var ids = {}
      var lines = swService._localScanOutput.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var id = lines[i].trim()
        if (id && /^\d+$/.test(id)) ids[id] = true
      }
      swService.localWorkshopIds = ids
    }
  }

  function search(page) {
    if (loading) return
    if (!apiKey) {
      errorText = "Steam API key required. Set steam.apiKey in config.json"
      resultsUpdated()
      return
    }
    swService.currentPage = page || 1
    loading = true
    errorText = ""
    _searchOutput = ""
    _searchProcess.command = ["curl", "-sSL", "--globoff", _buildUrl()]
    _searchProcess.running = true
  }

  function nextPage() {
    if (swService.currentPage < lastPage) search(swService.currentPage + 1)
  }
  function prevPage() {
    if (swService.currentPage > 1) search(swService.currentPage - 1)
  }

  function downloadWorkshop(workshopId) {
    if (!workshopId || _activeDownloads[workshopId]) return
    var safeId = workshopId.toString().replace(/[^0-9]/g, "")
    if (!safeId) return

    var status = Object.assign({}, downloadStatus)
    status[safeId] = "downloading"
    downloadStatus = status
    _activeDownloads[safeId] = true
    _downloadQueue.push(safeId)
    _drainDownloadQueue()
  }

  property var _activeDownloads: ({})
  property var _downloadQueue: []
  property int _runningDownloads: 0
  readonly property int _maxConcurrent: 1

  function _drainDownloadQueue() {
    while (_runningDownloads < _maxConcurrent && _downloadQueue.length > 0) {
      var id = _downloadQueue.shift()
      _runningDownloads++
      _spawnDownload(id)
    }
  }

  function _spawnDownload(workshopId) {
    var comp = Qt.createComponent("SteamWorkshopDownloadProc.qml")
    var proc = comp.createObject(swService, {
      workshopId: workshopId,
      steamDir: swService.weDir.replace(/\/steamapps\/workshop\/content\/431960\/?$/, ""),
      steamUsername: Config.steamUsername
    })
    proc.onProgressUpdate.connect(function(id, pct) {
      var p = Object.assign({}, downloadProgress)
      p[id] = pct
      downloadProgress = p
    })
    proc.onDone.connect(function(id, success) {
      _runningDownloads--
      var s = Object.assign({}, downloadStatus)
      if (success) {
        s[id] = "done"
        downloadStatus = s
        var ids = Object.assign({}, localWorkshopIds)
        ids[id] = true
        localWorkshopIds = ids
        downloadFinished(id)
      } else {
        s[id] = "error"
        downloadStatus = s
      }
      proc.destroy()
      _drainDownloadQueue()
    })
    proc.running = true
  }

  function _buildUrl() {
    var url = "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/?"
    var params = []
    params.push("key=" + encodeURIComponent(apiKey))
    params.push("appid=" + _appId)
    params.push("return_previews=true")
    params.push("return_tags=true")
    params.push("return_metadata=true")
    params.push("numperpage=" + numPerPage)
    params.push("page=" + swService.currentPage)

    var queryType = 1
    if (sorting === "totaluniquesubscribers") queryType = 3
    else if (sorting === "favorited") queryType = 2
    else if (sorting === "playtime_trend") queryType = 12
    else if (sorting === "textsearch" || query) queryType = 9

    if (query) queryType = 9
    params.push("query_type=" + queryType)

    if (query) params.push("search_text=" + encodeURIComponent(query))
    var tagIdx = 0
    if (requiredType) { params.push("requiredtags[" + tagIdx + "]=" + encodeURIComponent(requiredType)); tagIdx++ }
    if (requiredTag) { params.push("requiredtags[" + tagIdx + "]=" + encodeURIComponent(requiredTag)); tagIdx++ }

    for (var e = 0; e < excludedTags.length; e++) {
      params.push("excludedtags[" + e + "]=" + encodeURIComponent(excludedTags[e]))
    }

    return url + params.join("&")
  }

  property string _searchOutput: ""

  property var _searchProcess: Process {
    command: ["curl", "-fsSL", "about:blank"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => { swService._searchOutput += data }
    }
    onRunningChanged: {
      if (running) swService._searchOutput = ""
    }
    onExited: function(exitCode, exitStatus) {
      swService.loading = false
      if (exitCode !== 0) {
        swService.errorText = "Network error (curl exit " + exitCode + ")"
        swService.results = []
        swService.resultsUpdated()
        return
      }
      try {
        var json = JSON.parse(swService._searchOutput)
        var response = json.response || {}
        var total = response.total || 0
        var items = response.publishedfiledetails || []

        swService.results = items.map(function(item) {
          var previewUrl = item.preview_url || ""
          if (item.previews && item.previews.length > 0) {
            for (var p = 0; p < item.previews.length; p++) {
              if (item.previews[p].url) {
                previewUrl = item.previews[p].url
                break
              }
            }
          }

          var tags = []
          if (item.tags) {
            for (var t = 0; t < item.tags.length; t++) {
              if (item.tags[t].display_name) tags.push(item.tags[t].display_name)
              else if (item.tags[t].tag) tags.push(item.tags[t].tag)
            }
          }

          return {
            id: item.publishedfileid || "",
            title: item.title || "Untitled",
            description: (item.short_description || item.file_description || "").substring(0, 120),
            previewUrl: previewUrl,
            subscriptions: item.subscriptions || 0,
            favorited: item.favorited || 0,
            fileSize: item.file_size ? parseInt(item.file_size) : 0,
            tags: tags,
            creator: item.creator || ""
          }
        })

        swService.lastPage = Math.max(1, Math.ceil(total / swService.numPerPage))
        swService.errorText = ""
      } catch (e) {
        swService.errorText = "Parse error: " + e.message
        swService.results = []
      }
      swService.resultsUpdated()
      swService.scanLocalDirs()
    }
  }
}
