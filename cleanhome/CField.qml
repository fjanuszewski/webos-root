// CField.qml — campo de texto de las pantallas de edición. Con el foco encima, OK (o click) empieza a escribir y
// abre el teclado en pantalla de la TV; OK/“Listo” del teclado o ATRÁS termina. ▲ ▼ salen del campo. Qt 5.6.
import QtQuick 2.6

Rectangle {
    id: fld
    property alias text: input.text
    property string label: ""
    property string placeholder: ""
    property bool numeric: false
    property bool secret: false            // contraseña: se ve mientras se escribe y después se tapa
    property real s: 1
    property string family: "Droid Sans"
    property bool editing: input.activeFocus
    property bool okDown: false
    signal accepted()

    activeFocusOnTab: true
    width: 1200 * s; height: 84 * s
    radius: 14 * s
    color: Qt.rgba(1, 1, 1, editing ? 0.12 : 0.06)
    border.width: (activeFocus || editing) ? 4 * s : 1
    border.color: editing ? "#6fa8ff" : (activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.14))

    function startEdit() {
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
        Qt.inputMethod.show();
    }
    function endEdit() {
        Qt.inputMethod.hide();
        fld.forceActiveFocus();
        fld.accepted();
    }

    TextInput {
        id: input
        x: 24 * fld.s; width: parent.width - 48 * fld.s
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: "#eef1f6"; selectionColor: "#6fa8ff"
        font.family: fld.family; font.pixelSize: 32 * fld.s
        echoMode: fld.secret ? TextInput.PasswordEchoOnEdit : TextInput.Normal
        inputMethodHints: fld.numeric ? Qt.ImhDigitsOnly
                        : fld.secret ? (Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData)
                        : (Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly)
        validator: fld.numeric ? intVal : null
        onAccepted: fld.endEdit()
        Keys.onPressed: {
            if (event.key === 0x01200001 /* webOS ATRÁS */ || event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                event.accepted = true;
                fld.endEdit();
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                fld.endEdit();
                event.accepted = false;      // que siga a la navegación del formulario
            }
        }
    }
    IntValidator { id: intVal; bottom: 1; top: 864000 }
    Text {
        visible: input.text === "" && !fld.editing
        x: input.x; anchors.verticalCenter: parent.verticalCenter
        width: input.width; elide: Text.ElideRight
        text: fld.placeholder
        color: "#5d6576"; font.family: fld.family; font.pixelSize: 30 * fld.s
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (!fld.editing) fld.forceActiveFocus()
        onClicked: fld.startEdit()
    }
    Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
            if (!event.isAutoRepeat) okDown = true;
            event.accepted = true;
        }
    }
    Keys.onReleased: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
            event.accepted = true;
            if (okDown && !event.isAutoRepeat) fld.startEdit();
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false
}
