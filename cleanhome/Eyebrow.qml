// Etiqueta superior de un panel: texto en mayúsculas a la izquierda y dato chico a la derecha.
import QtQuick 2.6

Item {
    property string leftText: ""
    property string rightText: ""
    property real s: 1
    property real fs: 1
    property string family: ""
    height: 18 * s * fs

    Text {
        text: parent.leftText.toUpperCase()
        color: "#9aa3b5"
        font.family: parent.family; font.pixelSize: 13 * parent.s * parent.fs; font.weight: Font.DemiBold
        font.letterSpacing: 1 * parent.s
    }
    Text {
        anchors.right: parent.right
        text: parent.rightText
        color: "#5d6576"
        font.family: parent.family; font.pixelSize: 13 * parent.s * parent.fs
    }
}
