import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia
import de.ganbattea.app 1.0

ApplicationWindow {
    id: root
    width: 1120
    height: 780
    minimumWidth: 760
    minimumHeight: 650
    visible: true
    title: "Ganbattea – Take Control of Your Time"
    color: "#0B1020"

    property int selectedPage: 0
    property string currentTime: Qt.formatTime(new Date(), "HH:mm:ss")
    property var alarmItems: JSON.parse(controller.alarmsJson)
    property var lapItems: JSON.parse(controller.stopwatchLapsJson)

    function twoDigits(value) {
        return value < 10 ? "0" + value : value.toString()
    }

    Ganbattea {
        id: controller
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: controller.timerTick()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.currentTime = Qt.formatTime(new Date(), "HH:mm:ss")
            controller.checkAlarms()
        }
    }

    SoundEffect {
        id: alarmSound
        source: "qrc:/qt/qml/de/ganbattea/app/assets/alarm.wav"
        loops: SoundEffect.Infinite
        volume: 0.8
    }

    Connections {
        target: controller
        function onAlarmEventChanged() {
            alarmDialog.open()
            alarmSound.play()
        }
    }

    Dialog {
        id: alarmDialog
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        modal: true
        title: "Ganbattea – Alarm"
        standardButtons: Dialog.Ok
        width: 380
        onClosed: alarmSound.stop()
        background: Rectangle {
            color: "#18223A"
            radius: 22
            border.color: "#34415E"
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: "◷"
                color: "#9BE7D8"
                font.pixelSize: 42
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: controller.alarmEventText
                color: "#F4F7FF"
                font.pixelSize: 18
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0B1020" }
            GradientStop { position: 1.0; color: "#111B30" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 42
        anchors.rightMargin: 42
        anchors.topMargin: 28
        anchors.bottomMargin: 24
        spacing: 24

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                width: 52
                height: 52
                radius: 17
                color: "#263D52"
                border.color: "#3B6B74"
                Text {
                    anchors.centerIn: parent
                    text: "G"
                    color: "#A7F0DE"
                    font.pixelSize: 27
                    font.bold: true
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "Ganbattea"
                    color: "#F4F7FF"
                    font.pixelSize: 27
                    font.bold: true
                }
                Text {
                    text: "ZEIT. FOKUS. FLOW."
                    color: "#8291AD"
                    font.pixelSize: 10
                    font.letterSpacing: 2.6
                    font.bold: true
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                radius: 15
                color: "#141E33"
                border.color: "#26344E"
                Layout.preferredWidth: 152
                Layout.preferredHeight: 54
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        text: root.currentTime
                        color: "#C9D5E9"
                        font.pixelSize: 20
                        font.family: "monospace"
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: new Date().toLocaleDateString(Qt.locale("en_GB"), "dddd, d MMMM")
                        color: "#74839F"
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: ["Timer", "Stopwatch", "Alarms"]
                delegate: Button {
                    required property int index
                    required property string modelData
                    text: modelData
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 44
                    onClicked: root.selectedPage = index
                    background: Rectangle {
                        radius: 13
                        color: root.selectedPage === index ? "#9BE7D8" : "#151F34"
                        border.color: root.selectedPage === index ? "#9BE7D8" : "#2A3853"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.selectedPage === index ? "#10242B" : "#A9B6CC"
                        font.pixelSize: 14
                        font.bold: root.selectedPage === index
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.selectedPage === 0 ? timerPage : (root.selectedPage === 1 ? stopwatchPage : alarmPage)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                width: 7
                height: 7
                radius: 4
                color: "#9BE7D8"
            }
            Text {
                Layout.fillWidth: true
                text: controller.statusMessage
                color: "#8190AA"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                text: "GANBATTEA  •  VERSION 0.1"
                color: "#53627C"
                font.pixelSize: 9
                font.letterSpacing: 1.2
            }
        }
    }

    Component {
        id: timerPage
        RowLayout {
            spacing: 18

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.25
                radius: 25
                color: "#141F35"
                border.color: "#263650"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 34
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "COUNTDOWN"
                            color: "#9BE7D8"
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: controller.timerRunning ? "● RUNNING" : "○ READY"
                            color: controller.timerRunning ? "#9BE7D8" : "#8190AA"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 270
                        height: 270
                        radius: 135
                        color: "#172944"
                        border.color: "#315968"
                        border.width: 2
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 12
                            radius: width / 2
                            color: "transparent"
                            border.color: "#263B57"
                            border.width: 1
                        }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "TIME REMAINING"
                                color: "#8198B1"
                                font.pixelSize: 9
                                font.letterSpacing: 1.7
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: controller.timerDisplay
                                color: "#F2F7FF"
                                font.family: "monospace"
                                font.pixelSize: 41
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "One step at a time."
                                color: "#8C9CB5"
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        TextField {
                            id: hoursInput
                            text: "00"
                            placeholderText: "hh"
                            validator: IntValidator { bottom: 0; top: 168 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            Layout.preferredWidth: 72
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#F4F7FF"
                            font.pixelSize: 19
                            background: Rectangle { color: "#202D47"; radius: 10; border.color: "#344663" }
                        }
                        Text { text: ":"; color: "#71839F"; font.pixelSize: 22 }
                        TextField {
                            id: minutesInput
                            text: "05"
                            placeholderText: "mm"
                            validator: IntValidator { bottom: 0; top: 59 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            Layout.preferredWidth: 72
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#F4F7FF"
                            font.pixelSize: 19
                            background: Rectangle { color: "#202D47"; radius: 10; border.color: "#344663" }
                        }
                        Text { text: ":"; color: "#71839F"; font.pixelSize: 22 }
                        TextField {
                            id: secondsInput
                            text: "00"
                            placeholderText: "ss"
                            validator: IntValidator { bottom: 0; top: 59 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            Layout.preferredWidth: 72
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#F4F7FF"
                            font.pixelSize: 19
                            background: Rectangle { color: "#202D47"; radius: 10; border.color: "#344663" }
                        }
                    }
                    Text {
                        text: "Hours     Minutes     Seconds"
                        color: "#73839E"
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            text: controller.timerRunning ? "Pause" : "Start"
                            onClicked: {
                                if (controller.timerRunning) {
                                    controller.pauseTimer()
                                } else {
                                    if (controller.timerRemainingMs <= 0) {
                                        var h = parseInt(hoursInput.text) || 0
                                        var m = parseInt(minutesInput.text) || 0
                                        var s = parseInt(secondsInput.text) || 0
                                        controller.setTimer(h * 3600 + m * 60 + s)
                                    }
                                    controller.startTimer()
                                }
                            }
                            background: Rectangle { radius: 13; color: "#9BE7D8" }
                            contentItem: Text {
                                text: parent.text
                                color: "#10242B"
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Button {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 48
                            text: "Reset"
                            onClicked: {
                                var h = parseInt(hoursInput.text) || 0
                                var m = parseInt(minutesInput.text) || 0
                                var s = parseInt(secondsInput.text) || 0
                                controller.setTimer(h * 3600 + m * 60 + s)
                            }
                            background: Rectangle { radius: 13; color: "#263650"; border.color: "#3B4D6B" }
                            contentItem: Text {
                                text: parent.text
                                color: "#C1CDE0"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0.8
                radius: 25
                color: "#141F35"
                border.color: "#263650"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 16
                    Text {
                        text: "FOCUS MODE"
                        color: "#9BE7D8"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Text {
                        text: "Make time\nfor what\nmatters."
                        color: "#F0F4FC"
                        font.pixelSize: 29
                        font.bold: true
                    }
                    Text {
                        text: "Start a countdown for your next task, study session, or a well-deserved break."
                        color: "#98A7BF"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#293852" }
                    RowLayout {
                        Text { text: "◷"; color: "#9BE7D8"; font.pixelSize: 20 }
                        ColumnLayout {
                            spacing: 2
                            Text { text: "Maximum duration"; color: "#DDE6F5"; font.pixelSize: 12; font.bold: true }
                            Text { text: "Up to 7 days"; color: "#8292AB"; font.pixelSize: 11 }
                        }
                    }
                    RowLayout {
                        Text { text: "↻"; color: "#9BE7D8"; font.pixelSize: 20 }
                        ColumnLayout {
                            spacing: 2
                            Text { text: "Precision timekeeping"; color: "#DDE6F5"; font.pixelSize: 12; font.bold: true }
                            Text { text: "Monotonic Rust clock"; color: "#8292AB"; font.pixelSize: 11 }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "GANBATTE  —  You've got this."
                        color: "#A4E5D9"
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }
        }
    }

    Component {
        id: stopwatchPage
        RowLayout {
            spacing: 18
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.2
                radius: 25
                color: "#141F35"
                border.color: "#263650"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 34
                    spacing: 20
                    Text {
                        text: "STOPWATCH"
                        color: "#9BE7D8"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: controller.stopwatchDisplay
                        color: "#F2F7FF"
                        font.family: "monospace"
                        font.pixelSize: 52
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: controller.stopwatchRunning ? "STOPWATCH RUNNING" : "BEREIT"
                        color: controller.stopwatchRunning ? "#9BE7D8" : "#8190AA"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.8
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            text: controller.stopwatchRunning ? "Pause" : "Start"
                            onClicked: controller.stopwatchRunning ? controller.pauseStopwatch() : controller.startStopwatch()
                            background: Rectangle { radius: 13; color: "#9BE7D8" }
                            contentItem: Text { text: parent.text; color: "#10242B"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 50
                            text: "Lap"
                            enabled: controller.stopwatchRunning
                            onClicked: controller.lapStopwatch()
                            background: Rectangle { radius: 13; color: "#263650"; border.color: "#3B4D6B" }
                            contentItem: Text { text: parent.text; color: "#C1CDE0"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 50
                            text: "Reset"
                            onClicked: controller.resetStopwatch()
                            background: Rectangle { radius: 13; color: "#263650"; border.color: "#3B4D6B" }
                            contentItem: Text { text: parent.text; color: "#C1CDE0"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0.8
                radius: 25
                color: "#141F35"
                border.color: "#263650"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "LAP / TIME"; color: "#9BE7D8"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.7 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.twoDigits(root.lapItems.length); color: "#8292AB"; font.pixelSize: 11 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#293852" }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 7
                        model: root.lapItems.slice().reverse()
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            width: ListView.view.width
                            height: 42
                            radius: 10
                            color: index === 0 ? "#1D3444" : "#19263D"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                Text { text: "Lap " + root.twoDigits(root.lapItems.length - index); color: "#9BAAC0"; font.pixelSize: 12; Layout.fillWidth: true }
                                Text { text: modelData; color: "#E6EDF8"; font.family: "monospace"; font.pixelSize: 14; font.bold: true }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.lapItems.length === 0
                            text: "No laps recorded yet."
                            color: "#74849E"
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        text: "Tip: Select “Lap” to record split times without stopping the stopwatch."
                        color: "#8292AB"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    Component {
        id: alarmPage
        RowLayout {
            spacing: 18
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0.9
                radius: 25
                color: "#141F35"
                border.color: "#263650"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 18
                    Text {
                        text: "CREATE NEW ALARM"
                        color: "#9BE7D8"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.6
                    }
                    Text {
                        text: "Your next appointment\nwith yourself."
                        color: "#F0F4FC"
                        font.pixelSize: 26
                        font.bold: true
                    }
                    Text { text: "TIME"; color: "#91A1BA"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
                    RowLayout {
                        spacing: 10
                        SpinBox {
                            id: alarmHour
                            from: 0
                            to: 23
                            value: 7
                            editable: true
                            Layout.preferredWidth: 100
                            textFromValue: function(value, locale) { return root.twoDigits(value) }
                            background: Rectangle { color: "#202D47"; radius: 11; border.color: "#344663" }
                            contentItem: TextInput {
                                text: alarmHour.textFromValue(alarmHour.value, alarmHour.locale)
                                color: "#F4F7FF"
                                font.pixelSize: 25
                                font.family: "monospace"
                                horizontalAlignment: Qt.AlignHCenter
                                verticalAlignment: Qt.AlignVCenter
                                readOnly: !alarmHour.editable
                                validator: alarmHour.validator
                                inputMethodHints: Qt.ImhDigitsOnly
                                onTextEdited: alarmHour.value = alarmHour.valueFromText(text, alarmHour.locale)
                            }
                        }
                        Text { text: ":"; color: "#8B9BB4"; font.pixelSize: 28 }
                        SpinBox {
                            id: alarmMinute
                            from: 0
                            to: 59
                            value: 0
                            editable: true
                            Layout.preferredWidth: 100
                            textFromValue: function(value, locale) { return root.twoDigits(value) }
                            background: Rectangle { color: "#202D47"; radius: 11; border.color: "#344663" }
                            contentItem: TextInput {
                                text: alarmMinute.textFromValue(alarmMinute.value, alarmMinute.locale)
                                color: "#F4F7FF"
                                font.pixelSize: 25
                                font.family: "monospace"
                                horizontalAlignment: Qt.AlignHCenter
                                verticalAlignment: Qt.AlignVCenter
                                readOnly: !alarmMinute.editable
                                validator: alarmMinute.validator
                                inputMethodHints: Qt.ImhDigitsOnly
                                onTextEdited: alarmMinute.value = alarmMinute.valueFromText(text, alarmMinute.locale)
                            }
                        }
                    }
                    Text { text: "LABEL"; color: "#91A1BA"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
                    TextField {
                        id: alarmLabel
                        text: "Wake up"
                        placeholderText: "e.g. Meeting, break …"
                        Layout.fillWidth: true
                        color: "#F4F7FF"
                        font.pixelSize: 13
                        background: Rectangle { color: "#202D47"; radius: 11; border.color: "#344663" }
                    }
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        text: "+  Add alarm"
                        onClicked: {
                            controller.addAlarm(alarmHour.value, alarmMinute.value, alarmLabel.text)
                            alarmLabel.text = ""
                        }
                        background: Rectangle { radius: 13; color: "#9BE7D8" }
                        contentItem: Text { text: parent.text; color: "#10242B"; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Alarms are stored locally. Ganbattea must be open when an alarm is due."
                        color: "#8292AB"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.15
                radius: 25
                color: "#141F35"
                border.color: "#263650"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "YOUR ALARMS"; color: "#9BE7D8"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.7 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.twoDigits(root.alarmItems.length); color: "#8292AB"; font.pixelSize: 11 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#293852" }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 9
                        model: root.alarmItems
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width
                            height: 76
                            radius: 13
                            color: modelData.enabled ? "#1B2B43" : "#182238"
                            border.color: modelData.enabled ? "#2C4960" : "#26334A"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 10
                                spacing: 12
                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Text {
                                        text: root.twoDigits(modelData.hour) + ":" + root.twoDigits(modelData.minute)
                                        color: modelData.enabled ? "#F0F5FF" : "#8190A8"
                                        font.family: "monospace"
                                        font.pixelSize: 24
                                        font.bold: true
                                    }
                                    Text {
                                        text: modelData.label
                                        color: "#91A1BA"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                Switch {
                                    checked: modelData.enabled
                                    onToggled: controller.toggleAlarm(index, checked)
                                }
                                Button {
                                    text: "×"
                                    Layout.preferredWidth: 38
                                    Layout.preferredHeight: 38
                                    onClicked: controller.removeAlarm(index)
                                    background: Rectangle { radius: 11; color: "#2A354B" }
                                    contentItem: Text { text: parent.text; color: "#AAB7CB"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.alarmItems.length === 0
                            text: "No alarms set yet.\nAdd your first one on the left."
                            color: "#74849E"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
