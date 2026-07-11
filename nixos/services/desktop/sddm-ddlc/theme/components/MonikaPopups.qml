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
                py: 30 + Math.random() * Math.max(1, popups.height - 420)
            })
            spawned++
        }
    }

    Repeater {
        model: cards

        Image {
            id: card

            x: px
            y: py
            width: 240
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: "../assets/just-monika-ok.png"

            // Появление с лёгким «выпрыгиванием»
            scale: 0
            Component.onCompleted: scale = 1
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cards.remove(index)
            }
        }
    }
}
