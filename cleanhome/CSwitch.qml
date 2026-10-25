// CSwitch.qml — interruptor (encendido/apagado) con su texto. OK o click lo cambia. Qt 5.6.
import QtQuick 2.6

Rectangle {
    id: sw
    property string text: ""
    property bool checked: true
    property real s: 1
    property string family: "Droid Sans"
    property bool okDown: false

    activeFocusOnTab: true
    width: Math.max(760 * s, lbl.implicitWidth + 330 * s); height: 76 * s
    radius: 14 * s
    color: Qt.rgba(1, 1, 1, 0.05)
    border.width: activeFocus ? 4 * s : 1
    border.color: activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.10)

    Text {
        id: lbl
        x: 24 * sw.s; anchors.verticalCenter: parent.verticalCenter
        text: sw.text
        color: "#eef1f6"; font.family: sw.family; font.pixelSize: 30 * sw.s
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 24 * sw.s; anchors.verticalCenter: parent.verticalCenter
        width: 92 * sw.s; height: 48 * sw.s; radius: height / 2
        color: sw.checked ? "#3ddc97" : Qt.rgba(1, 1, 1, 0.18)
        Rectangle {
            width: 40 * sw.s; height: width; radius: width / 2; color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 4 * sw.s : 4 * sw.s
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 132 * sw.s; anchors.verticalCenter: parent.verticalCenter
        text: sw.checked ? "Encendido" : "Apagado"
        color: sw.checked ? "#3ddc97" : "#9aa3b5"; font.family: sw.family; font.pixelSize: 26 * sw.s
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: sw.forceActiveFocus()
        onClicked: sw.checked = !sw.checked
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
            if (okDown && !event.isAutoRepeat) sw.checked = !sw.checked;
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false
}
