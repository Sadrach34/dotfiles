// Calendar — port 1:1 de ambxst/calendar/Calendar.qml + CalendarDayButton.qml
import QtQuick
import QtQuick.Layouts
import "calendarLayout.js" as CalendarLayout

Item {
    id: root

    readonly property color clrPane:         "#1a1a1a"
    readonly property color clrInBg:         "#222222"
    readonly property color clrBorder:       "#2a2a2a"
    readonly property color clrText:         "#e0e0e0"
    readonly property color clrOutline:      "#6c7086"
    readonly property color clrDimDay:       "#3d3d4f"
    readonly property color clrPrimary:      "#89b4fa"
    readonly property color clrOverPrimary:  "#1a1a2e"
    readonly property string fnt:            "JetBrainsMono Nerd Font"
    readonly property string iconFnt:        "Phosphor-Bold"

    property int monthShift: 0
    property var viewingDate:        CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayoutData: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var calLayout:          calendarLayoutData.calendar
    property int currentWeekRow:     calendarLayoutData.currentWeekRow
    property int currentDayOfWeek: {
        if (monthShift !== 0) return -1
        return (new Date().getDay() + 6) % 7
    }

    function getDayAbbrev(dayIndex) {
        var d = new Date(2024, 0, 1 + dayIndex)
        var name = d.toLocaleDateString(Qt.locale(), "ddd")
        return (name.charAt(0).toUpperCase() + name.slice(1, 2)).replace(".", "")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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

                RowLayout {
                    Layout.fillWidth:    true
                    Layout.maximumHeight: 32
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        color:  root.clrInBg
                        radius: 16
                        Text {
                            anchors.centerIn: parent
                            text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                            font.family:    root.fnt
                            font.pixelSize: 14
                            font.weight:    Font.Bold
                            color:          root.clrText
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        color: leftArea.pressed ? root.clrPrimary
                                                : (leftArea.containsMouse ? Qt.rgba(1,1,1,0.08) : root.clrInBg)
                        radius: 16
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\ue138"
                            font.family:    root.iconFnt
                            font.pixelSize: 16
                            color: leftArea.pressed ? root.clrOverPrimary : root.clrText
                        }
                        MouseArea {
                            id: leftArea; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.monthShift--
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.fillHeight: true
                        color: rightArea.pressed ? root.clrPrimary
                                                 : (rightArea.containsMouse ? Qt.rgba(1,1,1,0.08) : root.clrInBg)
                        radius: 16
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\ue13a"
                            font.family:    root.iconFnt
                            font.pixelSize: 16
                            color: rightArea.pressed ? root.clrOverPrimary : root.clrText
                        }
                        MouseArea {
                            id: rightArea; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.monthShift++
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    color:  root.clrInBg
                    radius: 16

                    ColumnLayout {
                        anchors.fill:    parent
                        anchors.margins: 8
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            Repeater {
                                model: 7
                                delegate: DayCell {
                                    required property int index
                                    dayText:  root.getDayAbbrev(index)
                                    isToday:  0
                                    bold:     true
                                    isCurDow: index === root.currentDayOfWeek
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin:    2
                            Layout.bottomMargin: 2
                            Layout.leftMargin:   8
                            Layout.rightMargin:  8
                            height: 1
                            color:  root.clrBorder
                        }

                        Repeater {
                            model: 6
                            delegate: Rectangle {
                                required property int index
                                readonly property int rowIdx: index
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: 28
                                color:  (rowIdx === root.currentWeekRow) ? root.clrPane : "transparent"
                                radius: 12

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    Repeater {
                                        model: 7
                                        delegate: DayCell {
                                            required property int index
                                            dayText:  root.calLayout[rowIdx][index].day.toString()
                                            isToday:  root.calLayout[rowIdx][index].today
                                            bold:     false
                                            isCurDow: false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component DayCell: Item {
        id: cell
        required property string dayText
        required property int    isToday
        property bool bold:     false
        property bool isCurDow: false

        Layout.fillWidth:       true
        Layout.fillHeight:      false
        Layout.preferredWidth:  28
        Layout.preferredHeight: 28

        Rectangle {
            anchors.centerIn: parent
            width:  Math.min(parent.width, parent.height)
            height: width
            radius: 12
            color: cell.isToday === 1 ? root.clrPrimary : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.fill: parent
                text:         cell.dayText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                font.weight:    Font.Bold
                font.pixelSize: 12
                font.family:    root.fnt
                color: {
                    if (cell.isToday === 1) return root.clrOverPrimary
                    if (cell.bold) return cell.isCurDow ? root.clrText : root.clrOutline
                    if (cell.isToday === 0) return root.clrText
                    return root.clrDimDay
                }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    Timer {
        interval: 60000; repeat: true; running: true
        onTriggered: {
            root.viewingDate        = CalendarLayout.getDateInXMonthsTime(root.monthShift)
            root.calendarLayoutData = CalendarLayout.getCalendarLayout(root.viewingDate, root.monthShift === 0)
            root.calLayout          = root.calendarLayoutData.calendar
            root.currentWeekRow     = root.calendarLayoutData.currentWeekRow
        }
    }
}
