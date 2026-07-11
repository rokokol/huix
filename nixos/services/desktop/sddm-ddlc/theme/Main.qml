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

    // Фон реагирует на неудачи: 1-я и 2-я слегка затемняют, 3-я — чёрный
    color: justMonika ? "black" : Qt.darker(config.bgColor, 1 + failCount * 0.13)
    Behavior on color {
        ColorAnimation {
            duration: 3000
        }
    }

    property int failCount: 0
    readonly property bool justMonika: failCount >= 3

    // Реакция на неверный пароль. Вызывается из onLoginFailed и по F8:
    // в test-mode демона нет и sddm.loginFailed не приходит в принципе,
    // так что глитч и пасхалку иначе не проверить
    function showFail() {
        root.failCount++
        forgiveTimer.restart()
        panel.clearPassword()
        glitch.trigger()
    }

    DotsBackground {
        anchors.fill: parent
        z: 0
        corrupted: root.justMonika
    }

    // Часы
    Text {
        id: clockText

        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 30
        font.family: config.font
        font.pixelSize: 44
        color: config.deepPink
        text: Qt.formatTime(new Date(), "hh:mm")
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

        // Переключатель раскладки: клик листает по кругу.
        // Прячется, если раскладок нет (например, в test-mode)
        Rectangle {
            readonly property bool hasLayouts: typeof keyboard !== "undefined" && keyboard.layouts.length > 0

            visible: hasLayouts
            width: 44
            height: 44
            radius: width / 2
            color: layoutArea.containsMouse ? config.accentPink : "white"
            border.color: config.accentPink
            border.width: 2
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Text {
                anchors.centerIn: parent
                font.family: config.font
                font.pixelSize: 14
                color: layoutArea.containsMouse ? "white" : config.deepPink
                text: parent.hasLayouts
                      ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase()
                      : ""
            }

            MouseArea {
                id: layoutArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
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

    // Окошки Just Monika поверх всего, кроме глитча
    MonikaPopups {
        z: 6
        anchors.fill: parent
        active: root.justMonika
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
            root.showFail()
        }

        function onLoginSucceeded() {
            root.failCount = 0
        }
    }

    // F8 — предпросмотр глитча (три нажатия — пасхалка)
    Shortcut {
        sequence: "F8"
        context: Qt.ApplicationShortcut
        onActivated: root.showFail()
    }
}
