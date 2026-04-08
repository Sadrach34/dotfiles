import Quickshell.Io
import QtQuick

Process {
  id: dlProc

  property string workshopId
  property string steamDir: ""
  property string steamUsername: ""

  signal progressUpdate(string id, real pct)
  signal done(string id, bool success)

  property bool _finished: false

  function _finish(success) {
    if (_finished) return
    _finished = true
    if (success)
      dlProc.progressUpdate(dlProc.workshopId, 1.0)
    dlProc.done(dlProc.workshopId, success)
    if (dlProc.running)
      dlProc.running = false
  }

  readonly property string _login: steamUsername || "anonymous"

  command: steamDir
    ? ["steamcmd", "+@ShutdownOnFailedCommand", "1", "+@NoPromptForPassword", "1", "+force_install_dir", steamDir, "+login", _login, "+workshop_download_item", "431960", workshopId, "+quit"]
    : ["steamcmd", "+@ShutdownOnFailedCommand", "1", "+@NoPromptForPassword", "1", "+login", _login, "+workshop_download_item", "431960", workshopId, "+quit"]

  stderr: SplitParser {
    splitMarker: "\n"
    onRead: data => {
      var match = data.match(/(\d+)\s*\/\s*(\d+)\s*bytes/)
      if (match) {
        var got = parseInt(match[1])
        var total = parseInt(match[2])
        if (total > 0) dlProc.progressUpdate(dlProc.workshopId, got / total)
      }

      var pctMatch = data.match(/(\d+(?:\.\d+)?)\s*%/)
      if (pctMatch) {
        dlProc.progressUpdate(dlProc.workshopId, parseFloat(pctMatch[1]) / 100.0)
      }

      if (data.indexOf("Success. Downloaded item") >= 0 || data.indexOf("Success! App '431960' fully installed") >= 0) {
        dlProc._finish(true)
      }
    }
  }

  stdout: SplitParser {
    splitMarker: "\n"
    onRead: data => {
      var match = data.match(/(\d+(?:\.\d+)?)\s*%/)
      if (match) {
        dlProc.progressUpdate(dlProc.workshopId, parseFloat(match[1]) / 100.0)
      }

      if (data.indexOf("Success") >= 0 || data.indexOf("fully installed") >= 0) {
        dlProc._finish(true)
      }
    }
  }

  onExited: function(exitCode, exitStatus) {
    dlProc._finish(exitCode === 0)
  }
}
