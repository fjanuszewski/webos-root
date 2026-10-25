// RoundIcon.qml — botón redondo con ícono (como la ✕ del panel de Entradas). Se ilumina con el foco o el puntero.
// cross: dibuja una ✕. spinning: el ícono gira (ej. refrescar mientras se conecta). OK al soltar. Qt 5.6.
import QtQuick 2.6

Rectangle {
    id: rb
    property real s: 1
    property string icon: ""
    property bool cross: false
    property bool spinning: false
    property bool busy: false          // "cargando": fondo azul mientras trabaja
    property bool okDown: false
    property bool lit: activeFocus || mouse.containsMouse
    signal clicked()

    activeFocusOnTab: true
    width: 68 * s; height: 68 * s; radius: width / 2
    color: busy ? "#6fa8ff" : (lit ? "#eef1f6" : Qt.rgba(1, 1, 1, 0.08))
    border.width: busy && lit ? 4 * s : 1
    border.color: busy && lit ? "#ffffff" : Qt.rgba(1, 1, 1, lit ? 0 : 0.14)
    Behavior on color { ColorAnimation { duration: 200 } }

    // giro continuo hacia la derecha mientras "spinning"; al terminar vuelve derecho.
    // Gira el contenedor entero (ícono claro + versión oscura) con la animación pegada a su rotation.
    Item {
        id: spinner
        visible: !rb.cross && rb.icon !== ""
        anchors.centerIn: parent
        width: 38 * rb.s; height: 38 * rb.s
        NumberAnimation on rotation {
            id: spinAnim
            running: rb.spinning
            loops: Animation.Infinite
            from: 0; to: 360; duration: 900
        }
        Image {
            id: img
            anchors.fill: parent; smooth: true
            source: rb.icon
            // ícono claro sobre fondo claro: se oscurece cuando el botón está iluminado
            opacity: rb.lit && !rb.busy ? 0 : 1
        }
        Rectangle {   // versión oscura del ícono cuando está iluminado (Qt 5.6 sin efectos: círculo oscuro detrás)
            visible: rb.lit && !rb.busy
            anchors.fill: parent; radius: width / 2
            color: "#0b0d12"
            Image { anchors.centerIn: parent; width: 30 * rb.s; height: 30 * rb.s; smooth: true; source: rb.icon }
        }
    }
    onSpinningChanged: if (!spinning) spinner.rotation = 0
    Repeater {
        model: rb.cross ? [45, -45] : []
        Rectangle { anchors.centerIn: parent; width: 28 * rb.s; height: 3.5 * rb.s; radius: height / 2; rotation: modelData; color: rb.lit ? "#0b0d12" : "#eef1f6" }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }
    Keys.onPressed: { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
    Keys.onReleased: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
            event.accepted = true;
            if (okDown && !event.isAutoRepeat) rb.clicked();
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false
}
