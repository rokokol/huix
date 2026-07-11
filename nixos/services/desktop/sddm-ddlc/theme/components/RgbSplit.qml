import QtQuick
import QtQuick.Effects

// RGB-split для глитча: две подкрашенные копии панели логина,
// разъехавшиеся по горизонтали. Файл грузится через Loader —
// если QtQuick.Effects в greeter недоступен, ломается только он,
// а не вся тема.
Item {
    id: split

    property Item target
    property bool active: false

    visible: active && target !== null

    ShaderEffectSource {
        id: tex

        sourceItem: split.target
        hideSource: false
        visible: false
        live: true
    }

    MultiEffect {
        source: tex
        x: split.target ? split.target.x - 6 : 0
        y: split.target ? split.target.y + 2 : 0
        width: split.target ? split.target.width : 0
        height: split.target ? split.target.height : 0
        colorization: 1
        colorizationColor: "#FF0044"
        opacity: 0.35
    }

    MultiEffect {
        source: tex
        x: split.target ? split.target.x + 6 : 0
        y: split.target ? split.target.y - 2 : 0
        width: split.target ? split.target.width : 0
        height: split.target ? split.target.height : 0
        colorization: 1
        colorizationColor: "#00E5FF"
        opacity: 0.35
    }
}
