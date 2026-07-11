import QtQuick
import QtQuick.Controls.Basic

// Выбор сессии в нижнем левом углу. Список раскрывается вверх,
// чтобы не выйти за границу экрана.
ComboBox {
    id: control

    model: sessionModel
    currentIndex: sessionModel.lastIndex
    textRole: "name"
    width: 190
    height: 44
    font.family: config.font
    font.pixelSize: 15

    background: Rectangle {
        radius: control.height / 2
        color: "white"
        border.color: config.accentPink
        border.width: 2
    }

    contentItem: Text {
        leftPadding: 18
        rightPadding: 30
        text: control.displayText
        font: control.font
        color: config.textDark
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 14
        anchors.verticalCenter: control.verticalCenter
        text: "▴" // ▴ — список открывается вверх
        font.pixelSize: 13
        color: config.deepPink
    }

    delegate: ItemDelegate {
        id: item

        width: control.width - 12
        height: 36
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            leftPadding: 8
            text: model.name
            font.family: config.font
            font.pixelSize: 15
            color: config.textDark
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 8
            color: item.highlighted ? "#FFE3F1" : "transparent"
        }
    }

    popup: Popup {
        y: -implicitHeight - 8
        width: control.width
        implicitHeight: contentItem.implicitHeight + 12
        padding: 6

        background: Rectangle {
            radius: 12
            color: "white"
            border.color: config.accentPink
            border.width: 2
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
    }
}
