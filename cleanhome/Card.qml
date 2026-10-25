// Card.qml — tarjeta con el mismo estilo que las del panel de Entradas (CleanInputs.qml): ícono arriba a la
// izquierda, cartel verde o ícono chico arriba a la derecha, título grande abajo y (opcional) subtítulo.
// La usa CleanSettings (secciones y redes wifi). El foco lo maneja la grilla (sel); el puntero avisa con hovered/clicked. Qt 5.6.
import QtQuick 2.6

Item {
    id: card
    property real s: 1
    property string fDisplay: "Droid Sans"
    property string fBody: "Droid Sans"
    property bool sel: false
    property bool dim: false
    property string icon: ""
    property real iconW: 64 * s
    property real iconH: 64 * s
    property string title: ""
    property string sub: ""
    property string badge: ""          // cartel verde (ej. "Conectada")
    property string mark: ""           // ícono chico arriba a la derecha (llave, candado)
    signal hovered()
    signal clicked()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 14 * card.s
        radius: 24 * card.s
        color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 0.98)
        border.width: card.sel ? 4 * card.s : 1
        border.color: card.sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
        opacity: card.dim && !card.sel ? 0.45 : 1
        scale: card.sel ? 1.05 : 1
        Behavior on scale { NumberAnimation { duration: 140 } }

        Image {
            x: 28 * card.s; y: 26 * card.s
            width: card.iconW; height: card.iconH
            fillMode: Image.PreserveAspectFit; smooth: true
            source: card.icon
        }
        Rectangle {
            visible: card.badge !== ""
            anchors.right: parent.right; anchors.rightMargin: 24 * card.s; y: 30 * card.s
            width: badgeText.implicitWidth + 20 * card.s; height: 32 * card.s; radius: height / 2
            color: Qt.rgba(61 / 255, 220 / 255, 151 / 255, 0.16)
            Text { id: badgeText; anchors.centerIn: parent; text: card.badge; color: "#3ddc97"; font.family: card.fBody; font.pixelSize: 18 * card.s; font.weight: Font.DemiBold }
        }
        Image {
            visible: card.badge === "" && card.mark !== ""
            anchors.right: parent.right; anchors.rightMargin: 26 * card.s; y: 28 * card.s
            width: 40 * card.s; height: 40 * card.s; smooth: true
            source: card.mark
        }
        Text {
            x: 28 * card.s; anchors.bottom: subText.visible ? subText.top : parent.bottom
            anchors.bottomMargin: subText.visible ? 6 * card.s : 26 * card.s
            width: parent.width - 56 * card.s; elide: Text.ElideRight
            text: card.title
            color: "#eef1f6"; font.family: card.fDisplay; font.pixelSize: 38 * card.s; font.weight: Font.Bold
        }
        Text {
            id: subText
            visible: card.sub !== ""
            x: 28 * card.s; anchors.bottom: parent.bottom; anchors.bottomMargin: 26 * card.s
            width: parent.width - 56 * card.s; elide: Text.ElideRight
            text: card.sub
            color: "#9aa3b5"; font.family: card.fBody; font.pixelSize: 24 * card.s
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: card.hovered()
        onClicked: card.clicked()
    }
}
