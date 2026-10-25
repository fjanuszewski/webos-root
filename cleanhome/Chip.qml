// Píldora de variación: verde si sube, roja si baja, gris si igual.
import QtQuick 2.6

Rectangle {
    property string label: ""
    property string kind: "flat"   // up | down | flat
    property real s: 1
    property real fs: 1
    property string family: ""

    height: 24 * s * fs
    width: t.implicitWidth + 16 * s * fs
    radius: height / 2
    color: kind === "up" ? Qt.rgba(61 / 255, 220 / 255, 151 / 255, 0.14)
         : kind === "down" ? Qt.rgba(1, 107 / 255, 107 / 255, 0.14)
         : Qt.rgba(1, 1, 1, 0.07)

    Text {
        id: t
        anchors.centerIn: parent
        text: parent.label
        color: parent.kind === "up" ? "#3ddc97" : parent.kind === "down" ? "#ff6b6b" : "#9aa3b5"
        font.family: parent.family; font.pixelSize: 13 * parent.s * parent.fs; font.weight: Font.DemiBold
    }
}
