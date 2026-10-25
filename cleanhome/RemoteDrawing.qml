// RemoteDrawing.qml — el dibujo del control (Magic Remote MR20) con sus 9 botones que se pueden cambiar.
// La imagen (img/control-mr20.png) sale de la vista previa (design/launcher.html, mismo dibujo); encima van las
// zonas de los 9 botones (botones.js → KEYS): resaltadas, la elegida con borde blanco y, en "modo elegir",
// titilando. Pasar el puntero o hacer click sobre un botón avisa con hovered / clicked. Qt 5.6.
import QtQuick 2.6
import "botones.js" as Botones

Item {
    id: rd

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property string selected: ""        // id del botón elegido (Botones.KEYS[i].id)
    property bool blink: false          // "modo elegir": los 9 botones titilan
    property color accent: "#6fa8ff"
    signal hovered(string key)
    signal clicked(string key)

    // mantiene la proporción del dibujo: el alto manda
    width: height * Botones.VIEW_W / Botones.VIEW_H
    property real k: height / Botones.VIEW_H

    Image {
        anchors.fill: parent
        source: rd.base + "img/control-mr20.png"
        smooth: true
        sourceSize.height: Math.max(1, Math.round(rd.height))
    }

    property real pulse: 1
    SequentialAnimation on pulse {
        running: rd.blink && rd.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.25; duration: 550; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.25; to: 1; duration: 550; easing.type: Easing.InOutQuad }
    }

    Repeater {
        model: Botones.KEYS
        delegate: Rectangle {
            property var zn: modelData.zone   // (no "z": es la propiedad de apilado)
            property bool sel: rd.selected === modelData.id
            // el elegido: aro blanco grueso separado del botón (se ve aunque el botón sea blanco, como NETFLIX);
            // los demás que se pueden cambiar: borde de color pegado al botón
            property real gap: sel ? 7 : 3
            x: (zn[0] - gap) * rd.k; y: (zn[1] - gap) * rd.k
            width: (zn[2] + 2 * gap) * rd.k; height: (zn[3] + 2 * gap) * rd.k
            radius: height / 2
            color: "transparent"
            border.width: sel ? Math.max(3, 3.5 * rd.k) : Math.max(2, 2.5 * rd.k)
            border.color: sel ? "#ffffff" : rd.accent
            opacity: rd.blink ? rd.pulse : (sel ? 1 : 0.8)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: rd.hovered(modelData.id)
                onClicked: rd.clicked(modelData.id)
            }
        }
    }
}
