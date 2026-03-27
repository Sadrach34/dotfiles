import QtQuick

// Minimal Separator stub — a thin line, horizontal or vertical.
Rectangle {
    property bool vert: false  // vert=true → vertical line (for row layout)

    width:  vert ? 1   : 32
    height: vert ? 32  : 1
    color: "#45475a"
    opacity: 0.6
}
