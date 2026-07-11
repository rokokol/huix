import QtQuick
import QtQuick.Controls.Basic

// Поле ввода в стиле DDLC: белая «пилюля» с розовой рамкой,
// при фокусе рамка темнеет.
TextField {
    id: field

    font.family: config.font
    font.pixelSize: 19
    color: config.textDark
    placeholderTextColor: "#C9A0B4"
    selectionColor: config.accentPink
    selectedTextColor: "white"
    leftPadding: 18
    rightPadding: 18
    topPadding: 10
    bottomPadding: 10

    background: Rectangle {
        radius: height / 2
        color: "white"
        border.color: field.activeFocus ? config.deepPink : config.accentPink
        border.width: 2
    }
}
