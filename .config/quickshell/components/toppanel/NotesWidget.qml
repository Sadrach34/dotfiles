import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Widget de notas — en carpeta toppanel/
//
//  autoHeight: false (default) → rellena el padre con anchors (TopPanel)
//  autoHeight: true            → maneja Layout.preferredHeight con animación (Dashboard)
//  panelVisible                → el padre pasa su bandera de visibilidad para disparar reload
//  expanded                    → false por defecto; el padre puede forzar true (TopPanel)
Rectangle {
    id: notesWidget

    // ── Colors inline ──────────────────────────────────────────────────────
    readonly property color _bg:        "#0d0d0d"
    readonly property color _surface:   "#161616"
    readonly property color _accent:    "#ffffff"
    readonly property color _text:      "#e0e0e0"
    readonly property color _subtext:   "#808080"
    readonly property color _border:    "#2a2a2a"
    readonly property color _highlight: "#2e2e2e"

    // ── Config ─────────────────────────────────────────────────────────────
    property bool autoHeight:    false
    property bool expanded:      false
    property bool panelVisible:  false

    property bool linkPickerOpen: false
    property bool newFileMode:    false

    property string vaultPath:     Quickshell.env("HOME") + "/Documentos/Sil"
    property string currentSubpath: ""   // carpeta relativa al vault, e.g. "" o "Sildrech"
    property string browsingPath:  currentSubpath === "" ? vaultPath : (vaultPath + "/" + currentSubpath)
    property string currentFile:   "notas.md"
    property string notesPath:     browsingPath + "/" + currentFile

    // Lista de entradas: { name, isDir }
    property var    vaultFiles:  []

    property string _accum:    ""
    property bool   _dirty:    false
    property bool   _loading:  false
    property string _pendingFile: ""

    // ── Layout (sólo relevante cuando autoHeight: true) ────────────────────
    Layout.fillWidth:      autoHeight
    Layout.preferredHeight: {
        if (!autoHeight) return -1
        if (!expanded)   return 38
        return 230 + ((linkPickerOpen || newFileMode) ? 110 : 0)
    }
    Behavior on Layout.preferredHeight {
        enabled: autoHeight
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    color:        _surface
    radius:       15
    border.width: 1
    border.color: _border
    clip:         true

    // ── API pública ────────────────────────────────────────────────────────
    function reload() {
        loadProc.running = true
        listProc.running = true
    }

    onPanelVisibleChanged: { if (panelVisible) reload() }
    Component.onCompleted:  reload()

    // Cambia de archivo → limpiar inmediatamente y cargar el nuevo contenido
    onNotesPathChanged: {
        saveTimer.stop()
        _dirty   = false
        _accum   = ""
        _loading = true
        notesArea.text = ""
        loadProc.running = false
        loadProc.running = true
    }

    Timer {
        id: saveTimer
        interval: 1500; repeat: false
        onTriggered: {
            saveProc.environment = { "NOTE_PATH": notesPath, "NOTE_CONTENT": notesArea.text }
            saveProc.running = true
        }
    }

    // ── Header ─────────────────────────────────────────────────────────────
    Item {
        id: header
        width: parent.width
        height: 38

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 8

            Text {
                text: "\ue63e"
                font.family: "Phosphor-Bold"; font.pixelSize: 15
                color: _accent
            }
            Text {
                Layout.fillWidth: true
                text: {
                    var label = currentFile.replace(/\.md$/, "")
                    if (currentSubpath !== "") label = currentSubpath + "/" + label
                    return label
                }
                color: _accent; font.pixelSize: 13; font.bold: true
                elide: Text.ElideRight
            }
            // Indicador de cambios sin guardar
            Text { visible: _dirty; text: "●"; color: _accent; font.pixelSize: 13 }
            // Chevron expandir/colapsar
            Text {
                visible: !_dirty
                text: expanded ? "\ue13c" : "\ue136"
                font.family: "Phosphor-Bold"; font.pixelSize: 15
                color: _subtext
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                expanded = !expanded
                if (!expanded) { linkPickerOpen = false; newFileMode = false }
            }
        }
    }

    // ── Toolbar ────────────────────────────────────────────────────────────
    Item {
        id: toolbar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 30
        visible: expanded

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: 68; height: 24
                radius: 6
                color: linkPickerOpen ? _accent : _highlight
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "\ue2e2"; font.family: "Phosphor-Bold"; font.pixelSize: 12
                        color: linkPickerOpen ? _bg : _text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "link"; color: linkPickerOpen ? _bg : _text
                        font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        linkPickerOpen = !linkPickerOpen
                        newFileMode = false
                        if (linkPickerOpen) listProc.running = true
                    }
                }
            }

            Rectangle {
                width: 68; height: 24
                radius: 6
                color: newFileMode ? _accent : _highlight
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "\ue348"; font.family: "Phosphor-Bold"; font.pixelSize: 12
                        color: newFileMode ? _bg : _text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "new"; color: newFileMode ? _bg : _text
                        font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        newFileMode = !newFileMode
                        linkPickerOpen = false
                        if (newFileMode) Qt.callLater(function() { newNameField.forceActiveFocus() })
                    }
                }
            }
        }
    }

    // ── Panel expandible (link picker / nueva nota) ─────────────────────────
    Item {
        id: expandPanel
        anchors.top: toolbar.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: (linkPickerOpen || newFileMode) ? 106 : 0
        visible: expanded
        clip: true

        Behavior on height { NumberAnimation { duration: 150 } }

        // Link picker / file browser
        Rectangle {
            anchors.fill: parent
            color: _bg
            radius: 8
            border.width: 1
            border.color: _border
            visible: linkPickerOpen
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 4
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                Column {
                    width: parent.width
                    spacing: 2

                    // Botón "← atrás" cuando estamos dentro de una subcarpeta
                    Rectangle {
                        width: parent.width
                        height: currentSubpath !== "" ? 24 : 0
                        visible: currentSubpath !== ""
                        color: backMa.containsMouse ? _highlight : "transparent"
                        radius: 4
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6
                            Text {
                                text: "\ue138"; font.family: "Phosphor-Bold"; font.pixelSize: 12
                                color: _accent; anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: ".."; color: _accent; font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: backMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Subir un nivel
                                var parts = currentSubpath.split("/")
                                parts.pop()
                                currentSubpath = parts.join("/")
                                listProc.running = true
                            }
                        }
                    }

                    Repeater {
                        model: vaultFiles
                        Rectangle {
                            width: parent.width
                            height: 24
                            color: itemMa.containsMouse ? _highlight : "transparent"
                            radius: 4

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                spacing: 6
                                width: parent.width - 12
                                clip: true
                                Text {
                                    text: modelData.isDir ? "\ue24a" : "\ue348"
                                    font.family: "Phosphor-Bold"; font.pixelSize: 12
                                    color: modelData.isDir ? _accent : _subtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.name.replace(/\.md$/, "")
                                    color: modelData.isDir ? _accent : _text
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.width - 18 - parent.spacing
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: itemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.isDir) {
                                        // Entrar a la subcarpeta
                                        currentSubpath = currentSubpath === ""
                                            ? modelData.name
                                            : currentSubpath + "/" + modelData.name
                                        listProc.running = true
                                    } else {
                                        // Insertar [[link]] o abrir archivo
                                        if (linkPickerOpen) {
                                            var ref = "[[" + modelData.name.replace(/\.md$/, "") + "]]"
                                            notesArea.insert(notesArea.cursorPosition, ref)
                                            linkPickerOpen = false
                                        } else {
                                            currentFile = modelData.name
                                            linkPickerOpen = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Nueva nota
        Rectangle {
            anchors.fill: parent
            color: _bg
            radius: 8
            border.width: 1
            border.color: _border
            visible: newFileMode
            clip: true

            Row {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                TextField {
                    id: newNameField
                    width: parent.width - 68
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    background: Rectangle {
                        color: _surface
                        radius: 6
                        border.width: 1
                        border.color: newNameField.activeFocus ? _accent : _border
                    }
                    color: _text
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    placeholderText: "nombre-del-archivo"
                    placeholderTextColor: _subtext
                    leftPadding: 8
                    Keys.onReturnPressed: doCreate()
                    Keys.onEscapePressed: { newFileMode = false; text = "" }
                }

                Rectangle {
                    width: 52; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6
                    color: createMa.containsMouse ? _accent : _highlight
                    Text {
                        anchors.centerIn: parent
                        text: "crear"
                        color: createMa.containsMouse ? _bg : _text
                        font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    MouseArea {
                        id: createMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: doCreate()
                    }
                }
            }
        }
    }

    // Crea el archivo y lo abre en la carpeta actual.
    function doCreate() {
        var raw = newNameField.text.trim()
        if (raw === "") return
        var fname = raw.endsWith(".md") ? raw : raw + ".md"
        saveTimer.stop()
        _pendingFile = fname
        createProc.environment = { "VAULT": browsingPath, "FNAME": fname }
        createProc.running = true
        newFileMode = false
        newNameField.text = ""
    }

    // ── Área de texto ──────────────────────────────────────────────────────
    Rectangle {
        anchors.top: expandPanel.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        color: _bg
        radius: 8
        border.width: 1
        border.color: _border
        visible: expanded
        clip: true

        ScrollView {
            anchors.fill: parent
            anchors.margins: 6
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            TextArea {
                id: notesArea
                background: null
                color: _text
                selectedTextColor: _bg
                selectionColor: _accent
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: TextArea.Wrap
                placeholderText: "Escribe aquí tus notas e ideas..."
                placeholderTextColor: _subtext
                onTextChanged: {
                    if (_loading) return
                    _dirty = true
                    saveTimer.restart()
                }
            }
        }
    }

    // ── Procesos ───────────────────────────────────────────────────────────
    Process {
        id: loadProc
        command: ["bash", "-c", "cat \"$NOTE_PATH\" 2>/dev/null"]
        environment: ({ "NOTE_PATH": notesPath })
        stdout: SplitParser {
            onRead: data => { _accum += (_accum === "" ? "" : "\n") + data }
        }
        onExited: {
            _loading = true
            notesArea.text = _accum
            _accum   = ""
            _dirty   = false
            _loading = false
        }
    }

    Process {
        id: saveProc
        command: ["python3", "-c", "import os; open(os.environ['NOTE_PATH'],'w').write(os.environ['NOTE_CONTENT'])"]
        onExited: _dirty = false
    }

    // Lista carpetas (sin .) y archivos .md en browsingPath
    Process {
        id: listProc
        property var _buf: []
        command: ["bash", "-c",
            "find \"$BROWSE\" -maxdepth 1 -mindepth 1 " +
            "\\( -type d -not -name '.*' -printf 'd:%f\\n' \\) " +
            "-o \\( -name '*.md' -printf 'f:%f\\n' \\) 2>/dev/null | sort"
        ]
        environment: ({ "BROWSE": browsingPath })
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var isDir  = line.startsWith("d:")
                var name   = line.substring(2)
                listProc._buf.push({ name: name, isDir: isDir })
            }
        }
        onExited: {
            // Ordenar: carpetas primero, luego archivos; ambos alfabéticos
            var arr = listProc._buf.slice()
            arr.sort(function(a, b) {
                if (a.isDir !== b.isDir) return a.isDir ? -1 : 1
                return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
            })
            vaultFiles = arr
            listProc._buf = []
        }
    }

    Process {
        id: createProc
        command: ["bash", "-c", "mkdir -p \"$VAULT\" && touch \"$VAULT/$FNAME\""]
        onExited: {
            listProc.running = true
            if (_pendingFile !== "") {
                currentFile  = _pendingFile
                _pendingFile = ""
            }
        }
    }
}
