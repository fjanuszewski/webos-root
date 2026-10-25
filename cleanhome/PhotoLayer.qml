// PhotoLayer.qml — una capa del protector: una foto cargada directo de Google, con movimiento lento (Ken Burns).
// Verticales: entera, sobre la misma foto en chiquito (40 px) ampliada: se ve desenfocada sin efecto de desenfoque.
// Horizontales: llenan la pantalla.
// Memoria (medido 2026-10-25, ver SCREENSAVER.md): el efecto FastBlur se comía ~60 MB y las fotos a 1920 otros ~15;
// así, el protector suma ~15 MB y al cerrarse los devuelve.
// CleanSaver usa dos capas (la que se ve y la que precarga la siguiente) y vacía la vieja después del fundido.
import QtQuick 2.6

Item {
    id: layer

    property var photo: null
    property bool dim: false
    property bool portrait: !!(photo && photo.h > photo.w)
    readonly property bool ready: !!photo && img.status === Image.Ready
    signal failed()
    clip: true

    Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutQuad } }

    function load(p) {
        kb.stop();
        photo = p;
        // Se pide a Google a 1280 de ancho como máximo: en una tele de 50" a distancia de sillón no se nota y ocupa
        // la mitad que 1920 al decodificar
        var w = Math.min(Math.round(width) || 1920, 1280), h = Math.round(w * 9 / 16);
        img.source = p.url + "=w" + w + "-h" + h;
        bgSmall.source = (p.h > p.w) ? p.url + "=w40-h40" : "";
    }
    function clear() {
        kb.stop();
        photo = null;
        img.source = "";
        bgSmall.source = "";
    }
    // Ken Burns: zoom y desplazamiento muy lentos, dirección al azar
    function startMotion() {
        kb.stop();
        content.scale = 1.0; content.x = 0; content.y = 0;
        kbToX = (Math.random() - 0.5) * width * 0.04;
        kbToY = (Math.random() - 0.5) * height * 0.04;
        kbT0 = Date.now();
        kb.start();
    }

    Item {
        id: content
        width: parent.width; height: parent.height

        // Fondo desenfocado para las fotos verticales: versión de 40 px de la foto, ampliada (smooth la suaviza)
        Image {
            id: bgSmall
            anchors.fill: parent
            visible: layer.portrait && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            smooth: true; asynchronous: true; cache: false
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35); visible: bgSmall.visible }

        Image {
            id: img
            anchors.fill: parent
            fillMode: layer.portrait ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            sourceSize.width: layer.width; sourceSize.height: layer.height
            smooth: true; asynchronous: true; cache: false
            onStatusChanged: if (status === Image.Error && layer.photo) layer.failed()
        }
    }

    // Modo noche: oscurece la foto
    Rectangle { anchors.fill: parent; color: "black"; opacity: layer.dim ? 0.65 : 0; Behavior on opacity { NumberAnimation { duration: 1500 } } }

    // Ken Burns a pocos cuadros por segundo: con una animación normal la tele redibuja la pantalla entera 60 veces
    // por segundo (medido 2026-10-25: 30 % del procesador con el protector, contra 8 % sin movimiento). El zoom es
    // tan lento (8 % en 30 s) que a "fps" cuadros por segundo no se nota el salto.
    property int fps: 10
    property real kbT0: 0
    property real kbToX: 0
    property real kbToY: 0
    readonly property int kbMs: 30000
    Timer {
        id: kb
        interval: Math.round(1000 / layer.fps)
        repeat: true
        onTriggered: {
            var f = Math.min(1, (Date.now() - layer.kbT0) / layer.kbMs);
            content.scale = 1 + 0.08 * f;
            content.x = layer.kbToX * f;
            content.y = layer.kbToY * f;
            if (f >= 1) stop();
        }
    }
}
