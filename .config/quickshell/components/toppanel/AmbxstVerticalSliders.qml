// VerticalSliders — port 1:1 de ambxst WidgetsTab columna derecha
// Brillo: StyledSlider vertical (track 4px, handle pill blanco)
// Volumen + mic: CircularControl (arco Canvas + icono, drag vertical)
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ── Colores inline (mismos que ambxst) ───────────────────────────────────
    readonly property color clrPane:      "#1a1a1a"
    readonly property color clrBorder:    "#2a2a2a"
    readonly property color clrText:      "#e0e0e0"
    readonly property color clrPrimary:   "#89b4fa"   // Styling.srItem("overprimary")
    readonly property color clrTrack:     "#333333"   // Colors.surfaceBright
    readonly property color clrOutline:   "#6c7086"   // Colors.outline
    readonly property string iconFnt:     "Phosphor-Bold"

    implicitWidth: 48

    // ── Procesos de LECTURA ──────────────────────────────────────────────────
    // Brillo: brightnessctl -m → "dev,class,N,70%,val" → $4 → "70%"
    Process {
        id: brReadProc
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{v=$4; gsub(/%/,\"\",v); print v}'"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) brSlider.externalValue = Math.max(1, Math.min(100, v))
            }
        }
    }
    // Volumen: wpctl get-volume → "Volume: 0.45" ó "Volume: 0.45 [MUTED]"
    Process {
        id: volReadProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                volMuted = line.indexOf("[MUTED]") !== -1
                var m = line.match(/[\d.]+/)
                if (m) volSlider.value = Math.min(1.5, parseFloat(m[0]))
            }
        }
    }
    // Mic: wpctl get-volume @DEFAULT_AUDIO_SOURCE@
    Process {
        id: micReadProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                micMuted = line.indexOf("[MUTED]") !== -1
                var m = line.match(/[\d.]+/)
                if (m) micSlider.value = Math.min(1.0, parseFloat(m[0]))
            }
        }
    }

    property bool volMuted: false
    property bool micMuted: false

    // ── Refresco periódico ───────────────────────────────────────────────────
    Timer {
        interval: 2000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            if (!brReadProc.running)  brReadProc.running  = true
            if (!volReadProc.running) volReadProc.running = true
            if (!micReadProc.running) micReadProc.running = true
        }
    }

    // ── Procesos de ESCRITURA ────────────────────────────────────────────────
    Process { id: brSetProc;    onExited: brReadProc.running  = true }
    Process { id: volSetProc;   onExited: volReadProc.running = true }
    Process { id: micSetProc;   onExited: micReadProc.running = true }
    Process { id: volMuteProc;  command: ["bash","-c","wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"];   onExited: volReadProc.running = true }
    Process { id: micMuteProc;  command: ["bash","-c","wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"]; onExited: micReadProc.running = true }
    // Reinicio seguro de un proceso: detiene antes de rearrancar
    function restartProc(proc, cmd) {
        proc.running = false
        proc.command = cmd
        proc.running = true
    }
    // ════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── BRILLO ──────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            spacing: 8

            // Icono brillo (StyledRect pane 48×48)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 48; height: 48
                radius: 20
                color: brIconArea.containsMouse ? "#252535" : root.clrPane
                border.width: 1; border.color: root.clrBorder
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: brSlider.displayValue > 30 ? "\ue472" : "\ue474"  // sun / sunDim
                    font.family: root.iconFnt; font.pixelSize: 18
                    color: root.clrText
                }
                MouseArea {
                    id: brIconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onWheel: wheel => {
                        var v = Math.max(1, Math.min(100, brSlider.displayValue + (wheel.angleDelta.y > 0 ? 5 : -5)))
                        brSlider.displayValue = v
                        root.restartProc(brSetProc, ["bash","-c","brightnessctl set " + v + "%"])
                    }
                }
            }

            // Slider vertical brillo (port StyledSlider vertical de ambxst)
            Item {
                Layout.preferredWidth: 48
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignHCenter

                VertSlider {
                    id: brSlider
                    anchors.fill: parent
                    onUserMoved: val => {
                        root.restartProc(brSetProc, ["bash","-c","brightnessctl set " + val + "%"])
                    }
                }
            }
        }

        // ── Separador ────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: root.clrBorder }

        // ── VOLUMEN (CircularControl) ─────────────────────────────────────────
        CircCtrl {
            id: volSlider
            Layout.alignment: Qt.AlignHCenter
            width: 48; height: 48
            iconText: {
                if (root.volMuted || volSlider.value < 0.01) return "\ue45a"   // speakerSlash
                if (volSlider.value < 0.19) return "\ue44e"                     // speakerNone
                if (volSlider.value < 0.49) return "\ue44c"                     // speakerLow
                return "\ue44a"                                                  // speakerHigh
            }
            accentColor: root.volMuted ? root.clrOutline : root.clrPrimary
            onControlChanged: v => {
                root.restartProc(volSetProc, ["bash","-c","wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2)])
            }
            onToggleRequested: {
                volMuteProc.running = false
                volMuteProc.running = true
            }
        }

        // ── MIC (CircularControl) ──────────────────────────────────────────────
        CircCtrl {
            id: micSlider
            Layout.alignment: Qt.AlignHCenter
            width: 48; height: 48
            iconText: root.micMuted ? "\ue30e" : "\ue310"   // micSlash / mic
            accentColor: root.micMuted ? root.clrOutline : root.clrPrimary
            onControlChanged: v => {
                root.restartProc(micSetProc, ["bash","-c","wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + v.toFixed(2)])
            }
            onToggleRequested: {
                micMuteProc.running = false
                micMuteProc.running = true
            }
        }

    } // ColumnLayout

    // ════════════════════════════════════════════════════════════════════════
    // Componente: VertSlider (port StyledSlider vertical de ambxst)
    // Track 4px, handle pill blanco, progreso #89b4fa bajo el handle
    // ════════════════════════════════════════════════════════════════════════
    component VertSlider: Item {
        id: vs
        property int  displayValue:  50
        property int  externalValue: 50
        property bool isDragging:    false
        signal userMoved(int val)

        // Sincroniza el valor externo solo cuando no se arrastra
        onExternalValueChanged: { if (!vs.isDragging) displayValue = externalValue }

        // ── Pane de fondo ─────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: root.clrPane
            border.width: 1; border.color: root.clrBorder
        }

        // ── Track container (4px centrado) ─────────────────────────────────
        Item {
            id: trackArea
            anchors.centerIn: parent
            width: 4
            height: parent.height - 16   // margen arriba/abajo

            // Track de fondo (encima del handle = zona no llenada)
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: vHandle.top
                anchors.bottomMargin: 4
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4; radius: 2
                color: root.clrTrack
            }
            // Track de progreso (debajo del handle = zona llenada)
            Rectangle {
                anchors.top: vHandle.bottom
                anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4; radius: 2
                color: root.clrPrimary
                Behavior on height { NumberAnimation { duration: 80 } }
            }

            // Handle (pill blanco, más ancho cuando no arrastra)
            Rectangle {
                id: vHandle
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (1.0 - vs.displayValue / 100.0) - height / 2
                height: vs.isDragging ? 2  : 4
                width:  vs.isDragging ? 20 : 16
                radius: 16
                color: "#e0e0e0"
                Behavior on y      { enabled: !vs.isDragging; NumberAnimation { duration: 80 } }
                Behavior on width  { NumberAnimation { duration: 100 } }
                Behavior on height { NumberAnimation { duration: 100 } }
            }
        }

        // ── Zona de arrastre (todo el item) ──────────────────────────────
        MouseArea {
            id: vsDrag
            anchors.fill: parent
            cursorShape: Qt.SizeVerCursor
            preventStealing: true

            function fromY(my) {
                // Márgenes del trackArea dentro del item
                var topMargin    = (parent.height - trackArea.height) / 2
                var relY         = my - topMargin
                var fraction     = 1.0 - Math.max(0.0, Math.min(1.0, relY / trackArea.height))
                return Math.round(fraction * 100)
            }

            onPressed: mouse => {
                vs.isDragging = true
                var v = fromY(mouse.y)
                vs.displayValue = v
                vs.userMoved(v)
            }
            onReleased: { vs.isDragging = false }
            onPositionChanged: mouse => {
                if (pressed) {
                    var v = fromY(mouse.y)
                    vs.displayValue = v
                    vs.userMoved(v)
                }
            }
            onWheel: w => {
                var v = Math.max(1, Math.min(100, vs.displayValue + (w.angleDelta.y > 0 ? 5 : -5)))
                vs.displayValue = v
                vs.userMoved(v)
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Componente: CircCtrl (port CircularControl de ambxst)
    // Arco Canvas 270° con handle + icono centrado, drag vertical
    // ════════════════════════════════════════════════════════════════════════
    component CircCtrl: Item {
        id: cc
        property real   value:       0.5
        property string iconText:    ""
        property color  accentColor: root.clrPrimary
        signal controlChanged(real v)
        signal toggleRequested

        // Geometría del arco (idéntica a ambxst CircularControl)
        readonly property real gapAngle:    45
        readonly property real lineWidth:   4
        readonly property real arcRadius:   16
        readonly property real handleSpace: 6
        readonly property real handleSize:  8
        readonly property real arcAngle:    value * (360 - 2 * gapAngle)  // 0..270

        // Fondo (StyledRect pane = clrPane + border)
        Rectangle {
            anchors.fill: parent
            radius: 20
            color:  ccArea.containsMouse ? "#252535" : root.clrPane
            border.width: 1; border.color: root.clrBorder
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Canvas del arco
        Canvas {
            id: ccCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2
                var cy = height / 2
                var r  = cc.arcRadius
                var lw = cc.lineWidth

                ctx.lineCap = "round"

                var baseStart = (Math.PI / 2) + (cc.gapAngle * Math.PI / 180)
                var progRad   = cc.arcAngle * Math.PI / 180
                var hGap      = cc.handleSpace * (360 / (2 * Math.PI * r)) * Math.PI / 180
                var hSize     = cc.handleSize  * (360 / (2 * Math.PI * r)) * Math.PI / 180

                // Arco de progreso
                var progEnd = baseStart + progRad - hGap
                if (cc.arcAngle > 1 && progEnd > baseStart + 0.01) {
                    ctx.strokeStyle = cc.accentColor.toString()
                    ctx.lineWidth = lw
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, baseStart, progEnd, false)
                    ctx.stroke()
                }

                // Handle (línea radial blanca en posición actual)
                var hAngle = baseStart + progRad
                var iR = r - 2; var oR = r + 4
                ctx.strokeStyle = "#e0e0e0"
                ctx.lineWidth = lw
                ctx.beginPath()
                ctx.moveTo(cx + iR * Math.cos(hAngle), cy + iR * Math.sin(hAngle))
                ctx.lineTo(cx + oR * Math.cos(hAngle), cy + oR * Math.sin(hAngle))
                ctx.stroke()

                // Resto del arco (gris)
                var remStart = baseStart + progRad + hGap
                var totalRad = (360 - 2 * cc.gapAngle) * Math.PI / 180
                var remEnd   = baseStart + totalRad
                if (remStart < remEnd) {
                    ctx.strokeStyle = root.clrOutline
                    ctx.lineWidth = lw
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, remStart, remEnd, false)
                    ctx.stroke()
                }
            }

            Connections {
                target: cc
                function onArcAngleChanged() { ccCanvas.requestPaint() }
                function onAccentColorChanged() { ccCanvas.requestPaint() }
            }

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Icono centrado
        Text {
            anchors.centerIn: parent
            text: cc.iconText
            font.family: root.iconFnt
            font.pixelSize: 18
            color: root.clrText
        }

        // Interacción
        MouseArea {
            id: ccArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            property real dragStartY:    0
            property real dragStartVal:  0
            property bool wasDragging:   false

            onPressed: mouse => {
                dragStartY   = mouse.y
                dragStartVal = cc.value
                wasDragging  = false
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                var delta = (dragStartY - mouse.y) / 100.0
                if (Math.abs(dragStartY - mouse.y) > 3) {
                    wasDragging = true
                    var v = Math.round(Math.max(0, Math.min(1, dragStartVal + delta)) * 100) / 100
                    cc.value = v
                    cc.controlChanged(v)
                }
            }
            onClicked: {
                if (!wasDragging) cc.toggleRequested()
            }
            onWheel: w => {
                var v = Math.round(Math.min(1, Math.max(0, cc.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))) * 100) / 100
                cc.value = v
                cc.controlChanged(v)
            }
        }
    }
}
