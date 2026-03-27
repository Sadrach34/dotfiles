pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Mezclador de audio — filas horizontales por app, PipeWire nativo
Item {
    id: appVol

    function streamBaseName(node) {
        return node?.properties?.["application.name"]
            || node?.description
            || node?.name
            || "Unknown"
    }

    function streamDetail(node) {
        var p = node?.properties || {}
        var base = streamBaseName(node).toLowerCase().trim()
        var candidates = [
            p["media.name"],
            p["media.title"],
            p["node.description"],
            p["node.nick"],
            node?.description,
            node?.name,
            p["application.process.binary"]
        ]

        for (var i = 0; i < candidates.length; i++) {
            var v = (candidates[i] || "").toString().trim()
            if (!v) continue
            var vl = v.toLowerCase()
            if (vl !== base && vl.indexOf(base) === -1)
                return v
        }
        return ""
    }

    function duplicateCount(baseName) {
        var base = (baseName || "").toLowerCase().trim()
        var count = 0
        for (var i = 0; i < appVol.sinkStreams.length; i++) {
            var n = appVol.sinkStreams[i]
            if (streamBaseName(n).toLowerCase().trim() === base)
                count++
        }
        return count
    }

    function duplicateOrdinal(node) {
        var base = streamBaseName(node).toLowerCase().trim()
        var ord = 0
        for (var i = 0; i < appVol.sinkStreams.length; i++) {
            var n = appVol.sinkStreams[i]
            if (streamBaseName(n).toLowerCase().trim() !== base)
                continue
            ord++
            if (n === node) return ord
            if (n?.id !== undefined && node?.id !== undefined && n.id === node.id)
                return ord
        }
        return ord > 0 ? ord : 1
    }

    function streamDisplayName(node) {
        var detail = streamDetail(node)
        if (detail) return detail

        var idx = duplicateOrdinal(node)
        return "Audio stream " + idx
    }

    // ── Streams de salida activos (apps reproduciendo audio) ─────────────
    readonly property list<var> sinkStreams: {
        if (!Pipewire.ready) return []
        return Pipewire.nodes.values.filter(function(node) {
            return node?.isSink && node?.isStream && node?.audio
        })
    }

    // ── Color de marca por app ────────────────────────────────────────────
    function appColor(name) {
        var n = (name || "").toLowerCase()
        if (n.indexOf("firefox")     !== -1) return "#FF7139"
        if (n.indexOf("spotify")     !== -1) return "#1DB954"
        if (n.indexOf("discord")     !== -1) return "#5865F2"
        if (n.indexOf("telegram")    !== -1) return "#2CA5E0"
        if (n.indexOf("mpv")         !== -1) return '#ff0000'
        if (n.indexOf("steam")       !== -1) return "#66C0F4"
        if (n.indexOf("rhythmbox")   !== -1) return "#E84393"
        if (n.indexOf("clementine")  !== -1) return "#E84393"
        if (n.indexOf("audacious")   !== -1) return "#E84393"
        if (n.indexOf("obs")         !== -1) return "#7B68EE"
        if (n.indexOf("zoom")        !== -1) return "#2D8CFF"
        if (n.indexOf("teams")       !== -1) return "#6264A7"
        if (n.indexOf("slack")       !== -1) return "#4A154B"
        if (n.indexOf("thunderbird") !== -1) return "#0A84FF"
        return "#8be9fd"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Header ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "\ue44a"
                font.family: "Phosphor-Bold"; font.pixelSize: 15
                color: "#e0e0e0"
            }
            Text {
                text: "Sound"
                color: "#e0e0e0"; font.pixelSize: 13; font.bold: true
                Layout.fillWidth: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#1a1a1a" }

        // ── Contenido ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Estado vacío
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: appVol.sinkStreams.length === 0
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "\ue44a"
                    font.family: "Phosphor-Bold"; font.pixelSize: 32
                    color: "#2a2a2a"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No audio playing"
                    color: "#404040"; font.pixelSize: 11
                }
            }

            // Lista de apps
            Flickable {
                anchors.fill: parent
                contentHeight: streamCol.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                visible: appVol.sinkStreams.length > 0
                interactive: true

                ColumnLayout {
                    id: streamCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: appVol.sinkStreams

                        delegate: Item {
                            id: rowItem
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 64

                            // Mantiene el nodo trackeado para recibir actualizaciones
                            PwObjectTracker {
                                objects: [rowItem.modelData]
                            }

                            readonly property bool   isMuted:  rowItem.modelData?.audio?.muted  ?? false
                            readonly property real   nodeVol:  rowItem.modelData?.audio?.volume ?? 0
                            readonly property string baseAppName: appVol.streamBaseName(rowItem.modelData)
                            readonly property string appName:     appVol.streamDisplayName(rowItem.modelData)
                            readonly property color  brandColor:  Qt.color(appVol.appColor(rowItem.baseAppName))

                            ColumnLayout {
                                anchors { fill: parent; leftMargin: 4; rightMargin: 6; topMargin: 4; bottomMargin: 0 }
                                spacing: 4

                                // Fila superior: botón mute + slider + %
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Botón mute/unmute
                                    Rectangle {
                                        width: 36; height: 36; radius: 8
                                        color: muteMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: rowItem.isMuted ? "\ue45a" : "\ue44a"
                                            font.family: "Phosphor-Bold"; font.pixelSize: 16
                                            color: rowItem.isMuted ? "#ff5555" : rowItem.brandColor
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }
                                        MouseArea {
                                            id: muteMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (rowItem.modelData?.audio)
                                                    rowItem.modelData.audio.muted = !rowItem.modelData.audio.muted
                                            }
                                        }
                                    }

                                    // Slider de volumen
                                    Slider {
                                        id: volSlider
                                        Layout.fillWidth: true
                                        implicitHeight: 30
                                        from: 0; to: 1

                                        Component.onCompleted: value = rowItem.nodeVol

                                        Connections {
                                            target: rowItem
                                            function onNodeVolChanged() {
                                                if (!volSlider.pressed)
                                                    volSlider.value = rowItem.nodeVol
                                            }
                                        }

                                        onMoved: {
                                            if (rowItem.modelData?.audio)
                                                rowItem.modelData.audio.volume = value
                                        }

                                        onValueChanged: {
                                            if (pressed && rowItem.modelData?.audio)
                                                rowItem.modelData.audio.volume = value
                                        }

                                        background: Rectangle {
                                            x: volSlider.leftPadding
                                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                            width: volSlider.availableWidth; height: 6; radius: 3
                                            color: "#1a1a1a"
                                            Rectangle {
                                                width: volSlider.visualPosition * parent.width
                                                height: parent.height; radius: 2
                                                color: rowItem.isMuted ? "#2a2a2a" : rowItem.brandColor
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }
                                        }

                                        handle: Rectangle {
                                            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                            width: 20; height: 20; radius: 10
                                            color: volSlider.pressed ? Qt.rgba(1,1,1,0.85)
                                                 : (rowItem.isMuted ? "#333333" : rowItem.brandColor)
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                        }
                                    }

                                    // Porcentaje
                                    Text {
                                        text: Math.round(rowItem.nodeVol * 100) + "%"
                                        color: "#ffffff"; font.pixelSize: 12
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 36
                                    }
                                }

                                // Fila inferior: nombre de la app
                                Text {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 38
                                    text: rowItem.appName
                                    color: "#ffffff"; font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
