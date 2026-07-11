import QtQuick

// Пасхалка: после трёх неверных паролей по экрану одно за другим
// появляются маленькие «окошки» Just Monika. Каждое закрывается кликом
Item {
    id: popups

    property bool active: false
    property int total: 7

    onActiveChanged: {
        cards.clear()
        if (active) {
            spawnTimer.spawned = 0
            spawnTimer.restart()
        } else {
            spawnTimer.stop()
        }
    }

    ListModel {
        id: cards
    }

    Timer {
        id: spawnTimer

        property int spawned: 0

        interval: 350
        repeat: true
        onTriggered: {
            if (spawned >= popups.total) {
                stop()
                return
            }
            // Не залезаем на нижнюю полосу со спрайтами и кнопками
            cards.append({
                px: 30 + Math.random() * Math.max(1, popups.width - 290),
                py: 30 + Math.random() * Math.max(1, popups.height - 420),
                rot: (Math.random() - 0.5) * 12
            })
            spawned++
        }
    }

    Repeater {
        model: cards

        Rectangle {
            id: card

            x: px
            y: py
            width: 230
            height: 110
            radius: 8
            rotation: rot
            color: config.panelColor
            border.color: config.panelBorder
            border.width: 4

            // Появление с лёгким «выпрыгиванием»
            scale: 0
            Component.onCompleted: scale = 1
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }

            // Полоска заголовка с крестиком, как у окна
            Rectangle {
                id: titleBar

                width: parent.width - 8
                height: 26
                x: 4
                y: 4
                radius: 5
                color: config.panelBorder

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    font.pixelSize: 14
                    font.bold: true
                    color: "white"
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: titleBar.bottom
                anchors.topMargin: 18
                text: "Just Monika."
                font.family: config.font
                font.pixelSize: 22
                color: config.textDark
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cards.remove(index)
            }
        }
    }
}
