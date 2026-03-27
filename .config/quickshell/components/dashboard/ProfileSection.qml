import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Rectangle {
    property var theme
    property string configPath
    property bool dashboardVisible

    Layout.fillWidth: true
    Layout.preferredHeight: pfpPickerOpen ? 280 : 100
    color: theme.surface
    radius: 15
    border.width: 1
    border.color: theme.border
    clip: true

    property bool pfpPickerOpen: false
    property var pfpFiles: []

    Behavior on Layout.preferredHeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: 2000
        running: dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!uptimeProc.running) uptimeProc.running = true }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Item {
                width: 74; height: 74

                Rectangle {
                    anchors.fill: parent
                    radius: 37
                    color: "transparent"
                    border.width: 3
                    border.color: theme.accent
                }
                Image {
                    id: pfpImage
                    anchors.centerIn: parent
                    width: 68; height: 68
                    source: "file://" + configPath + "/assets/pfps/pfp.jpg"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: false
                    sourceSize.width: 256
                    sourceSize.height: 256
                    visible: false
                    property int reloadTrigger: 0
                    function reload() {
                        reloadTrigger++
                        source = ""
                        source = "file://" + configPath + "/assets/pfps/pfp.jpg?" + reloadTrigger
                    }
                }
                Rectangle {
                    id: pfpMask
                    anchors.centerIn: parent
                    width: 68; height: 68; radius: 34
                    visible: false
                }
                OpacityMask {
                    anchors.centerIn: parent
                    width: 68; height: 68
                    source: pfpImage
                    maskSource: pfpMask
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 22; height: 22; radius: 11
                    color: theme.accent
                    border.width: 2
                    border.color: theme.background
                    Text {
                        anchors.centerIn: parent
                        text: "󰏫"
                        color: theme.background
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pfpPickerOpen = !pfpPickerOpen
                        if (pfpPickerOpen) {
                            pfpFiles = []
                            pfpListProc.running = true
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    text: Quickshell.env("USER")
                    color: theme.accent
                    font.pixelSize: 26
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    id: uptimeText
                    text: "up ..."
                    color: theme.subtext
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: theme.surface
            radius: 10
            visible: pfpPickerOpen

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "Choose Avatar"
                    color: theme.accent
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: pfpGrid.height
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    GridLayout {
                        id: pfpGrid
                        width: parent.width
                        columns: 6
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: pfpFiles
                            Item {
                                width: 48; height: 48
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 24
                                    color: "transparent"
                                    border.width: 2
                                    border.color: thumbMa.containsMouse ? theme.highlight : theme.accent
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                }
                                Image {
                                    id: thumbImg
                                    anchors.centerIn: parent
                                    width: 44; height: 44
                                    source: "file://" + modelData
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    sourceSize.width: 128
                                    sourceSize.height: 128
                                    visible: false
                                }
                                Rectangle {
                                    id: thumbMask
                                    anchors.centerIn: parent
                                    width: 44; height: 44; radius: 22
                                    visible: false
                                }
                                OpacityMask {
                                    anchors.centerIn: parent
                                    width: 44; height: 44
                                    source: thumbImg
                                    maskSource: thumbMask
                                }
                                MouseArea {
                                    id: thumbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        setPfpProc.selFile = modelData
                                        setPfpProc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p"]
        stdout: SplitParser { onRead: data => uptimeText.text = data.trim() }
    }

    Process {
        id: pfpListProc
        command: ["bash", "-c",
            "find " + configPath + "/assets/pfps -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' \\) ! -name 'pfp.jpg' | sort"]
        stdout: SplitParser {
            onRead: data => {
                var file = data.trim()
                if (file.length > 0) {
                    var current = pfpFiles.slice()
                    current.push(file)
                    pfpFiles = current
                }
            }
        }
    }

    Process {
        id: setPfpProc
        property string selFile: ""
        command: ["bash", "-c", "cp '" + selFile + "' " + configPath + "/assets/pfps/pfp.jpg"]
        onExited: {
            pfpImage.reload()
            pfpPickerOpen = false
        }
    }
}
