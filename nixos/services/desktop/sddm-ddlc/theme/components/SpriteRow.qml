import QtQuick

// Ряд из четырёх девочек над нижними кнопками. Каждая дрейфует строго
// в своей полосе (полосы не пересекаются и не заходят на зоны углов),
// поэтому спрайты не выходят за экран и не наезжают ни друг на друга,
// ни на элементы интерфейса.
Item {
    id: row

    property int failCount: 0
    readonly property bool justMonika: failCount >= 3
    // Ширина зон нижних углов (кнопки сессии слева, питания справа)
    property real sideReserve: 240

    height: 150

    readonly property var girls: ["sayori", "monika", "natsuki", "yuri"]

    Repeater {
        id: rep

        model: row.girls

        CharacterSprite {
            readonly property real bandW: Math.max(150, (row.width - 2 * row.sideReserve) / row.girls.length)

            calmSource: "../assets/" + modelData + "-sticker-calm.png"
            excitedSource: "../assets/" + modelData + "-sticker-excited.png"
            // Юри со 2-й неудачи переключается на искажённые спрайты
            distortedCalmSource: modelData === "yuri" ? "../assets/yuri-sticker-distorted-calm.png" : ""
            distortedExcitedSource: modelData === "yuri" ? "../assets/yuri-sticker-distorted-excited.png" : ""
            distorted: modelData === "yuri" && row.failCount >= 2
            isMonika: modelData === "monika"
            xMin: row.sideReserve + index * bandW + 10
            xMax: Math.max(xMin + 10, row.sideReserve + (index + 1) * bandW - width - 10)
            driftDuration: 4800 + index * 1100
            frozen: row.justMonika
            centerTo: (row.width - width) / 2
            // Сайори уходит после 1-й неудачи; при пасхалке остаётся одна Моника
            gone: (modelData === "sayori" && row.failCount >= 1)
                  || (row.justMonika && modelData !== "monika")
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
