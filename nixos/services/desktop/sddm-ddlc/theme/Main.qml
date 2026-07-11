import QtQuick
import "components"

// Тема SDDM в стиле Doki Doki Literature Club.
// Слои снизу вверх: фон с кружочками → затемнение пасхалки → часы/цитата →
// спрайты девочек → панель логина → нижние углы → глитч поверх всего.
Rectangle {
    id: root

    // Размеры по умолчанию для test-mode; в реальном greeter их задаёт SDDM
    width: 1280
    height: 720
    color: config.bgColor

    property int failCount: 0
    readonly property bool justMonika: failCount >= 3

    readonly property var quotes: [
        "Every day, I imagine a future where I can be with you.",
        "The Literature Club is truly a place where no bad thing has ever happened.",
        "Don't judge a book by its cover!",
        "It's time to work on your poem!",
        "Poems are like a vessel for expressing your feelings.",
        "Ehehe~",
        "Okay, everyone! It's time to make today's poem!",
        "Doki Doki!"
    ]

    DotsBackground {
        anchors.fill: parent
        z: 0
    }

    // Лёгкое затемнение, когда остаётся одна Моника
    Rectangle {
        anchors.fill: parent
        z: 1
        color: "#1A0A12"
        opacity: root.justMonika ? 0.22 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 1500
            }
        }
    }

    // Часы и случайная цитата из игры
    Column {
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        spacing: 6

        Text {
            id: clockText

            anchors.horizontalCenter: parent.horizontalCenter
            font.family: config.font
            font.pixelSize: 44
            color: config.deepPink
            text: Qt.formatTime(new Date(), "hh:mm")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: config.font
            font.pixelSize: 17
            color: config.textDark
            opacity: 0.8
            text: root.quotes[Math.floor(Math.random() * root.quotes.length)]
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
    }

    SpriteRow {
        id: sprites

        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Спрайты стоят над нижними кнопками и не пересекаются с ними
        anchors.bottomMargin: 88
        justMonika: root.justMonika
        sideReserve: Math.max(leftControls.width, rightControls.width) + 40
    }

    // Надпись пасхалки над Моникой
    Text {
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: sprites.top
        anchors.bottomMargin: 20
        text: "Just Monika."
        font.family: config.font
        font.pixelSize: 40
        color: config.textDark
        opacity: root.justMonika ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 1800
            }
        }
    }

    LoginPanel {
        id: panel

        z: 3
        anchors.centerIn: parent
        onLoginRequested: function(username, password) {
            sddm.login(username, password, sessions.currentIndex)
        }
    }

    // Нижний левый угол: сессия и раскладка
    Row {
        id: leftControls

        z: 4
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 12

        SessionSelector {
            id: sessions
        }

        // Индикатор текущей раскладки клавиатуры
        Rectangle {
            width: 44
            height: 44
            radius: width / 2
            color: "white"
            border.color: config.accentPink
            border.width: 2

            Text {
                anchors.centerIn: parent
                font.family: config.font
                font.pixelSize: 14
                color: config.deepPink
                text: (typeof keyboard !== "undefined" && keyboard.layouts.length > 0)
                      ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase()
                      : "?"
            }
        }
    }

    // Нижний правый угол: сон, перезагрузка, выключение
    Row {
        id: rightControls

        z: 4
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 12

        PowerButton {
            glyph: ""
            visible: sddm.canSuspend
            onActivated: sddm.suspend()
        }
        PowerButton {
            glyph: ""
            visible: sddm.canReboot
            onActivated: sddm.reboot()
        }
        PowerButton {
            glyph: ""
            visible: sddm.canPowerOff
            onActivated: sddm.powerOff()
        }
    }

    GlitchOverlay {
        id: glitch

        z: 10
        anchors.fill: parent
        target: panel
    }

    // Пасхалка сбрасывается сама через минуту тишины
    Timer {
        id: forgiveTimer

        interval: 60000
        onTriggered: root.failCount = 0
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.failCount++
            forgiveTimer.restart()
            panel.clearPassword()
            panel.showError(root.justMonika ? "Just Monika." : "Wrong password!")
            glitch.trigger()
        }

        function onLoginSucceeded() {
            root.failCount = 0
        }
    }
}
