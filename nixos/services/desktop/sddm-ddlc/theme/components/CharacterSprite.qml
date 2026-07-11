import QtQuick

// Один персонаж: дрейфует влево-вправо в своей полосе [xMin, xMax],
// при наведении подпрыгивает и переключается на excited-стикер.
// В режиме пасхалки (frozen) дрейф останавливается: Моника съезжается
// в центр, остальные растворяются (gone).
Item {
    id: sprite

    property url calmSource
    property url excitedSource
    property real xMin: 0
    property real xMax: 200
    property int driftDuration: 9000
    property bool frozen: false
    property bool isMonika: false
    property real centerTo: 0
    property bool gone: false

    property bool selfExcited: false
    readonly property bool excitedNow: hoverArea.containsMouse || selfExcited

    // Зеркалим спрайт по направлению движения
    property real prevX: x
    property bool movingRight: false
    onXChanged: {
        if (Math.abs(x - prevX) > 0.5) {
            movingRight = x > prevX
            prevX = x
        }
    }

    width: img.width
    height: 150

    opacity: gone ? 0 : 1
    Behavior on opacity {
        NumberAnimation {
            duration: 1600
        }
    }
    visible: opacity > 0

    x: xMin

    SequentialAnimation on x {
        id: drift

        running: !sprite.frozen
        loops: Animation.Infinite

        NumberAnimation {
            to: sprite.xMax
            duration: sprite.driftDuration
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: sprite.xMin
            duration: sprite.driftDuration
            easing.type: Easing.InOutSine
        }
    }

    onFrozenChanged: {
        if (frozen) {
            drift.stop()
            if (isMonika)
                centerAnim.restart()
        } else {
            centerAnim.stop()
            drift.restart()
        }
    }

    NumberAnimation {
        id: centerAnim

        target: sprite
        property: "x"
        to: sprite.centerTo
        duration: 1800
        easing.type: Easing.InOutQuad
    }

    Image {
        id: img

        source: sprite.excitedNow ? sprite.excitedSource : sprite.calmSource
        height: sprite.height
        width: sourceSize.height > 0 ? height * sourceSize.width / sourceSize.height : height
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        mirror: sprite.movingRight
    }

    // Прыжок: вверх резко, вниз с отскоком
    SequentialAnimation {
        id: jump

        NumberAnimation {
            target: img
            property: "y"
            to: -42
            duration: 190
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: img
            property: "y"
            to: 0
            duration: 480
            easing.type: Easing.OutBounce
        }
        onFinished: sprite.selfExcited = false
    }

    function hop(excite) {
        if (jump.running)
            return
        if (excite)
            selfExcited = true
        jump.start()
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: sprite.hop(false)
    }
}
