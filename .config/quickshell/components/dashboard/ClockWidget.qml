import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    property var theme

    Layout.fillWidth: true
    Layout.preferredHeight: 310
    color: theme.surface
    radius: 15
    border.width: 1
    border.color: theme.border

    // state
    property int today: 0
    property int currentMonth: 0
    property int currentYear: 0
    property int firstWeekday: 0   // 0=Sun … 6=Sat
    property int daysInMonth: 0

    function updateCalendar(date) {
        today        = date.getDate()
        currentMonth = date.getMonth()
        currentYear  = date.getFullYear()
        var first     = new Date(currentYear, currentMonth, 1)
        firstWeekday  = first.getDay()          // 0 Sun, 1 Mon …
        daysInMonth   = new Date(currentYear, currentMonth + 1, 0).getDate()
    }

    function prevMonth() {
        var d = new Date(currentYear, currentMonth - 1, 1)
        updateCalendar(d)
    }
    function nextMonth() {
        var d = new Date(currentYear, currentMonth + 1, 1)
        updateCalendar(d)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8

        // ── Clock ─────────────────────────────────────────
        Text {
            id: timeDisplay
            anchors.horizontalCenter: parent.horizontalCenter
            text: "12:00:00 AM"
            color: theme.accent
            font.pixelSize: 36
            font.family: "JetBrainsMono Nerd Font"
        }
        Text {
            id: dateDisplay
            anchors.horizontalCenter: parent.horizontalCenter
            text: "01.01.2026, Friday"
            color: theme.subtext
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
        }

        // ── Separator ─────────────────────────────────────
        Rectangle {
            width: parent.width; height: 1
            color: theme.border
        }

        // ── Calendar header ───────────────────────────────
        Item {
            width: parent.width
            height: 22
            Text {
                id: monthLabel
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(currentYear, currentMonth, 1), "MMMM yyyy")
                color: theme.accent
                font.pixelSize: 13
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
            }
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "‹"
                color: prevMa.containsMouse ? theme.accent : theme.subtext
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: prevMonth() }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: nextMa.containsMouse ? theme.accent : theme.subtext
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nextMonth() }
            }
        }

        // ── Day-of-week headers ───────────────────────────
        Grid {
            width: parent.width
            columns: 7
            spacing: 0
            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                Text {
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: theme.subtext
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }

        // ── Day grid ──────────────────────────────────────
        Grid {
            id: dayGrid
            width: parent.width
            columns: 7
            spacing: 1

            Repeater {
                // 6 weeks × 7 = 42 cells
                model: 42
                Item {
                    width: dayGrid.width / 7
                    height: 30

                    property int dayNum: index - firstWeekday + 1
                    property bool isValid: dayNum >= 1 && dayNum <= daysInMonth
                    property bool isToday: isValid && dayNum === today
                        && currentMonth === new Date().getMonth()
                        && currentYear  === new Date().getFullYear()

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: parent.height - 4
                        radius: (width / 2)
                        color: isToday ? theme.accent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: isValid ? dayNum : ""
                        color: isToday ? theme.background : theme.text
                        font.pixelSize: 10
                        font.bold: isToday
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            var hours   = now.getHours()
            var minutes = now.getMinutes()
            var seconds = now.getSeconds()
            var ampm = hours >= 12 ? "PM" : "AM"
            hours = hours % 12
            hours = hours ? hours : 12
            var h = hours   < 10 ? "0" + hours   : hours
            var m = minutes < 10 ? "0" + minutes : minutes
            var s = seconds < 10 ? "0" + seconds : seconds
            timeDisplay.text = h + ":" + m + ":" + s + " " + ampm
            dateDisplay.text = Qt.formatDate(now, "dd.MM.yyyy, dddd")
            updateCalendar(now)
        }
    }
}
