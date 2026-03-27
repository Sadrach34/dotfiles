import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: root

    required property var targetScreen
    screen: targetScreen

    property string imagePath: ""

    anchors {
        left: true
        bottom: true
    }

    implicitWidth: mainRow.width + 20
    implicitHeight: mainRow.height + 20

    color: "transparent"
    visible: imagePath !== ""

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property Process copyOverlayProcess: Process {
        id: copyOverlayProcess
        command: ["bash", "-c", "cat \"" + root.imagePath + "\" | wl-copy --type image/png"]
        onExited: exitCode => {
            if (exitCode !== 0) console.warn("Overlay Copy Failed (Exit code: " + exitCode + ")")
        }
    }

    Timer {
        id: hideTimer
        interval: 5000
        repeat: false
        running: root.visible && !mouseAreaHover.containsMouse
        onTriggered: root.imagePath = ""
    }

    MouseArea {
        id: mouseAreaHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
    }

    Connections {
        target: Screenshot
        function onImageSaved(path) {
            var s = root.targetScreen;
            var mx = Screenshot.selectionX;
            var my = Screenshot.selectionY;

            if (mx >= s.x && mx < (s.x + s.width) && my >= s.y && my < (s.y + s.height)) {
                root.imagePath = path;
            } else if (Screenshot.captureMode === "screen") {
                var cursor = Quickshell.cursor;
                if (cursor && cursor.screen && cursor.screen.name === s.name) {
                    root.imagePath = path;
                }
            }
        }
    }

    Row {
        id: mainRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 20
        spacing: 8

        ClippingRectangle {
            id: imgContainer

            property real maxWidth: 250
            property real maxHeight: 250
            property real imgRatio: img.sourceSize.width > 0 ? img.sourceSize.width / img.sourceSize.height : 1
            property real boxRatio: maxWidth / maxHeight

            width: {
                if (img.sourceSize.width <= 0) return 0;
                if (imgRatio > boxRatio) return maxWidth;
                return Math.min(maxWidth, img.sourceSize.width * (maxHeight / img.sourceSize.height));
            }

            height: {
                if (img.sourceSize.height <= 0) return 0;
                if (imgRatio > boxRatio) return Math.min(maxHeight, img.sourceSize.height * (maxWidth / img.sourceSize.width));
                return maxHeight;
            }

            radius: Styling.radius(4)
            color: "transparent"
            border.width: 2
            border.color: Colors.primaryFixed

            Image {
                mipmap: true
                id: img
                anchors.fill: parent
                source: root.imagePath !== "" ? "file://" + root.imagePath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                Item {
                    id: dragTarget
                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: {
                        "text/uri-list": "file://" + root.imagePath
                    }
                    Drag.imageSource: img.source
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.DragCopyCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    drag.target: dragTarget

                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                            proc.command = ["rm", root.imagePath];
                            proc.running = true;
                            root.imagePath = "";
                        } else {
                            Qt.openUrlExternally("file://" + root.imagePath);
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: Colors.background
                    opacity: dragArea.containsMouse ? 0.8 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: Icons.handGrab
                        font.family: Icons.font
                        color: Colors.overBackground
                    }
                }
            }
        }

        Column {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            ActionButton {
                icon: Icons.copy
                onTriggered: { copyOverlayProcess.running = true }
                StyledToolTip { show: parent.containsMouse; tooltipText: "Copy" }
            }

            ActionButton {
                icon: Icons.disk
                onTriggered: { root.imagePath = "" }
                StyledToolTip { show: parent.containsMouse; tooltipText: "Save & Close" }
            }

            ActionButton {
                icon: Icons.edit
                onTriggered: {
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["bash", "-c", "if command -v gradia >/dev/null; then gradia \"" + root.imagePath + "\"; else flatpak run be.alexandervanhee.gradia \"" + root.imagePath + "\"; fi & disown"];
                    proc.running = true;
                    root.imagePath = "";
                }
                StyledToolTip { show: parent.containsMouse; tooltipText: "Edit with Gradia" }
            }

            ActionButton {
                icon: Icons.trash
                hoverVariant: "error"
                clickVariant: "overerror"
                onTriggered: {
                    var proc = Qt.createQmlObject('import Quickshell; import Quickshell.Io; Process { }', root);
                    proc.command = ["rm", root.imagePath];
                    proc.running = true;
                    root.imagePath = "";
                }
                StyledToolTip { show: parent.containsMouse; tooltipText: "Delete" }
            }
        }
    }

    component ActionButton: MouseArea {
        id: btn
        width: 36
        height: 36
        hoverEnabled: true

        property string icon
        property string variant: "common"
        property string hoverVariant: "focus"
        property string clickVariant: "primary"

        signal triggered

        StyledRect {
            anchors.fill: parent
            radius: Styling.radius(0)
            variant: {
                if (btn.pressed) return btn.clickVariant;
                if (btn.containsMouse) return btn.hoverVariant;
                return btn.variant;
            }

            Text {
                anchors.centerIn: parent
                text: btn.icon
                font.family: Icons.font
                font.pixelSize: 16
                color: Colors.overBackground
            }
        }

        onClicked: triggered()
    }
}
