// PhotoLayer.qml — una capa del protector: una foto cargada directo de Google, con movimiento lento (Ken Burns).
// Verticales: entera, sobre la misma foto desenfocada de fondo. Horizontales: llenan la pantalla.
// El fondo desenfocado se arma barato: la foto chica se desenfoca a tamaño reducido (FastBlur sobre ~384 px) y
// recién después se agranda a pantalla completa. Así el blur cuesta unos pocos MB, no los ~60 MB que costaba
// cuando se desenfocaba a pantalla completa. Las fotos de adelante se piden a 1280 (~15 MB); al cerrar el
// protector se devuelve todo (ver SCREENSAVER.md, medición 2026-10-25).
// CleanSaver usa dos capas (la que se ve y la que precarga la siguiente) y vacía la vieja después del fundido.
import QtQuick 2.6
import QtGraphicalEffects 1.0

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
        bgSmall.source = (p.h > p.w) ? p.url + "=w384-h384" : "";
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

        // Fondo desenfocado para las fotos verticales: se desenfoca en chico (FastBlur sobre una superficie de
        // 384x216) y recién se agranda a pantalla completa con "scale". bgSmall es solo la fuente (oculta);
        // lo que se ve es el blur, escalado. Así el desenfoque cuesta poca memoria.
        Item {
            anchors.fill: parent
            visible: layer.portrait && bgSmall.status === Image.Ready
            clip: true
            Item {
                id: bgLow
                width: 384; height: 216
                transformOrigin: Item.TopLeft
                scale: Math.max(parent.width / width, parent.height / height)
                Image {
                    id: bgSmall
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    smooth: true; asynchronous: true; cache: false
                    visible: false
                }
                FastBlur { anchors.fill: parent; source: bgSmall; radius: 20 }
            }
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35); visible: layer.portrait && bgSmall.status === Image.Ready }

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
