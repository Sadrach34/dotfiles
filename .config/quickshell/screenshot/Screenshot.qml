pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    signal screenshotCaptured(string path)
    signal monitorScreenshotReady(string monitorName, string path)
    signal errorOccurred(string message)
    signal windowListReady(var windows)
    signal monitorsListReady(var monitors)
    signal lensImageReady(string path)
    signal imageSaved(string path)

    property string tempPathBase: "/tmp/qs_freeze"
    property string cropPath: "/tmp/qs_crop.png"
    property string lensPath: "/tmp/image.png"

    property string captureMode: "normal"

    property string screenshotsDir: ""
    property string finalPath: ""

    property var _activeWorkspaceIds: []
    property var monitors: []

    property int selectionX: 0
    property int selectionY: 0
    property int selectionW: 0
    property int selectionH: 0

    property real monitorScale: 1.0

    property Process xdgProcess: Process {
        id: xdgProcess
        command: ["bash", "-c", "xdg-user-dir PICTURES"]
        stdout: StdioCollector {}
        running: true
        onExited: exitCode => {
            if (exitCode === 0) {
                var dir = xdgProcess.stdout.text.trim()
                if (dir === "") {
                    dir = Quickshell.env("HOME") + "/Pictures"
                }
                root.screenshotsDir = dir + "/Screenshots"
                ensureDirProcess.running = true
            }
        }
    }

    property Process ensureDirProcess: Process {
        id: ensureDirProcess
        command: ["mkdir", "-p", root.screenshotsDir]
    }

    property Process freezeProcess: Process {
        id: freezeProcess
        command: []
        onExited: exitCode => {
            root._freezing = false;
            if (exitCode === 0) {
                for (var i = 0; i < root.monitors.length; i++) {
                    var m = root.monitors[i];
                    var path = root.tempPathBase + "_" + m.name + ".png";
                    root.monitorScreenshotReady(m.name, path);
                }
                root.screenshotCaptured(root.tempPathBase + "_ALL.png")
            } else {
                root.errorOccurred("Failed to capture screen (grim)")
                root._freezing = false;
            }
        }
    }

    property Process monitorsProcess: Process {
        id: monitorsProcess
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var rawMonitors = JSON.parse(monitorsProcess.stdout.text)
                    root.monitors = rawMonitors;

                    var ids = []
                    for (var i = 0; i < rawMonitors.length; i++) {
                        if (rawMonitors[i].activeWorkspace) {
                            ids.push(rawMonitors[i].activeWorkspace.id)
                        }
                    }
                    root._activeWorkspaceIds = ids

                    clientsProcess.running = true
                    root.monitorsListReady(rawMonitors)
                } catch (e) {
                    console.warn("Screenshot: Failed to parse monitors: " + e.message)
                    root.errorOccurred("Failed to parse monitors")
                }
            } else {
                console.warn("Screenshot: Failed to fetch monitors")
                root.errorOccurred("Failed to fetch monitors")
            }
        }
    }

    property Process clientsProcess: Process {
        id: clientsProcess
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var allClients = JSON.parse(clientsProcess.stdout.text)
                    var activeIds = root._activeWorkspaceIds

                    var filteredClients = allClients.filter(c => {
                        return c.pinned || (activeIds.length > 0 && activeIds.includes(c.workspace.id))
                    })

                    root.windowListReady(filteredClients)
                } catch (e) {
                    console.warn("Screenshot: Error processing windows: " + e.message)
                }
            }
        }
    }

    property Process cropProcess: Process {
        id: cropProcess
        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.captureMode === "lens") {
                    root.runLensScript()
                    root.captureMode = "normal"
                } else {
                    copyProcess.running = true
                    root.imageSaved(root.finalPath)
                }
            } else {
                root.errorOccurred("Failed to save image")
            }
        }
    }

    property Process notifySavedProcess: Process {
        id: notifySavedProcess
        onExited: {}
    }

    property Process copyProcess: Process {
        id: copyProcess
        command: ["bash", "-c", `cat "${root.finalPath}" | wl-copy --type image/png`]
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) console.warn("Screenshot Copy Error: " + text)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("Failed to copy to clipboard (Exit code: " + exitCode + ")")
            }
            // Notificar con thumbnail
            notifySavedProcess.command = [
                "bash", "-c",
                `notify-send -i "${root.finalPath}" "Captura guardada" "${root.finalPath.replace(Quickshell.env("HOME"), "~")}"`
            ];
            notifySavedProcess.running = true;
        }
    }

    property Process lensProcess: Process {
        id: lensProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Screenshot: Google Lens script executed successfully")
            } else {
                root.errorOccurred("Failed to open Google Lens: " + lensProcess.stderr.text)
            }
        }
    }

    property bool _freezing: false

    function freezeScreen() {
        if (_freezing) return;
        _freezing = true;

        var qsScreens = Quickshell.screens;
        var mappedMonitors = [];
        for (var i = 0; i < qsScreens.length; i++) {
             var s = qsScreens[i];
             mappedMonitors.push({
                 id: i,
                 name: s.name,
                 x: s.x,
                 y: s.y,
                 width: s.width * s.scale,
                 height: s.height * s.scale,
                 scale: s.scale
             });
        }
        root.monitors = mappedMonitors;

        root.executeFreezeBatch();
        root.fetchWindows();
    }

    function fetchWindows() {
        monitorsProcess.running = true
    }

    function executeFreezeBatch() {
        if (root.monitors.length === 0) {
            console.warn("Screenshot: No monitors found to freeze");
            _freezing = false;
            return;
        }

        var cmd = "";
        for (var i = 0; i < root.monitors.length; i++) {
            var m = root.monitors[i];
            var path = root.tempPathBase + "_" + m.name + ".png";
            cmd += `grim -o "${m.name}" "${path}" & `;
        }
        cmd += "wait";

        console.log("Screenshot: Executing freeze batch: " + cmd);
        freezeProcess.command = ["bash", "-c", cmd];
        freezeProcess.running = true;
    }

    function getTimestamp() {
        var d = new Date()
        var pad = (n) => n < 10 ? '0' + n : n;
        return d.getFullYear() + '-' +
               pad(d.getMonth() + 1) + '-' +
               pad(d.getDate()) + '-' +
               pad(d.getHours()) + '-' +
               pad(d.getMinutes()) + '-' +
               pad(d.getSeconds());
    }

    function processRegion(x, y, w, h) {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }

        var m = null;
        if (root.monitors.length > 0) {
            m = root.monitors.find(mon => {
                var logicalW = mon.width / mon.scale;
                var logicalH = mon.height / mon.scale;

                if (mon.transform === 1 || mon.transform === 3 || mon.transform === 5 || mon.transform === 7) {
                    var logicalW  = mon.height / mon.scale;
                    var logicalH  = mon.width / mon.scale;
                }

                return x >= mon.x && x < (mon.x + logicalW) &&
                       y >= mon.y && y < (mon.y + logicalH);
            });
        }

        if (!m) {
            console.warn("Screenshot: Could not find monitor for region " + x + "," + y);
            if (root.monitors.length > 0) m = root.monitors[0];
            else return;
        }

        var localX = x - m.x;
        var localY = y - m.y;

        var physX = Math.round(localX * m.scale);
        var physY = Math.round(localY * m.scale);
        var physW = Math.round(w * m.scale);
        var physH = Math.round(h * m.scale);

        console.log(`Screenshot: Cropping on monitor ${m.name} (Scale ${m.scale})`);
        console.log(`Screenshot: Logical Local: ${localX},${localY} ${w}x${h} -> Physical: ${physX},${physY} ${physW}x${physH}`);

        var srcPath = root.tempPathBase + "_" + m.name + ".png";

        var geom = `${physW}x${physH}+${physX}+${physY}`;
        cropProcess.command = ["convert", srcPath, "-crop", geom, root.finalPath];
        cropProcess.running = true;
    }

    function processFullscreen() {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }

        var cmd = ["grim", root.finalPath];
        cropProcess.command = cmd;
        cropProcess.running = true;
    }

    function processMonitorScreen(monitorName) {
        if (root.captureMode === "lens") {
            root.finalPath = root.lensPath;
        } else {
            if (root.screenshotsDir === "") {
                root.screenshotsDir = Quickshell.env("HOME") + "/Pictures/Screenshots"
            }
            var filename = "Screenshot_" + getTimestamp() + ".png"
            root.finalPath = root.screenshotsDir + "/" + filename
        }

        var srcPath = root.tempPathBase + "_" + monitorName + ".png";
        cropProcess.command = ["cp", srcPath, root.finalPath];
        cropProcess.running = true;
    }

    property Process openScreenshotsProcess: Process {
        id: openScreenshotsProcess
        command: ["xdg-open", root.screenshotsDir]
    }

    function openScreenshotsFolder() {
        if (root.screenshotsDir === "") {
             openScreenshotsProcess.command = ["xdg-open", Quickshell.env("HOME") + "/Pictures/Screenshots"];
        } else {
             openScreenshotsProcess.command = ["xdg-open", root.screenshotsDir];
        }
        openScreenshotsProcess.running = true;
    }

    function runLensScript() {
        var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
        verifyImageProcess.command = ["test", "-f", root.lensPath];
        verifyImageProcess.running = true;
    }

    property Process verifyImageProcess: Process {
        id: verifyImageProcess
        onExited: exitCode => {
            if (exitCode === 0) {
                var scriptPath = Qt.resolvedUrl("../../scripts/google_lens.sh").toString().replace("file://", "");
                lensProcess.command = ["bash", scriptPath];
                lensProcess.running = true;
            } else {
                root.errorOccurred("Image file not ready for Google Lens")
            }
        }
    }
}
