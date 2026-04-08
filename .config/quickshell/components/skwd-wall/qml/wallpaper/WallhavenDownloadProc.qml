import Quickshell.Io
import QtQuick

Process {
  id: dlProc

  property string whId
  property string dest

  signal progressUpdate(string id, real pct)
  signal done(string id, bool success)

  stderr: SplitParser {
    splitMarker: "\r"
    onRead: data => {
      var match = data.match(/([\d.]+)\s*%/)
      if (match) {
        dlProc.progressUpdate(dlProc.whId, parseFloat(match[1]) / 100.0)
      }
    }
  }

  onExited: function(exitCode, exitStatus) {
    if (exitCode === 0) {
      dlProc.progressUpdate(dlProc.whId, 1.0)
      _verifyProc.running = true
    } else {
      dlProc.done(dlProc.whId, false)
    }
  }

  property var _verifyProc: Process {
    command: ["file", "--brief", "--mime-type", dlProc.dest]
    property string _output: ""
    stdout: SplitParser {
      onRead: data => { dlProc._verifyProc._output = data.trim() }
    }
    onExited: function(exitCode, exitStatus) {
      var mime = _output.toLowerCase()
      if (exitCode === 0 && mime.indexOf("image/") === 0) {
        dlProc.done(dlProc.whId, true)
      } else {
        _cleanupProc.running = true
      }
    }
  }

  property var _cleanupProc: Process {
    command: ["rm", "-f", dlProc.dest]
    onExited: function() {
      dlProc.done(dlProc.whId, false)
    }
  }
}
