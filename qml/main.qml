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
    color: "#303446"

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
            if (!controller.alarmLaunch)
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

    Component.onCompleted: {
        if (controller.alarmLaunch && controller.alarmEvent > 0) {
            alarmDialog.open()
            alarmSound.play()
            controller.alarmLaunch = false
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
            color: "#414559"
            radius: 22
            border.color: "#626880"
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: "◷"
                color: "#ca9ee6"
                font.pixelSize: 42
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: controller.alarmEventText
                color: "#c6d0f5"
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
            GradientStop { position: 0.0; color: "#303446" }
            GradientStop { position: 1.0; color: "#292c3c" }
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
                color: "#414559"
                border.color: "#626880"
                Text {
                    anchors.centerIn: parent
                    text: "G"
                    color: "#99d1db"
                    font.pixelSize: 27
                    font.bold: true
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "Ganbattea"
                    color: "#c6d0f5"
                    font.pixelSize: 27
                    font.bold: true
                }
                Text {
                    text: "TIME. FOCUS. FLOW."
                    color: "#949cbb"
                    font.pixelSize: 10
                    font.letterSpacing: 2.6
                    font.bold: true
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                radius: 15
                color: "#292c3c"
                border.color: "#51576d"
                Layout.preferredWidth: 152
                Layout.preferredHeight: 54
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        text: root.currentTime
                        color: "#b5bfe2"
                        font.pixelSize: 20
                        font.family: "monospace"
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: new Date().toLocaleDateString(Qt.locale("en_GB"), "dddd, d MMMM")
                        color: "#838ba7"
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
                        color: root.selectedPage === index ? "#ca9ee6" : "#414559"
                        border.color: root.selectedPage === index ? "#ca9ee6" : "#626880"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.selectedPage === index ? "#303446" : "#a5adce"
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
                color: "#ca9ee6"
            }
            Text {
                Layout.fillWidth: true
                text: controller.statusMessage
                color: "#949cbb"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                text: "GANBATTEA  •  VERSION 0.1"
                color: "#737994"
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
                color: "#414559"
                border.color: "#51576d"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 34
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "COUNTDOWN"
                            color: "#ca9ee6"
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: controller.timerRunning ? "● RUNNING" : "○ READY"
                            color: controller.timerRunning ? "#ca9ee6" : "#949cbb"
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
                        color: "#51576d"
                        border.color: "#626880"
                        border.width: 2
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 12
                            radius: width / 2
                            color: "transparent"
                            border.color: "#626880"
                            border.width: 1
                        }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "TIME REMAINING"
                                color: "#949cbb"
                                font.pixelSize: 9
                                font.letterSpacing: 1.7
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: controller.timerDisplay
                                color: "#c6d0f5"
                                font.family: "monospace"
                                font.pixelSize: 41
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "One step at a time."
                                color: "#949cbb"
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
                            color: "#c6d0f5"
                            font.pixelSize: 19
                            background: Rectangle { color: "#51576d"; radius: 10; border.color: "#737994" }
                        }
                        Text { text: ":"; color: "#838ba7"; font.pixelSize: 22 }
                        TextField {
                            id: minutesInput
                            text: "05"
                            placeholderText: "mm"
                            validator: IntValidator { bottom: 0; top: 59 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            Layout.preferredWidth: 72
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#c6d0f5"
                            font.pixelSize: 19
                            background: Rectangle { color: "#51576d"; radius: 10; border.color: "#737994" }
                        }
                        Text { text: ":"; color: "#838ba7"; font.pixelSize: 22 }
                        TextField {
                            id: secondsInput
                            text: "00"
                            placeholderText: "ss"
                            validator: IntValidator { bottom: 0; top: 59 }
                            inputMethodHints: Qt.ImhDigitsOnly
                            Layout.preferredWidth: 72
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#c6d0f5"
                            font.pixelSize: 19
                            background: Rectangle { color: "#51576d"; radius: 10; border.color: "#737994" }
                        }
                    }
                    Text {
                        text: "Hours     Minutes     Seconds"
                        color: "#838ba7"
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
                            background: Rectangle { radius: 13; color: "#ca9ee6" }
                            contentItem: Text {
                                text: parent.text
                                color: "#303446"
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
                            background: Rectangle { radius: 13; color: "#51576d"; border.color: "#626880" }
                            contentItem: Text {
                                text: parent.text
                                color: "#b5bfe2"
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
                color: "#414559"
                border.color: "#51576d"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 16
                    Text {
                        text: "FOCUS MODE"
                        color: "#ca9ee6"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Text {
                        text: "Make time\nfor what\nmatters."
                        color: "#c6d0f5"
                        font.pixelSize: 29
                        font.bold: true
                    }
                    Text {
                        text: "Start a countdown for your next task, study session, or a well-deserved break."
                        color: "#a5adce"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#51576d" }
                    RowLayout {
                        Text { text: "◷"; color: "#99d1db"; font.pixelSize: 20 }
                        ColumnLayout {
                            spacing: 2
                            Text { text: "Maximum duration"; color: "#b5bfe2"; font.pixelSize: 12; font.bold: true }
                            Text { text: "Up to 7 days"; color: "#949cbb"; font.pixelSize: 11 }
                        }
                    }
                    RowLayout {
                        Text { text: "↻"; color: "#99d1db"; font.pixelSize: 20 }
                        ColumnLayout {
                            spacing: 2
                            Text { text: "Precision timekeeping"; color: "#b5bfe2"; font.pixelSize: 12; font.bold: true }
                            Text { text: "Monotonic Rust clock"; color: "#949cbb"; font.pixelSize: 11 }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "GANBATTE  —  You've got this."
                        color: "#99d1db"
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
                color: "#414559"
                border.color: "#51576d"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 34
                    spacing: 20
                    Text {
                        text: "STOPWATCH"
                        color: "#99d1db"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: controller.stopwatchDisplay
                        color: "#c6d0f5"
                        font.family: "monospace"
                        font.pixelSize: 52
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: controller.stopwatchRunning ? "STOPWATCH RUNNING" : "READY"
                        color: controller.stopwatchRunning ? "#ca9ee6" : "#949cbb"
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
                            background: Rectangle { radius: 13; color: "#ca9ee6" }
                            contentItem: Text { text: parent.text; color: "#303446"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 50
                            text: "Lap"
                            enabled: controller.stopwatchRunning
                            onClicked: controller.lapStopwatch()
                            background: Rectangle { radius: 13; color: "#51576d"; border.color: "#626880" }
                            contentItem: Text { text: parent.text; color: "#b5bfe2"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            Layout.preferredWidth: 112
                            Layout.preferredHeight: 50
                            text: "Reset"
                            onClicked: controller.resetStopwatch()
                            background: Rectangle { radius: 13; color: "#51576d"; border.color: "#626880" }
                            contentItem: Text { text: parent.text; color: "#b5bfe2"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0.8
                radius: 25
                color: "#414559"
                border.color: "#51576d"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "LAP / TIME"; color: "#99d1db"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.7 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.twoDigits(root.lapItems.length); color: "#949cbb"; font.pixelSize: 11 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#51576d" }
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
                            color: index === 0 ? "#414559" : "#292c3c"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                Text { text: "Lap " + root.twoDigits(root.lapItems.length - index); color: "#a5adce"; font.pixelSize: 12; Layout.fillWidth: true }
                                Text { text: modelData; color: "#c6d0f5"; font.family: "monospace"; font.pixelSize: 14; font.bold: true }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.lapItems.length === 0
                            text: "No laps recorded yet."
                            color: "#838ba7"
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        text: "Tip: Select “Lap” to record split times without stopping the stopwatch."
                        color: "#949cbb"
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
                color: "#414559"
                border.color: "#51576d"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 18
                    Text {
                        text: "CREATE NEW ALARM"
                        color: "#99d1db"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.6
                    }
                    Text {
                        text: "Your next appointment\nwith yourself."
                        color: "#c6d0f5"
                        font.pixelSize: 26
                        font.bold: true
                    }
                    Text { text: "TIME"; color: "#99d1db"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
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
                            background: Rectangle { color: "#51576d"; radius: 11; border.color: "#737994" }
                            contentItem: TextInput {
                                text: alarmHour.textFromValue(alarmHour.value, alarmHour.locale)
                                color: "#c6d0f5"
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
                        Text { text: ":"; color: "#949cbb"; font.pixelSize: 28 }
                        SpinBox {
                            id: alarmMinute
                            from: 0
                            to: 59
                            value: 0
                            editable: true
                            Layout.preferredWidth: 100
                            textFromValue: function(value, locale) { return root.twoDigits(value) }
                            background: Rectangle { color: "#51576d"; radius: 11; border.color: "#737994" }
                            contentItem: TextInput {
                                text: alarmMinute.textFromValue(alarmMinute.value, alarmMinute.locale)
                                color: "#c6d0f5"
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
                    Text { text: "LABEL"; color: "#99d1db"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
                    TextField {
                        id: alarmLabel
                        text: "Wake up"
                        placeholderText: "e.g. Meeting, break …"
                        Layout.fillWidth: true
                        color: "#c6d0f5"
                        font.pixelSize: 13
                        background: Rectangle { color: "#51576d"; radius: 11; border.color: "#737994" }
                    }
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        text: "+  Add alarm"
                        onClicked: {
                            controller.addAlarm(alarmHour.value, alarmMinute.value, alarmLabel.text)
                            alarmLabel.text = ""
                        }
                        background: Rectangle { radius: 13; color: "#ca9ee6" }
                        contentItem: Text { text: parent.text; color: "#303446"; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: controller.systemdAlarmsEnabled
                              ? "Scheduled with systemd. Ganbattea can be closed while your user session is active."
                              : "Systemd user timers are unavailable. Keep Ganbattea open for alarms."
                        color: "#949cbb"
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
                color: "#414559"
                border.color: "#51576d"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "YOUR ALARMS"; color: "#99d1db"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.7 }
                        Item { Layout.fillWidth: true }
                        Text { text: root.twoDigits(root.alarmItems.length); color: "#949cbb"; font.pixelSize: 11 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#51576d" }
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
                            color: modelData.enabled ? "#414559" : "#292c3c"
                            border.color: modelData.enabled ? "#626880" : "#51576d"
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
                                        color: modelData.enabled ? "#c6d0f5" : "#949cbb"
                                        font.family: "monospace"
                                        font.pixelSize: 24
                                        font.bold: true
                                    }
                                    Text {
                                        text: modelData.label
                                        color: "#949cbb"
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
                                    background: Rectangle { radius: 11; color: "#51576d" }
                                    contentItem: Text { text: parent.text; color: "#a5adce"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.alarmItems.length === 0
                            text: "No alarms set yet.\nAdd your first one on the left."
                            color: "#838ba7"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
