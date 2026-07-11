import QtQuick

// Зернистость/шероховатость на фоне: серый шумовой тайл поверх фона,
// слегка дрожит для эффекта «живой» плёнки. Включается со 2-й неудачи.
Item {
    id: grain

    property bool active: false

    clip: true
    opacity: active ? 0.14 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 1600
        }
    }

    Image {
        id: tile

        source: "../assets/noise.png"
        fillMode: Image.Tile
        // Крупнее экрана, чтобы дрожание не открывало края
        x: -40
        y: -40
        width: grain.width + 80
        height: grain.height + 80
    }

    // Дрожание зерна — тайл бесшовный, так что сдвиг незаметно повторяется
    Timer {
        interval: 70
        repeat: true
        running: grain.active
        onTriggered: {
            tile.x = -40 - Math.random() * 40
            tile.y = -40 - Math.random() * 40
        }
    }
}
