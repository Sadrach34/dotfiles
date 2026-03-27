import QtQuick

// Animated border-drawing effect that traces all four edges
// Direct port from piixident project
Item {
  id: root
  anchors.fill: parent

  property color lineColor: "#6272a4"
  property int lineThickness: 2
  property int duration: 800
  property real progress: internal.lineProgress
  property real lineOpacity: progress > 0 ? internal.lineOpacity : 0

  function animate() {
    lineAnim.stop()
    internal.lineProgress = 0
    internal.lineOpacity = 0
    lineAnim.start()
  }

  function reset() {
    lineAnim.stop()
    internal.lineProgress = 0
    internal.lineOpacity = 0
  }

  QtObject {
    id: internal
    property real lineProgress: 0
    property real lineOpacity: 0
  }

  Rectangle {
    height: root.lineThickness; radius: 1
    width: parent.width * root.progress
    color: root.lineColor
    anchors.top: parent.top; anchors.right: parent.right
    opacity: root.lineOpacity
  }
  Rectangle {
    height: root.lineThickness; radius: 1
    width: parent.width * root.progress
    color: root.lineColor
    anchors.bottom: parent.bottom; anchors.left: parent.left
    opacity: root.lineOpacity
  }
  Rectangle {
    width: root.lineThickness; radius: 1
    height: parent.height * root.progress
    color: root.lineColor
    anchors.left: parent.left; anchors.top: parent.top
    opacity: root.lineOpacity
  }
  Rectangle {
    width: root.lineThickness; radius: 1
    height: parent.height * root.progress
    color: root.lineColor
    anchors.right: parent.right; anchors.bottom: parent.bottom
    opacity: root.lineOpacity
  }

  ParallelAnimation {
    id: lineAnim
    NumberAnimation { target: internal; property: "lineProgress"; from: 0; to: 1; duration: root.duration; easing.type: Easing.OutCubic }
    NumberAnimation { target: internal; property: "lineOpacity"; from: 0; to: 1; duration: root.duration }
  }
}
