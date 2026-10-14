import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Window {
    id: root
    visible: true
    width: 460
    height: 860
    minimumWidth: 400
    minimumHeight: 740
    color: "#303446"
    title: backend.running ? fmtMs(backend.remaining_ms) + " · Ganbattea"
           : (backend.sw_running ? fmtSw(backend.sw_elapsed_ms) + " · Ganbattea" : "Ganbattea")

    // ---------- state ----------
    readonly property color accent: backend.total_ms > 0 ? backend.tea_color : "#ca9ee6"
    readonly property int ringSize: Math.min(root.width - 80, 280)
    property var presets: JSON.parse(backend.presets_json || "[]")

    // editor state
    property int mode: 0            // 0 = timer, 1 = stopwatch
    property var laps: JSON.parse(backend.sw_laps_json || "[]")

    property bool editorOpen: false
    property int eIndex: -1
    property int eMin: 3
    property int eSec: 0
    property int eTemp: 90
    property string eColor: "#ca9ee6"
    readonly property var swatches: ["#ca9ee6", "#a6d189", "#e5c890", "#ef9f76", "#e78284", "#f4b8e4", "#81c8be"]

    // ---------- helpers ----------
    function pad(n) { return n < 10 ? "0" + n : "" + n }
    function fmtMs(ms) {
        var s = Math.ceil(ms / 1000)
        return pad(Math.floor(s / 60)) + ":" + pad(s % 60)
    }
    function fmtSec(s) {
        var m = Math.floor(s / 60), r = s % 60
        if (r === 0) return m + " min"
        return m > 0 ? m + "m " + pad(r) + "s" : r + " s"
    }
    function fmtSw(ms) {
        var cs = Math.floor(ms / 10) % 100
        var s = Math.floor(ms / 1000)
        var h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60
        return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s % 60) + "." + pad(cs)
    }
    function mainLabel() {
        if (backend.running) return "Pause"
        if (backend.total_ms > 0 && backend.remaining_ms === 0) return "Brew again"
        if (backend.remaining_ms > 0 && backend.remaining_ms < backend.total_ms) return "Resume"
        return "Start"
    }
    function mainAction() {
        if (backend.running) backend.pause()
        else if (backend.total_ms > 0 && backend.remaining_ms === 0) backend.restart()
        else backend.resume()
    }

    function openEditor(index) {
        eIndex = index
        if (index >= 0) {
            var p = presets[index]
            nameInput.text = p.name
            eMin = Math.floor(p.seconds / 60)
            eSec = p.seconds % 60
            eTemp = p.temp
            eColor = p.color
        } else {
            nameInput.text = ""
            eMin = 3; eSec = 0; eTemp = 90; eColor = swatches[0]
        }
        editorOpen = true
        nameInput.forceActiveFocus()
    }
    function editorSeconds() { return eMin * 60 + eSec }
    function editorName() { return nameInput.text.trim() || "My Tea" }
    function saveEditor() {
        if (editorSeconds() < 1) return
        if (eIndex >= 0) backend.update_preset(eIndex, editorName(), editorSeconds(), eTemp, eColor)
        else backend.add_preset(editorName(), editorSeconds(), eTemp, eColor)
        editorOpen = false
    }
    function brewEditor() {
        if (editorSeconds() < 1) return
        backend.start(editorName(), editorSeconds(), eTemp, eColor)
        editorOpen = false
    }

    // ---------- reusable components ----------
    component Btn: Rectangle {
        id: btn
        property string text: ""
        property bool filled: false
        property bool danger: false
        property color tint: "#ca9ee6"
        property int fontSize: 15
        signal clicked()

        implicitHeight: 48
        implicitWidth: 100
        radius: height / 2
        color: filled ? tint : (area.containsMouse ? "#51576d" : "#414559")
        border.width: filled ? 0 : 1
        border.color: area.containsMouse && !filled ? "#99d1db" : "#626880"
        opacity: enabled ? 1 : 0.35
        scale: area.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: btn.text
            font.pixelSize: btn.fontSize
            font.weight: Font.DemiBold
            color: btn.filled ? "#232634" : (btn.danger ? "#e78284" : "#99d1db")
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component Stepper: ColumnLayout {
        id: st
        property string label: ""
        property int value: 0
        property int from: 0
        property int to: 99
        property int step: 1
        property string unit: ""
        signal moved(int v)
        spacing: 6

        Text { text: st.label; color: "#a5adce"; font.pixelSize: 12; font.weight: Font.Medium }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 12
            color: "#303446"
            border.color: "#51576d"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                Text {
                    text: "−"; color: "#99d1db"; font.pixelSize: 22
                    Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                    opacity: st.value > st.from ? 1 : 0.3
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: st.moved(Math.max(st.from, st.value - st.step)) }
                }
                Text {
                    Layout.fillWidth: true
                    text: st.value + st.unit
                    color: "#c6d0f5"; font.pixelSize: 17; font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "+"; color: "#99d1db"; font.pixelSize: 22
                    Layout.preferredWidth: 36; horizontalAlignment: Text.AlignHCenter
                    opacity: st.value < st.to ? 1 : 0.3
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: st.moved(Math.min(st.to, st.value + st.step)) }
                }
            }
        }
    }

    // ---------- timer tick & completion ----------
    Timer {
        interval: 100
        repeat: true
        running: backend.running
        onTriggered: backend.tick()
    }
    Timer {
        interval: 33
        repeat: true
        running: backend.sw_running
        onTriggered: backend.sw_tick()
    }
    Connections {
        target: backend
        function onFinished() {
            // Bring the window to the front so the alarm popup is seen
            root.show()
            root.raise()
            root.requestActivate()
            root.alert(0)
        }
    }

    // ---------- main screen ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 0
                Text {
                    text: "Ganbattea"
                    color: "#c6d0f5"
                    font.pixelSize: 30
                    font.weight: Font.Bold
                }
                Text {
                    text: "Steep with intention."
                    color: "#99d1db"
                    font.pixelSize: 13
                }
            }
            Item { Layout.fillWidth: true }
            Btn {
                visible: root.mode === 0
                text: "+ New timer"
                implicitWidth: 120
                implicitHeight: 40
                fontSize: 14
                onClicked: root.openEditor(-1)
            }
        }

        // Mode switch: Timer | Stopwatch
        Rectangle {
            id: seg
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 22
            color: "#292c3c"
            border.color: "#414559"

            Rectangle {
                id: pill
                y: 4
                height: parent.height - 8
                width: (parent.width - 8) / 2
                radius: height / 2
                x: 4 + root.mode * width
                color: "#414559"
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: ["Timer", "Stopwatch"]
                    delegate: Item {
                        width: (seg.width - 8) / 2
                        height: seg.height - 8
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: modelData
                                color: root.mode === index ? "#99d1db" : "#a5adce"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            // dot: the other mode is running in the background
                            Rectangle {
                                width: 7; height: 7; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: index === 0 ? root.accent : "#99d1db"
                                visible: index === 0 ? backend.running : backend.sw_running
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mode = index
                        }
                    }
                }
            }
        }

        // ---------- timer view ----------
        ColumnLayout {
            id: timerView
            visible: root.mode === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // Progress ring
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                Layout.preferredWidth: root.ringSize
                Layout.preferredHeight: root.ringSize

                Canvas {
                    id: ring
                    anchors.fill: parent
                    property real progress: backend.total_ms > 0 ? backend.remaining_ms / backend.total_ms : 0
                    property color arc: root.accent
                    onProgressChanged: requestPaint()
                    onArcChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2, r = width / 2 - 16
                        ctx.lineWidth = 12
                        ctx.lineCap = "round"
                        ctx.strokeStyle = "#414559"
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.stroke()
                        if (progress > 0.001) {
                            ctx.strokeStyle = arc
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(progress, 1))
                            ctx.stroke()
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: backend.total_ms > 0 ? root.fmtMs(backend.remaining_ms) : "Ready"
                        color: "#c6d0f5"
                        font.pixelSize: backend.total_ms > 0 ? root.ringSize * 0.2 : root.ringSize * 0.14
                        font.weight: Font.Light
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.StyledText
                        text: backend.total_ms > 0
                              ? backend.tea_name + "  ·  <font color='#99d1db'>" + backend.tea_temp + "°C</font>"
                              : "Pick a tea below"
                        color: backend.total_ms > 0 ? root.accent : "#a5adce"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                }
            }

            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                Btn {
                    text: "Reset"
                    implicitWidth: 80
                    enabled: backend.total_ms > 0
                    onClicked: backend.reset()
                }
                Btn {
                    text: root.mainLabel()
                    filled: true
                    tint: root.accent
                    implicitWidth: 150
                    implicitHeight: 56
                    fontSize: 17
                    enabled: backend.total_ms > 0
                    onClicked: root.mainAction()
                }
                Btn {
                    text: "+30s"
                    implicitWidth: 80
                    enabled: backend.total_ms > 0
                    onClicked: backend.add_time(30)
                }
            }

            // Presets
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Text {
                    text: "Presets"
                    color: "#c6d0f5"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.presets.length + " saved"
                    color: "#a5adce"
                    font.pixelSize: 12
                }
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: flow.height + 8
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: flow
                    width: flick.width
                    spacing: 12

                    Repeater {
                        model: root.presets
                        delegate: Rectangle {
                            id: card
                            width: (flow.width - flow.spacing) / 2
                            height: 84
                            radius: 16
                            color: cardArea.containsMouse ? "#414559" : "#292c3c"
                            border.color: "#414559"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                width: 5; radius: 3
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 14 }
                                color: modelData.color
                            }
                            Column {
                                anchors { left: parent.left; leftMargin: 28; right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter }
                                spacing: 3
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    color: "#c6d0f5"
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    textFormat: Text.StyledText
                                    text: root.fmtSec(modelData.seconds) + "  ·  <font color='#99d1db'>" + modelData.temp + "°C</font>"
                                    color: "#a5adce"
                                    font.pixelSize: 13
                                }
                            }
                            MouseArea {
                                id: cardArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.start(modelData.name, modelData.seconds, modelData.temp, modelData.color)
                            }
                            // edit button
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                anchors { right: parent.right; top: parent.top; margins: 8 }
                                color: editArea.containsMouse ? "#626880" : "transparent"
                                Text { anchors.centerIn: parent; text: "✎"; color: "#a5adce"; font.pixelSize: 15 }
                                MouseArea {
                                    id: editArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openEditor(index)
                                }
                            }
                        }
                    }

                    // "add" card
                    Rectangle {
                        width: (flow.width - flow.spacing) / 2
                        height: 84
                        radius: 16
                        color: "transparent"
                        border.color: addArea.containsMouse ? "#99d1db" : "#626880"
                        border.width: 1.5
                        Text {
                            anchors.centerIn: parent
                            text: "+  Create your own"
                            color: addArea.containsMouse ? "#99d1db" : "#a5adce"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openEditor(-1)
                        }
                    }
                }
            }
        }

        // ---------- stopwatch view ----------
        ColumnLayout {
            id: stopwatchView
            visible: root.mode === 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                Layout.preferredWidth: root.ringSize
                Layout.preferredHeight: root.ringSize

                Canvas {
                    id: swRing
                    anchors.fill: parent
                    // one sweep = one minute
                    property real progress: (backend.sw_elapsed_ms % 60000) / 60000
                    onProgressChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2, r = width / 2 - 16
                        ctx.lineWidth = 12
                        ctx.lineCap = "round"
                        ctx.strokeStyle = "#414559"
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.stroke()
                        if (progress > 0.001) {
                            ctx.strokeStyle = "#99d1db"
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress)
                            ctx.stroke()
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.ringSize - 80
                        horizontalAlignment: Text.AlignHCenter
                        text: root.fmtSw(backend.sw_elapsed_ms)
                        color: "#c6d0f5"
                        font.pixelSize: root.ringSize * 0.17
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 18
                        font.weight: Font.Light
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: backend.sw_running ? "Running" : (backend.sw_elapsed_ms > 0 ? "Paused" : "Ready")
                        color: "#99d1db"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14
                Btn {
                    text: "Reset"
                    implicitWidth: 80
                    enabled: backend.sw_elapsed_ms > 0
                    onClicked: backend.sw_reset()
                }
                Btn {
                    text: backend.sw_running ? "Pause" : (backend.sw_elapsed_ms > 0 ? "Resume" : "Start")
                    filled: true
                    tint: "#99d1db"
                    implicitWidth: 150
                    implicitHeight: 56
                    fontSize: 17
                    onClicked: backend.sw_toggle()
                }
                Btn {
                    text: "Lap"
                    implicitWidth: 80
                    enabled: backend.sw_running
                    onClicked: backend.sw_lap()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Text {
                    text: "Laps"
                    color: "#c6d0f5"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.laps.length + " recorded"
                    color: "#a5adce"
                    font.pixelSize: 12
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: lapList
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    model: root.laps
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        width: lapList.width
                        height: 44
                        radius: 12
                        color: "#292c3c"
                        border.color: "#414559"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            Text {
                                Layout.preferredWidth: 64
                                text: "Lap " + modelData.n
                                color: "#a5adce"
                                font.pixelSize: 14
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "+" + root.fmtSw(modelData.split)
                                color: modelData.kind === "best" ? "#a6d189"
                                     : modelData.kind === "worst" ? "#e78284" : "#c6d0f5"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.fmtSw(modelData.total)
                                color: "#a5adce"
                                font.pixelSize: 13
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.laps.length === 0
                    text: "Press Lap to record split times"
                    color: "#737994"
                    font.pixelSize: 14
                }
            }
        }
    }

    // ---------- editor overlay ----------
    Rectangle {
        anchors.fill: parent
        color: "#CC232634"
        opacity: root.editorOpen ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        MouseArea { anchors.fill: parent; onClicked: root.editorOpen = false }

        Rectangle {
            id: editorCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 400)
            height: editorCol.implicitHeight + 44
            radius: 24
            color: "#292c3c"
            border.color: "#51576d"
            MouseArea { anchors.fill: parent }   // swallow clicks

            ColumnLayout {
                id: editorCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                spacing: 16

                Text {
                    text: root.eIndex >= 0 ? "Edit timer" : "New timer"
                    color: "#c6d0f5"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text { text: "Name"; color: "#a5adce"; font.pixelSize: 12; font.weight: Font.Medium }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 12
                        color: "#303446"
                        border.color: nameInput.activeFocus ? "#99d1db" : "#51576d"
                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.margins: 14
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#c6d0f5"
                            font.pixelSize: 16
                            maximumLength: 24
                            selectByMouse: true
                            clip: true
                            onAccepted: root.saveEditor()
                            Text {
                                visible: nameInput.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "e.g. Sencha, Earl Grey…"
                                color: "#737994"
                                font.pixelSize: 16
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Stepper {
                        Layout.fillWidth: true
                        label: "Minutes"
                        value: root.eMin
                        from: 0; to: 99; step: 1
                        onMoved: root.eMin = v
                    }
                    Stepper {
                        Layout.fillWidth: true
                        label: "Seconds"
                        value: root.eSec
                        from: 0; to: 55; step: 5
                        onMoved: root.eSec = v
                    }
                }

                Stepper {
                    Layout.fillWidth: true
                    label: "Water temperature"
                    value: root.eTemp
                    unit: "°C"
                    from: 60; to: 100; step: 5
                    onMoved: root.eTemp = v
                }

                ColumnLayout {
                    spacing: 8
                    Text { text: "Color"; color: "#a5adce"; font.pixelSize: 12; font.weight: Font.Medium }
                    Row {
                        spacing: 12
                        Repeater {
                            model: root.swatches
                            delegate: Rectangle {
                                width: 32; height: 32; radius: 16
                                color: modelData
                                border.width: root.eColor === modelData ? 3 : 0
                                border.color: "#c6d0f5"
                                scale: swatchArea.containsMouse ? 1.1 : 1
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                MouseArea {
                                    id: swatchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.eColor = modelData
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    Btn {
                        visible: root.eIndex >= 0
                        text: "Delete"
                        danger: true
                        Layout.preferredWidth: 84
                        onClicked: { backend.delete_preset(root.eIndex); root.editorOpen = false }
                    }
                    Btn {
                        text: "Brew now"
                        Layout.fillWidth: true
                        enabled: root.editorSeconds() > 0
                        onClicked: root.brewEditor()
                    }
                    Btn {
                        text: root.eIndex >= 0 ? "Save" : "Save preset"
                        filled: true
                        tint: root.eColor
                        Layout.fillWidth: true
                        enabled: root.editorSeconds() > 0
                        onClicked: root.saveEditor()
                    }
                }
            }
        }
    }

    // ---------- alarm popup (stops the alarm when dismissed) ----------
    Rectangle {
        id: alarmOverlay
        anchors.fill: parent
        color: "#E6232634"
        opacity: backend.alarming ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        // Clicking the backdrop also silences the alarm
        MouseArea { anchors.fill: parent; onClicked: backend.stop_alarm() }

        Rectangle {
            id: alarmCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 380)
            height: alarmCol.implicitHeight + 48
            radius: 28
            color: "#292c3c"
            border.color: root.accent
            border.width: 2
            MouseArea { anchors.fill: parent }   // swallow clicks on the card

            // pulsing glow while the alarm rings
            SequentialAnimation on border.width {
                running: backend.alarming
                loops: Animation.Infinite
                NumberAnimation { to: 5; duration: 500; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 2; duration: 500; easing.type: Easing.InOutQuad }
            }

            Column {
                id: alarmCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 12

                // Teacup drawn with Canvas, so it looks the same everywhere (no emoji font needed)
                Canvas {
                    id: cup
                    width: 96
                    height: 96
                    anchors.horizontalCenter: parent.horizontalCenter
                    property color tea: root.accent
                    onTeaChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"
                        // steam
                        ctx.strokeStyle = tea
                        ctx.lineWidth = 4
                        var xs = [36, 48, 60]
                        for (var i = 0; i < xs.length; i++) {
                            var x = xs[i], dy = (i % 2) * 5
                            ctx.beginPath()
                            ctx.moveTo(x, 36)
                            ctx.bezierCurveTo(x - 7, 28 - dy, x + 7, 20 - dy, x, 10 - dy)
                            ctx.stroke()
                        }
                        // handle
                        ctx.strokeStyle = "#c6d0f5"
                        ctx.lineWidth = 5
                        ctx.beginPath()
                        ctx.arc(74, 58, 9, -Math.PI / 2, Math.PI / 2)
                        ctx.stroke()
                        // cup body
                        ctx.fillStyle = "#c6d0f5"
                        ctx.beginPath()
                        ctx.moveTo(22, 44)
                        ctx.lineTo(74, 44)
                        ctx.bezierCurveTo(74, 70, 62, 78, 48, 78)
                        ctx.bezierCurveTo(34, 78, 22, 70, 22, 44)
                        ctx.closePath()
                        ctx.fill()
                        // tea surface
                        ctx.strokeStyle = tea
                        ctx.lineWidth = 6
                        ctx.beginPath()
                        ctx.moveTo(25, 45)
                        ctx.lineTo(71, 45)
                        ctx.stroke()
                        // saucer
                        ctx.strokeStyle = "#99d1db"
                        ctx.lineWidth = 5
                        ctx.beginPath()
                        ctx.moveTo(24, 87)
                        ctx.lineTo(72, 87)
                        ctx.stroke()
                    }
                    transformOrigin: Item.Bottom
                    SequentialAnimation on rotation {
                        running: backend.alarming
                        loops: Animation.Infinite
                        NumberAnimation { to: -8; duration: 160 }
                        NumberAnimation { to: 8; duration: 320 }
                        NumberAnimation { to: 0; duration: 160 }
                        PauseAnimation { duration: 600 }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Your tea is ready!"
                    color: "#c6d0f5"
                    font.pixelSize: 26
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: backend.tea_name + " · Ganbatte! Enjoy every sip."
                    color: root.accent
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
                Item { width: 1; height: 6 }
                Btn {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 56
                    text: "Stop alarm"
                    filled: true
                    tint: root.accent
                    fontSize: 17
                    onClicked: backend.stop_alarm()
                }
                Btn {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "Brew again"
                    onClicked: backend.restart()
                }
            }
        }
    }
}
