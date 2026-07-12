import QtQuick
import QtQuick.Shapes

// Фон в стиле меню DDLC: решётка кружков (чётные ряды сдвинуты на полшага)
// ползёт по диагонали. Движение реализовано через интегрирование скорости
// покадрово (FrameAnimation), чтобы его можно было плавно затормозить и так
// же плавно разогнать в обратную сторону — это включает режим пасхалки.
Item {
    id: bg

    clip: true

    // Режим «Just Monika»: чёрный фон, красные кружки, разворот движения
    property bool corrupted: false
    // Со 2-й неудачи ровная граница кружка расходится в колючий рваный контур
    property bool rough: false

    // JPEG-артефакты: со 2-й неудачи слой кружков рендерится в уменьшенную
    // текстуру и тянется nearest'ом — получаются блоки как от компрессии
    layer.enabled: rough
    layer.smooth: false
    layer.textureSize: Qt.size(Math.max(1, width / 7), Math.max(1, height / 7))

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

            // Кружок как многоугольник: в норме — гладкая окружность (24-гон),
            // при rough вершины расходятся в хаотичные колючки
            Shape {
                id: dot

                readonly property int row: Math.floor(index / bg.cols)
                readonly property int col: index % bg.cols
                readonly property int verts: 26

                // Стабильные случайные сиды на вершину: радиальный и угловой
                readonly property var seedR: {
                    var a = [];
                    for (var i = 0; i < verts; i++)
                        a.push(Math.random());
                    return a;
                }
                readonly property var seedA: {
                    var a = [];
                    for (var i = 0; i < verts; i++)
                        a.push(Math.random());
                    return a;
                }

                // Степень «колючести»: 0 — окружность, 1 — рваный контур
                property real spikiness: bg.rough ? 1 : 0
                Behavior on spikiness {
                    NumberAnimation {
                        duration: 1800
                        easing.type: Easing.InOutSine
                    }
                }

                x: col * bg.step + (row % 2 === 1 ? bg.step / 2 : 0) - bg.step
                y: row * bg.step - bg.step * 2
                width: bg.dotR * 2
                height: bg.dotR * 2
                // GeometryRenderer вместо CurveRenderer: контур из прямых
                // сегментов, кривые не нужны — это в разы дешевле на ~100 фигур
                // и убирает подтормаживание фона
                preferredRendererType: Shape.GeometryRenderer
                antialiasing: true

                function buildPath() {
                    var pts = [];
                    var c = bg.dotR;
                    var stepA = 2 * Math.PI / verts;
                    for (var i = 0; i <= verts; i++) {
                        var k = i % verts;
                        // угловое дрожание вершины — контур перестаёт быть симметричным
                        var ang = stepA * k + (seedA[k] - 0.5) * stepA * 0.9 * spikiness;
                        // в основном мелкие вмятины, изредка длинный шип наружу
                        var s = seedR[k];
                        var spike = (s > 0.66) ? (0.45 + (s - 0.66) * 2.6) : (-0.22 * s);
                        var rr = bg.dotR * (1 + spike * spikiness);
                        pts.push(Qt.point(c + rr * Math.cos(ang), c + rr * Math.sin(ang)));
                    }
                    return pts;
                }

                ShapePath {
                    fillColor: bg.dotColorNow
                    strokeColor: bg.dotColorNow
                    strokeWidth: 1

                    PathPolyline {
                        // пересчитывается при изменении spikiness (морф окружность→колючка)
                        path: dot.buildPath()
                    }
                }
            }
        }
    }
}
