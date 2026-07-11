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
            transformOrigin: Item.Center

            // Появление с лёгким «выпрыгиванием»
            scale: 0
            NumberAnimation on scale {
                id: appear

                from: 0
                to: 1
                duration: 260
                easing.type: Easing.OutBack
            }

            // Закрытие по клику: окошко сжимается обратно и удаляется
            NumberAnimation {
                id: shrink

                target: card
                property: "scale"
                to: 0
                duration: 320
                easing.type: Easing.InBack
                onFinished: popups.closeCid(card.cid)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !shrink.running
                onClicked: {
                    appear.stop()
                    shrink.start()
                }
            }
        }
    }
}
