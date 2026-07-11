import QtQuick
import QtQuick.Controls.Basic

// Панель логина: бледно-розовый бокс с рамкой в стиле just-monika-ok.png,
// поля логина/пароля и картинка-кнопка «Just Monika. OK».
Item {
    id: panel

    signal loginRequested(string username, string password)

    property string errorText: ""

    function clearPassword() {
        passwordField.text = ""
        passwordField.forceActiveFocus()
    }

    function showError(msg) {
        errorText = msg
    }

    function submit() {
        loginRequested(userField.text, passwordField.text)
    }

    width: 400
    height: box.height

    Rectangle {
        id: box

        width: parent.width
        height: content.height + 56
        radius: 10
        color: config.panelColor
        border.color: config.panelBorder
        border.width: 6
    }

    Column {
        id: content

        anchors.centerIn: box
        width: panel.width - 72
        spacing: 14

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Doki Doki Literature Club!"
            font.family: config.font
            font.pixelSize: 26
            color: config.deepPink
        }

        DdlcTextField {
            id: userField

            width: parent.width
            text: userModel.lastUser
            placeholderText: "Login"
            onAccepted: passwordField.forceActiveFocus()
        }

        DdlcTextField {
            id: passwordField

            width: parent.width
            echoMode: TextInput.Password
            placeholderText: "Password"
            onAccepted: panel.submit()
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: panel.errorText
            visible: panel.errorText !== ""
            font.family: config.font
            font.pixelSize: 15
            color: config.errorRed
            wrapMode: Text.WordWrap
        }

        Item {
            width: parent.width
            height: okButton.height

            LoginButton {
                id: okButton

                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: panel.submit()
            }
        }
    }

    // Фокус сразу в нужное поле: если логин предзаполнен — в пароль
    Component.onCompleted: {
        if (userField.text.length > 0)
            passwordField.forceActiveFocus()
        else
            userField.forceActiveFocus()
    }
}
