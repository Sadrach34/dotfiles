// FullPlayer — port 1:1 de ambxst FullPlayer.qml
// Adapta qs.modules.* → Quickshell.Services.Mpris + colores inline
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.Mpris

Rectangle {
    id: player
    color: "transparent"
    radius: 12
    clip: true
    implicitHeight: 400

    // ── Tema inline ────────────────────────────────────────────────────────
    readonly property color  clrBg:         "#0d0d0d"
    readonly property color  clrSurface:    "#161616"
    readonly property color  clrOverBg:     "#e0e0e0"
    readonly property color  clrPrimary:    "#89b4fa"
    readonly property color  clrOutline:    "#404040"
    readonly property string fnt:           "JetBrainsMono Nerd Font"
    readonly property string iconFnt:       "Phosphor-Bold"
    // Mismos codepoints que Icons.qml de ambxst (Phosphor-Bold)
    readonly property string icPlay:        "\ue3d0"
    readonly property string icPause:       "\ue39e"
    readonly property string icStop:        "\ue46c"
    readonly property string icPrev:        "\ue5a4"
    readonly property string icNext:        "\ue5a6"
    readonly property string icShuffle:     "\ue422"
    readonly property string icRepeat:      "\ue3f6"
    readonly property string icRepeatOnce:  "\ue3f8"
    readonly property string icPlayer:      "\uecac"

    // ── Estado MPRIS ───────────────────────────────────────────────────────
    property int  activePlayerIndex: 0
    property bool playersListExpanded: false

    // playersList es mutable: se actualiza via Connections en el model
    // (Mpris.players es isPropertyConstant, los bindings JS no la detectan)
    property var playersList: []

    function refreshPlayers() {
        var vals = Mpris.players.values
        playersList = vals ? vals.slice() : []
        // apuntar al que reproduzca activamente
        for (var i = 0; i < playersList.length; i++) {
            if (playersList[i].playbackState === MprisPlaybackState.Playing) {
                activePlayerIndex = i; return
            }
        }
        if (playersList.length > 0 && activePlayerIndex >= playersList.length)
            activePlayerIndex = 0
    }

    // Escuchar inserciones/borrados en el ObjectModel
    Connections {
        target: Mpris.players
        function onRowsInserted()  { player.refreshPlayers() }
        function onRowsRemoved()   { player.refreshPlayers() }
        function onModelReset()    { player.refreshPlayers() }
    }

    readonly property var activePlayer: {
        if (playersList.length === 0) return null
        for (var i = 0; i < playersList.length; i++) {
            if (playersList[i].playbackState === MprisPlaybackState.Playing) return playersList[i]
        }
        return playersList[Math.min(activePlayerIndex, playersList.length - 1)]
    }

    readonly property bool isPlaying:       activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property bool hasArtwork:      (activePlayer?.trackArtUrl ?? "") !== ""

    property real position: activePlayer?.position ?? 0.0
    property real length:   activePlayer?.length   ?? 1.0
    property bool isSeeking: false

    // Polling de respaldo: apunta activePlayerIndex al player que reproduce
    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: {
            for (var i = 0; i < player.playersList.length; i++) {
                if (player.playersList[i].playbackState === MprisPlaybackState.Playing) {
                    if (player.activePlayerIndex !== i) player.activePlayerIndex = i
                    return
                }
            }
        }
    }

    Timer {
        id: seekUnlockTimer
        interval: 1000; repeat: false
        onTriggered: player.isSeeking = false
    }

    function formatTime(seconds) {
        var t = Math.floor(seconds)
        var h = Math.floor(t / 3600)
        var m = Math.floor((t % 3600) / 60)
        var s = t % 60
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function syncSeekBar() {
        if (!realSeekBar.isDragging && !player.isSeeking)
            realSeekBar.value = (hasActivePlayer && length > 0) ? position / length : 0
    }

    // Igual que getPlayerIcon() en ambxst (usa HTML font tag para app-icons)
    function getPlayerIcon(p) {
        if (!p) return player.icPlayer
        var n = ((p.desktopEntry ?? "") + (p.identity ?? "")).toLowerCase()
        if (n.includes("spotify"))                         return "<font face='Symbols Nerd Font Mono'>\udb81\udcd7</font>"
        if (n.includes("firefox"))                         return "<font face='Symbols Nerd Font Mono'>\udb80\udc39</font>"
        if (n.includes("chromium") || n.includes("chrome")) return "<font face='Symbols Nerd Font Mono'>\udbe9\udd17</font>"
        if (n.includes("telegram"))                        return "<font face='Symbols Nerd Font Mono'>\udbe8\ude8b</font>"
        return player.icPlayer
    }

    // Actualizar posición cada segundo mientras reproduce
    Timer {
        running: player.isPlaying
        interval: 1000; repeat: true
        onTriggered: {
            player.position = player.activePlayer?.position ?? 0
            player.syncSeekBar()
        }
    }

    Connections {
        target: player.activePlayer
        ignoreUnknownSignals: true
        function onPositionChanged() { player.syncSeekBar() }
    }

    Component.onCompleted: { refreshPlayers(); syncSeekBar() }

    // ══════════════════════════════════════════════════════════════════════
    // Fondo: blur del arte + full-art con máscara invertida (borde de arte)
    // -- Idéntico a ambxst --
    // ══════════════════════════════════════════════════════════════════════

    Image {
        id: backgroundArtBlurred
        anchors.fill: parent
        source: player.hasArtwork ? player.activePlayer.trackArtUrl : ""
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectCrop
        visible: false; asynchronous: true; mipmap: true
    }

    MultiEffect {
        anchors.fill: parent; source: backgroundArtBlurred
        blurEnabled: true; blurMax: 32; blur: 1.0
        opacity: player.hasArtwork ? 0.25 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
    }

    Image {
        id: backgroundArtFull
        anchors.fill: parent
        source: player.hasArtwork ? player.activePlayer.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop
        visible: false; asynchronous: true; mipmap: true
    }

    // Máscara del área interior (rectángulo con 4px de margen, mismos bordes)
    Item {
        id: innerAreaMask
        anchors.fill: parent; visible: false; layer.enabled: true
        Rectangle {
            x: 4; y: 4; width: parent.width - 8; height: parent.height - 8
            radius: player.radius - 4; color: "white"
        }
    }

    // Arte completo renderizado sólo FUERA de la máscara interior
    // → aparece como borde/frame de arte igual que en ambxst
    MultiEffect {
        anchors.fill: parent; source: backgroundArtFull
        maskEnabled: true; maskSource: innerAreaMask
        maskInverted: true; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
        opacity: player.hasArtwork ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
    }

    // ══════════════════════════════════════════════════════════════════════
    // Controles: ColumnLayout centrado (idéntico a ambxst)
    // ══════════════════════════════════════════════════════════════════════

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        // ── Área del disco: CircularSeekBar (semicírculo inferior) + portada ─
        Item {
            id: discArea
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 180; Layout.preferredHeight: 180
            Layout.topMargin: -8; Layout.bottomMargin: -24

            // CircularSeekBar portado inline con QtQuick.Shapes
            Item {
                id: realSeekBar
                anchors.fill: parent

                property real value: 0
                property bool isDragging: seekMouseArea.isDragging
                property real dragValue: 0
                signal valueEdited(real newValue)

                // startAngle 180° (9 en punto) · span 180° (media vuelta, por abajo)
                readonly property real startAngleDeg: 180
                readonly property real spanAngleDeg:  180
                readonly property real lineWidth:     6
                readonly property real ringPadding:   12
                readonly property real handleSpacing: 20
                readonly property real ringRadius:    (Math.min(width, height) / 2) - ringPadding
                readonly property real effectiveValue: isDragging ? dragValue : value
                readonly property real gapAngleDeg:   (handleSpacing / 2) / Math.max(1, ringRadius) * 180 / Math.PI
                readonly property real currentAngleRad: (startAngleDeg + spanAngleDeg * effectiveValue) * Math.PI / 180
                property real animHandleOffset: isDragging ? 9 : 6
                Behavior on animHandleOffset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    // Track de fondo
                    ShapePath {
                        strokeColor: player.clrOutline; strokeWidth: realSeekBar.lineWidth
                        strokeStyle: ShapePath.SolidLine; capStyle: ShapePath.RoundCap; fillColor: "transparent"
                        PathAngleArc {
                            centerX: realSeekBar.width / 2;  centerY: realSeekBar.height / 2
                            radiusX: realSeekBar.ringRadius; radiusY: realSeekBar.ringRadius
                            startAngle: realSeekBar.startAngleDeg
                                        + realSeekBar.spanAngleDeg * realSeekBar.effectiveValue
                                        + realSeekBar.gapAngleDeg
                            sweepAngle: Math.max(0,
                                        realSeekBar.spanAngleDeg * (1 - realSeekBar.effectiveValue)
                                        - realSeekBar.gapAngleDeg)
                        }
                    }

                    // Arco de progreso
                    ShapePath {
                        strokeColor: player.clrPrimary; strokeWidth: realSeekBar.lineWidth
                        strokeStyle: ShapePath.SolidLine; capStyle: ShapePath.RoundCap; fillColor: "transparent"
                        PathAngleArc {
                            centerX: realSeekBar.width / 2;  centerY: realSeekBar.height / 2
                            radiusX: realSeekBar.ringRadius; radiusY: realSeekBar.ringRadius
                            startAngle: realSeekBar.startAngleDeg
                            sweepAngle: Math.max(0,
                                        realSeekBar.spanAngleDeg * realSeekBar.effectiveValue
                                        - realSeekBar.gapAngleDeg)
                        }
                    }

                    // Handle (línea radial en el extremo del progreso)
                    ShapePath {
                        strokeColor: player.clrOverBg; strokeWidth: realSeekBar.lineWidth
                        strokeStyle: ShapePath.SolidLine; capStyle: ShapePath.RoundCap; fillColor: "transparent"
                        startX: realSeekBar.width  / 2 + (realSeekBar.ringRadius - realSeekBar.animHandleOffset) * Math.cos(realSeekBar.currentAngleRad)
                        startY: realSeekBar.height / 2 + (realSeekBar.ringRadius - realSeekBar.animHandleOffset) * Math.sin(realSeekBar.currentAngleRad)
                        PathLine {
                            x: realSeekBar.width  / 2 + (realSeekBar.ringRadius + realSeekBar.animHandleOffset) * Math.cos(realSeekBar.currentAngleRad)
                            y: realSeekBar.height / 2 + (realSeekBar.ringRadius + realSeekBar.animHandleOffset) * Math.sin(realSeekBar.currentAngleRad)
                        }
                    }
                }

                MouseArea {
                    id: seekMouseArea
                    anchors.fill: parent; hoverEnabled: true; preventStealing: true
                    cursorShape: player.hasActivePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: player.hasActivePlayer
                    property bool isDragging: false

                    function updateFromMouse(mx, my) {
                        var cx = width / 2; var cy = height / 2
                        var angle = Math.atan2(my - cy, mx - cx)
                        if (angle < 0) angle += 2 * Math.PI
                        var startRad = realSeekBar.startAngleDeg * Math.PI / 180
                        var spanRad  = realSeekBar.spanAngleDeg  * Math.PI / 180
                        var rel = angle - startRad
                        while (rel < 0) rel += 2 * Math.PI
                        realSeekBar.dragValue = (rel <= spanRad)
                            ? (rel / spanRad)
                            : ((rel - spanRad < 2 * Math.PI - rel) ? 1.0 : 0.0)
                    }

                    onPressed:  mouse => { isDragging = true; realSeekBar.dragValue = realSeekBar.value; updateFromMouse(mouse.x, mouse.y) }
                    onPositionChanged: mouse => { if (isDragging) updateFromMouse(mouse.x, mouse.y) }
                    onReleased: { if (isDragging) { isDragging = false; realSeekBar.valueEdited(realSeekBar.dragValue) } }
                }

                onValueEdited: newVal => {
                    if (player.activePlayer?.canSeek) {
                        player.isSeeking = true
                        seekUnlockTimer.restart()
                        realSeekBar.value = newVal
                        player.activePlayer.position = newVal * player.length
                    }
                }
            }

            // Portada giratoria (ClippingRectangle + rotación + inercia spring)
            Item {
                id: coverDiscContainer
                anchors.centerIn: parent
                width:  parent.width  - 52
                height: parent.height - 52
                layer.enabled: true; layer.smooth: true

                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: player.clrSurface

                    Image {
                        anchors.fill: parent; mipmap: true; asynchronous: true
                        source: player.hasArtwork ? player.activePlayer.trackArtUrl : ""
                        sourceSize: Qt.size(256, 256); fillMode: Image.PreserveAspectCrop
                    }
                    // Placeholder sin arte
                    Rectangle {
                        anchors.fill: parent; color: player.clrSurface
                        visible: !player.hasArtwork
                    }
                }

                NumberAnimation on rotation {
                    id: rotateAnim
                    from: 0; to: 360; duration: 8000; loops: Animation.Infinite; running: false
                }
                SpringAnimation {
                    id: springAnim
                    target: coverDiscContainer; property: "rotation"
                    spring: 0.8; damping: 0.05; epsilon: 0.25
                }

                Connections {
                    target: player
                    function onIsPlayingChanged() {
                        if (player.isPlaying) {
                            springAnim.stop()
                            var cur = coverDiscContainer.rotation % 360
                            if (cur < 0) cur += 360
                            coverDiscContainer.rotation = cur
                            rotateAnim.from = cur; rotateAnim.to = cur + 360
                            rotateAnim.restart()
                        } else {
                            rotateAnim.stop()
                            var cur2 = coverDiscContainer.rotation % 360
                            if (cur2 < 0) cur2 += 360
                            coverDiscContainer.rotation = cur2
                            springAnim.to = cur2 > 180 ? 360 : 0
                            springAnim.start()
                        }
                    }
                }
            }
        }

        // ── Metadatos (título + álbum + artista) ─────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter; spacing: 2

            Text {
                Layout.fillWidth: true
                text: player.hasActivePlayer ? (player.activePlayer?.trackTitle ?? "") : "Nothing Playing"
                color: player.clrOverBg; font.pixelSize: 14; font.weight: Font.Bold; font.family: player.fnt
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 1
                visible: text !== ""
            }
            Text {
                Layout.fillWidth: true
                text: player.hasActivePlayer ? (player.activePlayer?.trackAlbum ?? "") : "Enjoy the silence"
                color: player.clrOverBg; opacity: 0.7; font.pixelSize: 12; font.family: player.fnt
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 1
                visible: text !== ""
            }
            Text {
                Layout.fillWidth: true
                text: player.hasActivePlayer ? (player.activePlayer?.trackArtist ?? "") : "\u00af\\_(ツ)_/\u00af"
                color: player.clrOverBg; opacity: 0.7; font.pixelSize: 12; font.family: player.fnt
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 1
                visible: text !== ""
            }
        }

        // ── Controles de reproducción ─────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter; spacing: 8

            // Icono del player activo (clic izq = ciclar · clic der = expandir lista)
            MediaIconButton {
                icon: player.getPlayerIcon(player.activePlayer)
                textFormat: Text.RichText
                opacity: player.hasActivePlayer ? 1.0 : 0.5
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        player.activePlayerIndex = (player.activePlayerIndex + 1) % Math.max(1, player.playersList.length)
                    else if (mouse.button === Qt.RightButton)
                        player.playersListExpanded = !player.playersListExpanded
                }
            }

            // Anterior
            MediaIconButton {
                icon: player.icPrev
                enabled: player.activePlayer?.canGoPrevious ?? false
                opacity: player.hasActivePlayer ? (enabled ? 1.0 : 0.3) : 0.5
                onClicked: player.activePlayer?.previous()
            }

            // Play/Pause — radio animado (22=círculo paused · 6=cuadrado playing)
            Rectangle {
                id: playPauseBtn
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                color: player.clrPrimary
                opacity: player.hasActivePlayer ? 1.0 : 0.5
                radius: (player.isPlaying && player.hasActivePlayer) ? 6 : 22
                Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                Text {
                    anchors.centerIn: parent
                    text: !player.hasActivePlayer ? player.icStop
                          : (player.isPlaying ? player.icPause : player.icPlay)
                    font.family: player.iconFnt; font.pixelSize: 22
                    color: player.clrBg
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    enabled: player.hasActivePlayer
                    onClicked: player.activePlayer?.togglePlaying()
                }
            }

            // Siguiente
            MediaIconButton {
                icon: player.icNext
                enabled: player.activePlayer?.canGoNext ?? false
                opacity: player.hasActivePlayer ? (enabled ? 1.0 : 0.3) : 0.5
                onClicked: player.activePlayer?.next()
            }

            // Modo: shuffle / repeat / repeatOnce
            MediaIconButton {
                icon: {
                    if (!player.hasActivePlayer) return player.icShuffle
                    if (player.activePlayer?.shuffle) return player.icShuffle
                    var ls = player.activePlayer?.loopState ?? MprisLoopState.None
                    if (ls === MprisLoopState.Track)    return player.icRepeatOnce
                    if (ls === MprisLoopState.Playlist) return player.icRepeat
                    return player.icShuffle
                }
                opacity: player.hasActivePlayer ? 1.0 : 0.5
                onClicked: mouse => {
                    var p = player.activePlayer; if (!p) return
                    if (p.shuffle) {
                        p.shuffle = false; p.loopState = MprisLoopState.Playlist
                    } else if ((p.loopState ?? MprisLoopState.None) === MprisLoopState.Playlist) {
                        p.loopState = MprisLoopState.Track
                    } else if ((p.loopState ?? MprisLoopState.None) === MprisLoopState.Track) {
                        p.loopState = MprisLoopState.None
                    } else {
                        p.shuffle = true
                    }
                }
            }
        }

        // ── Tiempo (posición / duración) ──────────────────────────────────────
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: player.hasActivePlayer
                  ? (player.formatTime(player.position) + " / " + player.formatTime(player.length))
                  : "--:-- / --:--"
            color: player.clrOverBg; opacity: 0.5
            font.pixelSize: 10; font.family: player.fnt
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Overlay de la lista de players (igual al de ambxst)
    // ══════════════════════════════════════════════════════════════════════════
    Item {
        id: overlayLayer
        anchors.fill: parent; visible: player.playersListExpanded; z: 100

        Rectangle {
            anchors.fill: parent; color: "black"; opacity: 0.4; radius: player.radius
            MouseArea { anchors.fill: parent; onClicked: player.playersListExpanded = false }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
            height: Math.min(160, playersListView.contentHeight + 8)
            color: "#1a1a1a"; radius: player.radius - 4
            border.width: 1; border.color: "#2a2a2a"

            ListView {
                id: playersListView
                anchors.fill: parent; anchors.margins: 4; clip: true
                model: player.playersList

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: playersListView.width; height: 40
                    color: dlgHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    radius: 4
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                        Text {
                            text: player.getPlayerIcon(modelData)
                            textFormat: Text.RichText
                            font.family: player.iconFnt; font.pixelSize: 18
                            color: player.clrOverBg
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData?.trackTitle || modelData?.identity || "Unknown Player"
                            color: player.clrOverBg; font.family: player.fnt
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler  { id: dlgHover }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { player.activePlayerIndex = index; player.playersListExpanded = false }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MediaIconButton — igual al componente MediaIconButton de ambxst
    // ══════════════════════════════════════════════════════════════════════════
    component MediaIconButton: Text {
        property string icon: ""
        signal clicked(var mouse)

        text: icon
        font.family: player.iconFnt; font.pixelSize: 20
        color: mibArea.containsMouse ? player.clrPrimary : player.clrOverBg
        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: mibArea
            anchors.fill: parent; anchors.margins: -4
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => parent.clicked(mouse)
        }
    }
}
