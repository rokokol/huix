import QtQuick

// Кнопка входа: текст «OK» с толстой фиолетовой обводкой на прозрачном
// фоне, как кнопка в игре. Обводка — восемь сдвинутых копий текста,
// потому что Text.Outline даёт слишком тонкую линию.
Item {
    id: btn

    signal clicked()

    readonly property string label: "OK"
    readonly property color outline: config.okOutline

    width: okText.implicitWidth + 28
    height: okText.implicitHeight + 12

    scale: area.pressed ? 0.92 : (area.containsMouse ? 1.1 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutQuad
        }
    }

    Repeater {
        model: [[-3, 0], [3, 0], [0, -3], [0, 3], [-2, -2], [2, -2], [-2, 2], [2, 2]]

        Text {
            x: (btn.width - implicitWidth) / 2 + modelData[0]
            y: (btn.height - implicitHeight) / 2 + modelData[1]
            text: btn.label
            font.family: config.font
            font.pixelSize: 44
            font.bold: true
            color: btn.outline
        }
    }

    Text {
        id: okText

        anchors.centerIn: parent
        text: btn.label
        font.family: config.font
        font.pixelSize: 44
        font.bold: true
        color: "white"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        // PointingHandCursor — в нашей курсорной теме это глитчнутая голова Сайори
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
