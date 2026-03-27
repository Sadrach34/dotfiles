// Servicio de monitoreo del sistema — wrapper del script system_monitor.py
// Funciona igual que el SystemResources de ambxst pero sin sus módulos.
// Uso: SysResources { id: sysRes }  →  sysRes.cpuUsage, sysRes.cpuHistory, etc.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Propiedades estáticas (llegan en el primer frame del script) ──────────
    property string cpuModel:   ""
    property int    gpuCount:   0
    property bool   gpuDetected: false
    property var    gpuNames:   []
    property var    gpuVendors: []
    property var    diskTypes:  ({})

    // ── Valores en tiempo real ────────────────────────────────────────────────
    property real cpuUsage:   0.0
    property int  cpuTemp:    -1
    property real ramUsage:   0.0
    property real ramTotal:   0
    property real ramUsed:    0
    property real ramAvailable: 0
    property var  gpuUsages:  []
    property var  gpuTemps:   []
    property var  diskUsage:  ({})

    // ── Historial (arrays de [0..1]) ──────────────────────────────────────────
    property var cpuHistory:    []
    property var ramHistory:    []
    property var gpuHistories:  []
    property int maxHistoryPts: 120
    property int totalPts:      0

    // ── Control ───────────────────────────────────────────────────────────────
    property bool  active:      false
    property int   intervalMs:  2000
    property var   monitorDisks: ["/"]

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/system_monitor.py"

    // Inicia / detiene el proceso según `active`
    onActiveChanged: {
        if (active) {
            if (!monProc.running) monProc.running = true
        } else {
            monProc.running = false
        }
    }
    onIntervalMsChanged: {
        if (monProc.running) {
            monProc.running = false
            restartTimer.start()
        }
    }

    property Timer restartTimer: Timer {
        interval: 100; repeat: false
        onTriggered: if (root.active) monProc.running = true
    }

    function _pushHistory(arr, val) {
        var next = arr.slice()
        next.push(val)
        if (next.length > root.maxHistoryPts) next.shift()
        return next
    }

    function _updateHistory() {
        root.totalPts++
        root.cpuHistory = _pushHistory(root.cpuHistory, root.cpuUsage / 100)
        root.ramHistory = _pushHistory(root.ramHistory, root.ramUsage / 100)

        if (root.gpuDetected && root.gpuCount > 0) {
            var newGH = root.gpuHistories.slice()
            while (newGH.length < root.gpuCount) newGH.push([])
            for (var i = 0; i < root.gpuCount; i++) {
                newGH[i] = _pushHistory(newGH[i], (root.gpuUsages[i] || 0) / 100)
            }
            root.gpuHistories = newGH
        }
    }

    property Process monProc: Process {
        id: monProc
        command: {
            var cmd = ["python3", root.scriptPath, root.intervalMs.toString()]
            return cmd.concat(root.monitorDisks)
        }
        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (!line) return
                try {
                    var s = JSON.parse(line)

                    // Info estática (solo en el primer mensaje)
                    if (s.static) {
                        root.cpuModel    = s.static.cpu_model   || ""
                        root.gpuNames    = s.static.gpu_names   || []
                        root.gpuVendors  = s.static.gpu_vendors || []
                        root.gpuCount    = s.static.gpu_count   || 0
                        root.gpuDetected = root.gpuCount > 0
                        root.diskTypes   = s.static.disk_types  || ({})
                        return
                    }

                    if (s.cpu) {
                        root.cpuUsage = s.cpu.usage
                        root.cpuTemp  = s.cpu.temp
                    }
                    if (s.ram) {
                        root.ramUsage     = s.ram.usage
                        root.ramTotal     = s.ram.total
                        root.ramUsed      = s.ram.used
                        root.ramAvailable = s.ram.available
                    }
                    if (s.disk) root.diskUsage = s.disk.usage
                    if (s.gpu) {
                        root.gpuUsages = s.gpu.usages
                        root.gpuTemps  = s.gpu.temps
                    }

                    root._updateHistory()
                } catch(e) {}
            }
        }
    }
}
