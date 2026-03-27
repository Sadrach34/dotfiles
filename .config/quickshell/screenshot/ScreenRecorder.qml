pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Copia de ambxst/modules/services/ScreenRecorder.qml
// Única diferencia: SuspendManager.isSuspending eliminado (no existe en este módulo)
// El statusTimer corre siempre para detectar instancias externas de gpu-screen-recorder

QtObject {
    id: root

    property bool isRecording: false
    property string duration: ""
    property string lastError: ""
    property bool canRecordDirectly: true

    property Process checkCapabilitiesProcess: Process {
        id: checkCapabilitiesProcess
        command: ["bash", "-c", "if [ -f /run/current-system/sw/bin/nixos-version ]; then if [[ \"$(type -p gpu-screen-recorder)\" == *\"/run/wrappers/bin/\"* ]]; then echo true; else echo false; fi; else echo true; fi"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                root.canRecordDirectly = (text.trim() === "true");
            }
        }
    }

    property string videosDir: ""

    property Process xdgVideosProcess: Process {
        id: xdgVideosProcess
        command: ["bash", "-c", "xdg-user-dir VIDEOS"]
        running: true
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                var dir = xdgVideosProcess.stdout.text.trim();
                if (dir === "") dir = Quickshell.env("HOME") + "/Videos";
                root.videosDir = dir + "/Recordings";
            } else {
                root.videosDir = Quickshell.env("HOME") + "/Videos/Recordings";
            }
        }
    }

    // Polling: detecta si gpu-screen-recorder está corriendo
    property Timer statusTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            checkProcess.running = true;
        }
    }

    property Process checkProcess: Process {
        id: checkProcess
        command: ["bash", "-c", "pgrep -f 'gpu-screen-recorder' | grep -v $$ > /dev/null"]
        onExited: exitCode => {
            var wasRecording = root.isRecording;
            root.isRecording = (exitCode === 0);
            if (root.isRecording) {
                timeProcess.running = true;
            } else {
                root.duration = "";
            }
        }
    }

    property Process timeProcess: Process {
        id: timeProcess
        command: ["bash", "-c", "pid=$(pgrep -f 'gpu-screen-recorder' | head -n 1); if [ -n \"$pid\" ]; then ps -o etime= -p \"$pid\"; fi"]
        stdout: StdioCollector {
            onTextChanged: {
                root.duration = text.trim();
            }
        }
    }

    function toggleRecording() {
        if (isRecording) {
            stopProcess.running = true;
        } else {
            startRecording(false, false, "portal", "");
        }
    }

    function startRecording(recordAudioOutput, recordAudioInput, mode, regionStr) {
        if (isRecording) return;

        var outputFile = root.videosDir + "/" + new Date().toISOString().replace(/[:.]/g, "-") + ".mkv";
        var cmd = "gpu-screen-recorder -f 60 -k h264 -fm cfr -c mkv";

        if (mode === "portal") {
            cmd += " -w portal";
        } else if (mode === "screen") {
            cmd += " -w screen";
        } else if (mode === "region") {
            cmd += " -w region";
            if (regionStr) cmd += " -region " + regionStr;
        }

        var audioSources = [];
        if (recordAudioOutput) audioSources.push("default_output");
        if (recordAudioInput)  audioSources.push("default_input");

        if (audioSources.length === 1) {
            cmd += " -a " + audioSources[0];
        } else if (audioSources.length > 1) {
            cmd += " -a \"" + audioSources.join("|") + "\"";
        }

        cmd += " -o \"" + outputFile + "\"";

        console.log("[ScreenRecorder] Iniciando: " + cmd);
        startProcess.command = ["bash", "-c", cmd];
        prepareProcess.running = true;
    }

    property Process prepareProcess: Process {
        id: prepareProcess
        command: ["mkdir", "-p", root.videosDir]
        onExited: {
            notifyStartProcess.running = true;
            startProcess.running = true;
        }
    }

    property Process notifyStartProcess: Process {
        id: notifyStartProcess
        command: ["notify-send", "Grabación de pantalla", "Iniciando grabación..."]
    }

    property Process startProcess: Process {
        id: startProcess
        command: ["bash", "-c", "echo 'Error: comando no configurado'"]
        stdout: StdioCollector {
            onTextChanged: console.log("[ScreenRecorder] OUT: " + text)
        }
        stderr: StdioCollector {
            onTextChanged: console.warn("[ScreenRecorder] ERR: " + text)
        }
        onExited: exitCode => {
            console.log("[ScreenRecorder] Salió con código: " + exitCode);
            if (exitCode !== 0 && exitCode !== 130 && exitCode !== 2) {
                root.isRecording = false;
                notifyErrorProcess.running = true;
            } else {
                notifySavedProcess.running = true;
            }
        }
    }

    property Process notifyErrorProcess: Process {
        id: notifyErrorProcess
        command: ["notify-send", "-u", "critical", "Error de grabación", "Falló al iniciar. Revisa los logs."]
    }

    property Process notifySavedProcess: Process {
        id: notifySavedProcess
        command: ["notify-send", "Grabación de pantalla", "Grabación guardada en " + root.videosDir]
    }

    property Process openVideosProcess: Process {
        id: openVideosProcess
        command: ["xdg-open", root.videosDir]
    }

    function openRecordingsFolder() {
        openVideosProcess.running = true;
    }

    property Process stopProcess: Process {
        id: stopProcess
        command: ["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]
    }

    function stopRecording() {
        if (isRecording) {
            stopProcess.running = true;
        }
    }
}
