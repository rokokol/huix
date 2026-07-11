import QtQuick

// Фон в стиле меню DDLC: решётка кружков (чётные ряды сдвинуты на полшага)
// ползёт по диагонали. Движение реализовано через интегрирование скорости
// покадрово (FrameAnimation), чтобы его можно было плавно затормозить и так
// же плавно разогнать в обратную сторону — это включает режим пасхалки.
Item {
    id: bg

    clip: true

    // Режим «Just Monika»: чёрный фон, красные кружки, разворот движения
    property bool corrupted: false

    readonly property int step: parseInt(config.dotSpacing) > 0 ? parseInt(config.dotSpacing) : 165
    readonly property int dotR: parseInt(config.dotRadius) > 0 ? parseInt(config.dotRadius) : 44
    readonly property int scrollMs: parseInt(config.scrollDuration) > 0 ? parseInt(config.scrollDuration) : 14000
    readonly property int cols: Math.ceil(width / step) + 3
    readonly property int rows: Math.ceil(height / step) + 5

    // Базовая скорость (px/сек) при vel = 1; vel — множитель и знак направления
    readonly property real baseVel: step * 1000 / scrollMs
    property real vel: 1
    property real pos: 0

    property color dotColorNow: config.dotColor
    Behavior on dotColorNow {
        ColorAnimation {
            duration: 3000
        }
    }

    onCorruptedChanged: {
        dotColorNow = corrupted ? config.corruptDot : config.dotColor
        velAnim.stop()
        if (corrupted)
            velAnim.start()
        else
            vel = 1
    }

    function wrapMod(v, m) {
        return ((v % m) + m) % m;
    }

    // Покадровый интегратор смещения
    FrameAnimation {
        running: true
        onTriggered: bg.pos += bg.baseVel * bg.vel * frameTime
    }

    // Плавно: сначала затухание движения до нуля, затем разгон в обратную сторону
    SequentialAnimation {
        id: velAnim

        NumberAnimation {
            target: bg
            property: "vel"
            to: 0
            duration: 2600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: bg
            property: "vel"
            to: -1
            duration: 2600
            easing.type: Easing.InOutSine
        }
    }

    Item {
        id: field

        // x повторяется с периодом step, y — с периодом 2·step (из-за сдвига рядов)
        x: bg.wrapMod(bg.pos, bg.step) - bg.step
        y: bg.wrapMod(bg.pos * 2, bg.step * 2) - bg.step * 2

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
                color: bg.dotColorNow
            }
        }
    }
}
