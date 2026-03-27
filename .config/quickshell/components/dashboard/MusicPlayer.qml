import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    property var theme
    property string configPath
    property bool dashboardVisible

    Layout.fillWidth: true
    Layout.preferredHeight: 180
    color: theme.surface
    radius: 15
    border.width: 1
    border.color: theme.border
    clip: true

    // Music state
    property string musicStatus: "Stopped"
    property bool backendPlaying: false
    property var playerList: []
    property int playerIndex: 0
    property string activePlayer: playerList.length > 0 ? playerList[playerIndex] : ""
    property string musicTitle: ""
    property string musicArtist: ""
    property real musicPosition: 0
    property real musicLength: 0
    property bool hasMusic: musicStatus === "Playing" || musicStatus === "Paused"

    function playerShortName(p) { return p.split(".")[0] }
    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    onDashboardVisibleChanged: {
        if (dashboardVisible) {
            playerList = []
            dashPlayerListProc.running = true
            if (!musicWatchProc.running) musicWatchProc.running = true
        } else {
            musicWatchProc.running = false
        }
    }

    // Polling de posicion: solo mientras Playing, cada 5 segundos
    Timer {
        interval: 5000
        running: dashboardVisible && musicStatus === "Playing"
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!dashMusicPosProc.running) dashMusicPosProc.running = true }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Text {
                text: musicTitle || "Nothing playing"
                color: theme.accent
                font.pixelSize: 13
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // Player switcher
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: playerList.length > 1

                Rectangle {
                    width: 16; height: 16; radius: 4
                    color: prevPlayerMa.containsMouse ? theme.highlight : "transparent"
                    Text { anchors.centerIn: parent; text: "◀"; color: theme.subtext; font.pixelSize: 10 }
                    MouseArea {
                        id: prevPlayerMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            playerIndex = (playerIndex - 1 + playerList.length) % playerList.length
                            musicWatchProc.running = false
                            musicWatchProc.running = true
                        }
                    }
                }
                Text {
                    text: playerList.length > 0 ? playerShortName(playerList[playerIndex]) : ""
                    color: theme.subtext
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: 16; height: 16; radius: 4
                    color: nextPlayerMa.containsMouse ? theme.highlight : "transparent"
                    Text { anchors.centerIn: parent; text: "▶"; color: theme.subtext; font.pixelSize: 10 }
                    MouseArea {
                        id: nextPlayerMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            playerIndex = (playerIndex + 1) % playerList.length
                            musicWatchProc.running = false
                            musicWatchProc.running = true
                        }
                    }
                }
            }

            Text {
                text: musicArtist
                color: theme.subtext
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                Layout.fillWidth: true
                elide: Text.ElideRight
                visible: musicArtist !== ""
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: hasMusic
                Text {
                    text: formatTime(musicPosition)
                    color: theme.subtext
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 3; radius: 2
                    color: theme.border
                    Rectangle {
                        width: musicLength > 0 ? parent.width * (musicPosition / musicLength) : 0
                        height: parent.height; radius: 2
                        color: theme.accent
                    }
                }
                Text {
                    text: formatTime(musicLength)
                    color: theme.subtext
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 15
                opacity: hasMusic ? 1.0 : 0.4
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: musicPrevMa.containsMouse ? theme.highlight : "transparent"
                    Text { anchors.centerIn: parent; text: "󰒮"; color: theme.text; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { id: musicPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: musicPrevProc.running = true }
                }
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: theme.accent
                    Text { anchors.centerIn: parent; text: musicStatus === "Playing" ? "󰏤" : "󰐊"; color: theme.background; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: musicPlayPauseProc.running = true }
                }
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: musicNextMa.containsMouse ? theme.highlight : "transparent"
                    Text { anchors.centerIn: parent; text: "󰒭"; color: theme.text; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { id: musicNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: musicNextProc.running = true }
                }
            }

            // BackEnd playlist
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                visible: !backendPlaying
                radius: 6
                color: backendMa.containsMouse ? theme.highlight : theme.border
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "  BackEnd"
                    color: theme.text
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                }
                MouseArea {
                    id: backendMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backendPlaying = true
                        backendProc.running = true
                    }
                }
            }
        }

        AnimatedImage {
            Layout.fillHeight: true
            Layout.preferredWidth: 130
            source: "file://" + configPath + "/assets/gifs/ado.gif"
            fillMode: Image.PreserveAspectFit
            smooth: true
            playing: musicStatus === "Playing"
            paused: musicStatus !== "Playing"
            cache: false
            asynchronous: true
        }
    }

    Process {
        id: dashPlayerListProc
        command: ["playerctl", "--list-all"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim()
                if (p.length > 0) {
                    var cur = playerList.slice()
                    if (cur.indexOf(p) === -1) cur.push(p)
                    playerList = cur
                }
            }
        }
        onExited: {
            if (playerList.length > 0)
                playerIndex = Math.min(playerIndex, playerList.length - 1)
            else
                playerIndex = 0
            if (dashboardVisible && !musicWatchProc.running) musicWatchProc.running = true
        }
    }

    // Proceso event-driven: emite solo cuando cambia status/título/artista/duración
    // NO incluir {{position}} — cambia cada segundo y causaría loop infinito
    Process {
        id: musicWatchProc
        command: activePlayer !== ""
            ? ["playerctl", "--player=" + activePlayer, "--follow", "metadata",
               "--format", "{{status}}|{{title}}|{{artist}}|{{mpris:length}}"]
            : ["playerctl", "--follow", "metadata",
               "--format", "{{status}}|{{title}}|{{artist}}|{{mpris:length}}"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|")
                if (parts.length < 4) return
                musicStatus  = parts[0] || "Stopped"
                musicTitle   = parts[1] || ""
                musicArtist  = parts[2] || ""
                musicLength  = (parseFloat(parts[3]) || 0) / 1000000
            }
        }
        onExited: {
            musicStatus = "Stopped"
            musicTitle = ""; musicArtist = ""
            musicLength = 0; musicPosition = 0
            if (dashboardVisible) musicRetryTimer.start()
        }
    }

    Timer {
        id: musicRetryTimer
        interval: 4000; repeat: false
        onTriggered: {
            if (dashboardVisible && !musicWatchProc.running) musicWatchProc.running = true
        }
    }

    Process {
        id: dashMusicPosProc
        command: ["playerctl", "--player=" + (activePlayer || ""), "position"]
        stdout: SplitParser { onRead: data => musicPosition = parseFloat(data.trim()) || 0 }
    }
    Process {
        id: musicPlayPauseProc
        command: ["playerctl", "--player=" + (activePlayer || ""), "play-pause"]
    }
    Process {
        id: musicNextProc
        command: ["playerctl", "--player=" + (activePlayer || ""), "next"]
    }
    Process {
        id: musicPrevProc
        command: ["playerctl", "--player=" + (activePlayer || ""), "previous"]
    }
    Process {
        id: backendProc
        command: ["bash", "-c", "pkill -x mpv 2>/dev/null; sleep 0.3; exec mpv --shuffle --input-ipc-server=/tmp/mpvsocket --vid=no --no-audio-display --ao=pipewire,pulse,alsa --ytdl-raw-options=cookies-from-browser=firefox '--ytdl-raw-options=extractor-args=youtube:player_client=android' '--user-agent=Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36' 'https://www.youtube.com/playlist?list=PLXuOK4h_ZtSbGV1FsT_nC0TRlf2EmwXEE'"]
        onExited: { backendPlaying = false }
    }
}
