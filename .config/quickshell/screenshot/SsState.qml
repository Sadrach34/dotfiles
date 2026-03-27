pragma Singleton
import QtQuick

// Replaces the GlobalStates screenshot-related properties.
// ScreenshotTool reads/writes these to control visibility and mode.
QtObject {
    property bool screenshotToolVisible:  false
    property string screenshotCaptureMode: "region"
    property bool screenRecordToolVisible: false
}
