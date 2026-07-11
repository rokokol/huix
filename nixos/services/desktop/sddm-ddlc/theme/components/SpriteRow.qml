import QtQuick

// Ряд из четырёх девочек над нижними кнопками. Каждая дрейфует строго
// в своей полосе (полосы не пересекаются и не заходят на зоны углов),
// поэтому спрайты не выходят за экран и не наезжают ни друг на друга,
// ни на элементы интерфейса.
Item {
    id: row

    property bool justMonika: false
    // Ширина зон нижних углов (кнопки сессии слева, питания справа)
    property real sideReserve: 240

    height: 120

    readonly property var girls: ["sayori", "monika", "natsuki", "yuri"]

    Repeater {
        id: rep

        model: row.girls

        CharacterSprite {
            readonly property real bandW: Math.max(150, (row.width - 2 * row.sideReserve) / row.girls.length)

            calmSource: "../assets/" + modelData + "-sticker-calm.png"
            excitedSource: "../assets/" + modelData + "-sticker-excited.png"
            isMonika: modelData === "monika"
            xMin: row.sideReserve + index * bandW + 10
            xMax: Math.max(xMin + 10, row.sideReserve + (index + 1) * bandW - width - 10)
            driftDuration: 7000 + index * 1700
            frozen: row.justMonika
            centerTo: (row.width - width) / 2
            gone: row.justMonika && modelData !== "monika"
        }
    }

    // Иногда случайный персонаж подпрыгивает сам — экран живёт и без мыши
    Timer {
        id: idleHops

        interval: 6000
        repeat: true
        running: !row.justMonika
        onTriggered: {
            interval = 6000 + Math.floor(Math.random() * 9000)
            var it = rep.itemAt(Math.floor(Math.random() * rep.count))
            if (it && !it.gone)
                it.hop(true)
        }
    }
}
