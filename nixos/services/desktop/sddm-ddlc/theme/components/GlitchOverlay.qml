import QtQuick

// Глитч при неверном пароле: тряска панели, RGB-split, случайные
// «сканлайны» и мигающий искажённый текст. Всё гаснет через ~0.8 с.
Item {
    id: overlay

    property Item target
    readonly property bool rgbSplit: String(config.glitchRgbSplit) === "true"
    property bool active: false

    visible: active

    function trigger() {
        active = true
        stopTimer.restart()
    }

    // Тряска панели и пересев шума каждые 40 мс
    Timer {
        id: shakeTimer

        interval: 40
        repeat: true
        running: overlay.active
        onTriggered: {
            if (overlay.target) {
                overlay.target.anchors.horizontalCenterOffset = Math.round((Math.random() - 0.5) * 14)
                overlay.target.anchors.verticalCenterOffset = Math.round((Math.random() - 0.5) * 10)
            }
            noise.reseed()
            corrupt.reseed()
        }
    }

    Timer {
        id: stopTimer

        interval: 800
        onTriggered: {
            overlay.active = false
            if (overlay.target) {
                overlay.target.anchors.horizontalCenterOffset = 0
                overlay.target.anchors.verticalCenterOffset = 0
            }
        }
    }

    // RGB-split вынесен в отдельный файл: при недоступном QtQuick.Effects
    // сломается только этот Loader, остальной глитч продолжит работать
    Loader {
        anchors.fill: parent
        source: overlay.rgbSplit ? "RgbSplit.qml" : ""
        onLoaded: {
            item.target = overlay.target
            item.active = Qt.binding(function() { return overlay.active })
        }
    }

    // Случайные горизонтальные полосы
    Item {
        id: noise

        anchors.fill: parent

        function reseed() {
            for (var i = 0; i < lines.count; i++)
                lines.itemAt(i).reseed()
        }

        Repeater {
            id: lines

            model: 14

            Rectangle {
                function reseed() {
                    y = Math.random() * overlay.height
                    height = 1 + Math.random() * 5
                    opacity = 0.25 + Math.random() * 0.5
                    color = Math.random() < 0.5 ? "#FF9AD0" : (Math.random() < 0.5 ? "#66F2F2" : "#333344")
                    x = -20 + Math.random() * 40
                }

                width: overlay.width + 40
                Component.onCompleted: reseed()
            }
        }
    }

    // Мигающий искажённый текст в духе «глитчей» игры
    Text {
        id: corrupt

        readonly property var pool: ["J̷u̷s̸t̶ ̸M̵o̷n̸i̵k̷a̶.", "Ĵ̶͔u̸̥͠s̵̼̆t̷̠̕ ̶̙͝M̶̼̚o̸͙͐n̷̙͋i̶͖͛k̵̳̎a̷͉͝", "░▒▓ JUST M0N1KA ▓▒░", "no password. only monika.", "̷̛͘͝?̸?̵?̶?̷?̸?̵?̶?̷"]

        function reseed() {
            if (Math.random() < 0.25)
                text = pool[Math.floor(Math.random() * pool.length)]
            visible = Math.random() < 0.8
            anchors.horizontalCenterOffset = Math.round((Math.random() - 0.5) * 30)
        }

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        text: pool[0]
        font.family: config.font
        font.pixelSize: 34
        color: config.errorRed
        style: Text.Outline
        styleColor: "#40000000"
    }
}
