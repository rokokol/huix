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

    property int nextId: 0

    ListModel {
        id: cards
    }

    // Удаление по уникальному id — индексы в модели съезжают при закрытии
    function closeCid(cid) {
        for (var i = 0; i < cards.count; i++) {
            if (cards.get(i).cid === cid) {
                cards.remove(i)
                break
            }
        }
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
                cid: popups.nextId++,
                px: 30 + Math.random() * Math.max(1, popups.width - 260),
                py: 30 + Math.random() * Math.max(1, popups.height - 400)
            })
            spawned++
        }
    }

    Repeater {
        model: cards

        Image {
            id: card

            readonly property int cid: model.cid

            x: px
            y: py
            width: 190
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

            // Плавное исчезновение по клику: затухание, потом удаление из модели
            NumberAnimation {
                id: fade

                target: card
                property: "opacity"
                to: 0
                duration: 550
                easing.type: Easing.InOutQuad
                onFinished: popups.closeCid(card.cid)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !fade.running
                onClicked: fade.start()
            }
        }
    }
}
