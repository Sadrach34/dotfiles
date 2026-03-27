// AmbxstNotificationHistory.qml
// Port de ambxst's NotificationHistory widget
// Usa Quickshell.Services.Notifications (api estándar)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: root

    // ── Colores y fuentes (inline, igual que ambxst) ─────────────────────────
    readonly property color clrPane:    "#1a1a1a"
    readonly property color clrInBg:    "#222222"
    readonly property color clrBorder:  "#2a2a2a"
    readonly property color clrText:    "#e0e0e0"
    readonly property color clrSubtext: "#888888"
    readonly property color clrPrimary: "#89b4fa"
    readonly property color clrOutline: "#6c7086"
    readonly property color clrError:   "#f38ba8"
    readonly property string fnt:       "JetBrainsMono Nerd Font"
    readonly property string iconFnt:   "Phosphor-Bold"

    // ── Estado DND (local + swaync si está disponible) ───────────────────────
    property bool dnd: false

    // ── Notificaciones agrupadas por appName ─────────────────────────────────
    property var appGroups: ({})
    property var appNames:  []

    // ── Servidor de notificaciones ───────────────────────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload:     true
        bodySupported:    true
        actionsSupported: true
        imageSupported:   true
        onNotification: (notif) => Qt.callLater(root.rebuildGroups)
    }

    Connections {
        target: notifServer.trackedNotifications
        function onValuesChanged() { Qt.callLater(root.rebuildGroups) }
    }

    function rebuildGroups() {
        var vals  = notifServer.trackedNotifications.values
        var g     = {}
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i]
            if (!n) continue
            var name = n.appName || "Unknown"
            if (!g[name]) g[name] = []
            g[name].push(n)
        }
        // Ordenar cada grupo: más reciente primero (Notification tiene .time en ms)
        for (var key in g) {
            g[key].sort(function(a, b) { return b.time - a.time })
        }
        appGroups = g
        appNames  = Object.keys(g)
    }

    function clearAll() {
        var vals = notifServer.trackedNotifications.values.slice()
        for (var i = 0; i < vals.length; i++) {
            if (vals[i]) vals[i].dismiss()
        }
        Qt.callLater(rebuildGroups)
    }

    // DND via swaync si está disponible (fail silently si no está)
    Process { id: dndProc; command: ["swaync-client", "-d"] }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Pane principal (igual que StyledRect variant:"pane") ─────────────────
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            color:  root.clrPane
            radius: 20
            border.width: 1
            border.color: root.clrBorder
            clip: true

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 4
                spacing: 4

                // ── Header row ─────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth:    true
                    Layout.maximumHeight: 32
                    spacing: 4

                    // Título "Notifications" (StyledRect internalbg fillWidth)
                    Rectangle {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        color:  root.clrInBg
                        radius: 16
                        Text {
                            anchors.centerIn: parent
                            text: "Notifications"
                            font.family:  root.fnt
                            font.pixelSize: 14
                            font.weight:  Font.Bold
                            color: root.clrText
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // DND bell toggle (primary cuando activo)
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        color:  root.dnd ? root.clrPrimary
                                         : (dndHover.containsMouse ? Qt.rgba(1,1,1,0.08) : root.clrInBg)
                        radius: root.dnd ? 12 : 16
                        Behavior on color  { ColorAnimation { duration: 150 } }
                        Behavior on radius { NumberAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.dnd ? "\ue5ee" : "\ue0ce" // bellZ : bell
                            font.family:    root.iconFnt
                            font.pixelSize: 18
                            color: root.dnd ? "#1a1a2e" : root.clrText
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            id: dndHover
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                root.dnd = !root.dnd
                                dndProc.running = true
                            }
                        }
                    }

                    // Broom / clear all
                    Rectangle {
                        id: clearBtnRect
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        color: broomArea.pressed ? root.clrError
                                                 : (broomArea.containsMouse ? Qt.rgba(1,1,1,0.08) : root.clrInBg)
                        radius: 16
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text:  "\uec54" // broom
                            font.family:    root.iconFnt
                            font.pixelSize: 18
                            color: broomArea.pressed ? "#1a1a2e" : root.clrText
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: broomArea
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked:    root.clearAll()
                        }
                    }
                }

                // ── Lista de notificaciones ────────────────────────────────────
                Rectangle {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    color:  "transparent"
                    radius: 16
                    clip:   true

                    // Estado vacío: icono campana centrado
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.appNames.length === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\ue0ce" // bell
                            font.family:    root.iconFnt
                            font.pixelSize: 40
                            color:          Qt.rgba(1, 1, 1, 0.08)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            font.family:    root.fnt
                            font.pixelSize: 12
                            color:          Qt.rgba(1, 1, 1, 0.2)
                        }
                    }

                    Flickable {
                        anchors.fill:   parent
                        contentWidth:   width
                        contentHeight:  notifColumn.implicitHeight
                        clip:           true
                        visible:        root.appNames.length > 0

                        ColumnLayout {
                            id: notifColumn
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.appNames

                                delegate: NotifGroupDelegate {
                                    required property string modelData
                                    required property int    index
                                    width: notifColumn.width
                                    appName:   modelData
                                    notifList: root.appGroups[modelData] ?? []
                                    onDismiss: n => n.dismiss()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Componente: grupo de notificaciones de una app ─────────────────────────
    component NotifGroupDelegate: Item {
        id: grp

        required property string appName
        required property var    notifList
        signal dismiss(var notification)

        implicitHeight: grpLayout.implicitHeight
        Layout.fillWidth: true

        ColumnLayout {
            id: grpLayout
            width: parent.width
            spacing: 2

            // App header
            Rectangle {
                Layout.fillWidth:   true
                Layout.preferredHeight: 28
                color:  root.clrInBg
                radius: 16

                RowLayout {
                    anchors.fill:    parent
                    anchors.leftMargin:  10
                    anchors.rightMargin: 10
                    spacing: 6

                    // App icon (si está disponible, desde primer notif)
                    Image {
                        id: appIconImg
                        property var firstNotif: grp.notifList.length > 0 ? grp.notifList[0] : null
                        source: firstNotif && firstNotif.appIcon ? "image://icon/" + firstNotif.appIcon : ""
                        visible: status === Image.Ready
                        width: 16; height: 16
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        id: appNameTxt
                        Layout.fillWidth: true
                        text: grp.appName
                        font.family:    root.fnt
                        font.pixelSize: 12
                        font.weight:    Font.Bold
                        color:          root.clrPrimary
                        elide:          Text.ElideRight
                    }

                    Text {
                        text: grp.notifList.length > 1 ? "(" + grp.notifList.length + ")" : ""
                        visible: grp.notifList.length > 1
                        font.family:    root.fnt
                        font.pixelSize: 11
                        color:          root.clrOutline
                    }
                }
            }

            // Lista de notificaciones del grupo (máx 3 visibles)
            Repeater {
                model: Math.min(grp.notifList.length, 3)

                delegate: NotifItemDelegate {
                    required property int index
                    width: grpLayout.width
                    notif: grp.notifList[index]
                    onDismissClicked: grp.dismiss(notif)
                }
            }
        }
    }

    // ── Componente: una notificación individual ───────────────────────────────
    component NotifItemDelegate: Item {
        id: item

        required property var notif
        signal dismissClicked

        implicitHeight: itemLayout.implicitHeight + 16
        Layout.fillWidth: true

        Rectangle {
            anchors.fill: parent
            color: itemHover.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"
            radius: 12
            Behavior on color { ColorAnimation { duration: 100 } }

            ColumnLayout {
                id: itemLayout
                anchors.fill:    parent
                anchors.margins: 8
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Imagen de la notificación (si tiene)
                    Image {
                        id: notifImg
                        source: item.notif && item.notif.image ? item.notif.image : ""
                        visible: source !== "" && status === Image.Ready
                        width: 36; height: 36
                        fillMode: Image.PreserveAspectCrop
                        mipmap: true
                        smooth: true
                        layer.enabled: true
                        layer.effect: null // simple rounded clip via mask not needed here
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: item.notif ? (item.notif.summary || "") : ""
                            font.family:    root.fnt
                            font.pixelSize: 13
                            font.weight:    Font.DemiBold
                            color:          root.clrText
                            elide:          Text.ElideRight
                            visible:        text !== ""
                        }
                        Text {
                            Layout.fillWidth: true
                            text: item.notif ? (item.notif.body || "") : ""
                            font.family:    root.fnt
                            font.pixelSize: 11
                            color:          root.clrSubtext
                            elide:          Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                        }
                    }

                    // X dismiss
                    Text {
                        text: "✕"
                        font.pixelSize: 10
                        color: dismissHover ? root.clrText : Qt.rgba(1,1,1,0.3)
                        property bool dismissHover: false
                        Behavior on color { ColorAnimation { duration: 100 } }
                        MouseArea {
                            anchors.fill:  parent
                            hoverEnabled:  true
                            cursorShape:   Qt.PointingHandCursor
                            onEntered:     parent.dismissHover = true
                            onExited:      parent.dismissHover = false
                            onClicked:     item.dismissClicked()
                        }
                    }
                }
            }
        }

        MouseArea {
            id: itemHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
}
