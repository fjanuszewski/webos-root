// Panel de vidrio oscuro de los widgets.
import QtQuick 2.6

Rectangle {
    property real s: 1
    color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 0.78)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    radius: 22 * s
}
