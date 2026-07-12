import QtQuick
import QtQuick.Controls.Basic

// Поле ввода в стиле DDLC: белая «пилюля» с розовой рамкой,
// при фокусе рамка темнеет.
TextField {
    id: field

    // Высота считается от метрик шрифта, а не от контента: иначе поле пароля
    // меняет размер при вводе (у точек echoMode другие метрики, чем у
    // плейсхолдера) и дёргает подложку. Так высота стабильна и сама
    // подстраивается под смену шрифта/кегля
    FontMetrics {
        id: fm

        font: field.font
    }
    height: Math.ceil(fm.height) + topPadding + bottomPadding

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
