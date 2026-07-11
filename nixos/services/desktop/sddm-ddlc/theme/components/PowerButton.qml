import QtQuick

// Круглая кнопка питания/сессии в нижнем углу: белая с розовой рамкой,
// при наведении заливается розовым и чуть подрастает.
Rectangle {
    id: btn

    property string glyph
    signal activated()

    width: 48
    height: 48
    radius: width / 2
    color: area.containsMouse ? config.accentPink : "white"
    border.color: config.accentPink
    border.width: 2

    scale: area.pressed ? 0.92 : (area.containsMouse ? 1.08 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 110
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        font.family: config.iconFont
        font.pixelSize: 20
        color: area.containsMouse ? "white" : config.deepPink
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.activated()
    }
}
