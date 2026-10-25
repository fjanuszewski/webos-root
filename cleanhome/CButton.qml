// CButton.qml — botón de las pantallas de edición. Se elige con flechas (foco = borde blanco) o con el puntero.
// OK actúa al SOLTAR (como el Home de LG) y se aceptan las dos mitades del evento. Qt 5.6.
import QtQuick 2.6

Rectangle {
    id: btn
    property string text: ""
    property bool primary: false
    property bool checked: false          // para usarlo como opción elegible (✓)
    property real s: 1
    property string family: "Droid Sans"
    property bool okDown: false
    signal clicked()

    activeFocusOnTab: true
    width: Math.max(t.implicitWidth + 56 * s, 160 * s); height: 72 * s
    radius: 14 * s
    color: checked ? Qt.rgba(111 / 255, 168 / 255, 1, 0.28) : (primary ? "#6fa8ff" : Qt.rgba(1, 1, 1, 0.08))
    border.width: activeFocus ? 4 * s : 1
    border.color: activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.14)
    opacity: enabled ? 1 : 0.35

    Text {
        id: t
        anchors.centerIn: parent
        text: (btn.checked ? "✓  " : "") + btn.text
        color: btn.primary && !btn.checked ? "#0b1220" : "#eef1f6"
        font.family: btn.family; font.pixelSize: 30 * btn.s; font.weight: Font.DemiBold
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: btn.forceActiveFocus()
        onClicked: btn.clicked()
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
            if (okDown && !event.isAutoRepeat) btn.clicked();
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false
}
