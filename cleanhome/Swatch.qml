// Swatch.qml — muestra elegible de un color o de una foto (Configuración → Tema). Foco o puntero: borde blanco;
// elegida: tilde. OK al SOLTAR (como el Home de LG). Qt 5.6.
import QtQuick 2.6

Rectangle {
    id: sw
    property real s: 1
    property color fill: "#000000"
    property string image: ""              // si hay foto, se ve la foto en vez del color
    property bool checked: false
    property bool okDown: false
    property bool lit: activeFocus || mouse.containsMouse
    signal clicked()

    activeFocusOnTab: true
    width: (image ? 160 : 72) * s; height: (image ? 90 : 72) * s
    radius: 14 * s
    color: fill
    border.width: lit ? 5 * s : (checked ? 3 * s : 1)
    border.color: lit ? "#ffffff" : (checked ? "#ffffff" : Qt.rgba(1, 1, 1, 0.25))

    Image {
        visible: sw.image !== ""
        anchors.fill: parent; anchors.margins: 4 * sw.s
        fillMode: Image.PreserveAspectCrop
        asynchronous: true; smooth: true; cache: false
        sourceSize.width: 192; sourceSize.height: 108
        source: sw.image
    }
    Rectangle {      // tilde de "elegida"
        visible: sw.checked
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 6 * sw.s
        width: 26 * sw.s; height: width; radius: width / 2
        color: "#0b0d12"; border.width: 2 * sw.s; border.color: "#ffffff"
        Text { anchors.centerIn: parent; text: "✓"; color: "#ffffff"; font.pixelSize: 18 * sw.s; font.bold: true }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onEntered: sw.forceActiveFocus(); onClicked: sw.clicked() }
    Keys.onPressed: { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
    Keys.onReleased: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
            event.accepted = true;
            if (okDown && !event.isAutoRepeat) sw.clicked();
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false
}
