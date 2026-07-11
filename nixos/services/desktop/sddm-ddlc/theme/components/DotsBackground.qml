import QtQuick

// Фон в стиле меню DDLC: решётка розовых кружков (чётные ряды сдвинуты
// на полшага) бесконечно ползёт по диагонали. Узор периодичен по x на шаг
// и по y на два шага, поэтому цикл анимации бесшовный.
Item {
    id: bg

    clip: true

    readonly property int step: parseInt(config.dotSpacing) > 0 ? parseInt(config.dotSpacing) : 200
    readonly property int dotR: parseInt(config.dotRadius) > 0 ? parseInt(config.dotRadius) : 36
    readonly property int dur: parseInt(config.scrollDuration) > 0 ? parseInt(config.scrollDuration) : 14000
    readonly property int cols: Math.ceil(width / step) + 3
    readonly property int rows: Math.ceil(height / step) + 5

    Item {
        id: field

        Repeater {
            model: bg.cols * bg.rows

            Rectangle {
                readonly property int row: Math.floor(index / bg.cols)
                readonly property int col: index % bg.cols

                x: col * bg.step + (row % 2 === 1 ? bg.step / 2 : 0) - bg.step
                y: row * bg.step - bg.step * 2
                width: bg.dotR * 2
                height: bg.dotR * 2
                radius: bg.dotR
                color: config.dotColor
            }
        }

        // Дрейф вниз-вправо: от минус-периода к нулю по обеим осям
        ParallelAnimation {
            running: true
            loops: Animation.Infinite

            NumberAnimation {
                target: field
                property: "x"
                from: -bg.step
                to: 0
                duration: bg.dur
            }
            NumberAnimation {
                target: field
                property: "y"
                from: -2 * bg.step
                to: 0
                duration: bg.dur
            }
        }
    }
}
