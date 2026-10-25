// CleanGlow.qml — fondo que se tiñe con el color de la app enfocada (fila de apps o cajón).
// Lo carga MainView.qml con un Loader como primer hijo (queda debajo de todo).
// El color sale del ícono de la app: se dibuja chico en un Canvas y se toma el píxel más saturado.
// Si el ícono no tiene color útil (blanco/negro), usa iconColor o bgColor; si nada sirve, un gris azulado.
// Según el tema (settings.json → theme.bg, Configuración → Tema) en vez de eso puede ser un color fijo (bgColor)
// o una foto de /var/lib/webosbrew/fondos/ (photo), oscurecida (photoDim) para que se lean los widgets.
import QtQuick 2.6
import QtQuick.Window 2.2
import QtGraphicalEffects 1.0
import "settings.js" as Settings

Item {
    id: glow

    property var drawer: null                 // CleanDrawer (lo setea MainView)
    property var recents: null                // CleanRecents: su primera app da el color inicial
    property color neutral: "#5f6c8a"
    // Arranca en negro (sin el fondo viejo de LG) y el primer color se aplica de golpe, sin fundido;
    // después los cambios entre apps sí se animan.
    property color target: "#000000"
    property color current: "#000000"
    property bool animate: false
    Behavior on current { enabled: glow.animate; ColorAnimation { duration: 650; easing.type: Easing.InOutQuad } }
    onTargetChanged: {
        current = target;
        if (!animate && target !== Qt.rgba(0, 0, 0, 1)) enableAnim.restart();
    }
    Timer { id: enableAnim; interval: 120; onTriggered: glow.animate = true }

    // ---------- Tema ----------
    property var theme: Settings.defaults().theme
    readonly property string fondos: "file:///var/lib/webosbrew/fondos/"
    property bool dynamic: theme.bg !== "color" && !(theme.bg === "photo" && theme.photo)
    function loadTheme() { Settings.load(function (st) { glow.theme = st.theme; }); }
    Component.onCompleted: loadTheme()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: glow.loadTheme() }
    Connections {
        target: uiController.mainView
        ignoreUnknownSignals: true
        onCleanRevChanged: glow.loadTheme()
    }

    property var cache: ({})                  // url del ícono -> color ya calculado
    property string pendingUrl: ""

    function hexOk(h) {
        if (!h || typeof h !== "string" || h.length < 7) return null;
        var c = Qt.darker(h, 1.0);
        var mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b);
        return (mx > 0.2 && mx - mn > 0.16) ? c : null;
    }
    function iconUrl(e) {
        var p = e.mediumLargeIcon || e.largeIcon || e.icon || "";
        if (!p) return "";
        return p.indexOf("/") === 0 ? "file://" + p : p;
    }
    function applyEntry(e) {
        if (!e) return;
        var url = iconUrl(e);
        if (url && cache[url] !== undefined) { target = cache[url] || hexOk(e.iconColor) || hexOk(e.bg) || neutral; return; }
        target = hexOk(e.iconColor) || hexOk(e.bg) || target;    // mientras se analiza el ícono
        if (url) { pendingUrl = url; sampler.loadImage(url); if (sampler.isImageLoaded(url)) sampler.requestPaint(); }
    }

    // Busca el "entry" de la app enfocada subiendo por los padres del ítem con foco
    function entryFromFocus(item) {
        for (var it = item, n = 0; it && n < 12; it = it.parent, n++) {
            if (it.objData && it.objData.title !== undefined) return it.objData;
        }
        return null;
    }
    property var afi: Window.activeFocusItem
    onAfiChanged: refresh()
    Connections {
        target: glow.drawer
        ignoreUnknownSignals: true
        onCurrentEntryChanged: glow.refresh()
        onOpenedChanged: glow.refresh()
    }
    Connections {
        target: glow.recents
        ignoreUnknownSignals: true
        onAppsChanged: glow.refresh()
        onCurrentEntryChanged: glow.refresh()
    }
    onRecentsChanged: refresh()
    function refresh() {
        if (drawer && drawer.opened) { applyEntry(drawer.currentEntry); return; }
        var e = entryFromFocus(afi);
        // Sin app enfocada (Home recién cargado, foco arriba): color de la primera app de recientes
        if (!e && recents && recents.apps && recents.apps.length) e = recents.apps[0];
        if (e) applyEntry(e);
    }

    Canvas {
        id: sampler
        width: 24; height: 24
        visible: false
        renderStrategy: Canvas.Immediate
        onImageLoaded: requestPaint()
        onPaint: {
            var url = glow.pendingUrl;
            if (!url || !isImageLoaded(url)) return;
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, 24, 24);
            ctx.drawImage(url, 0, 0, 24, 24);
            var best = null, bestS = 0;
            try {
                var px = ctx.getImageData(0, 0, 24, 24).data;
                for (var i = 0; i < px.length; i += 4) {
                    if (px[i + 3] < 200) continue;
                    var mx = Math.max(px[i], px[i + 1], px[i + 2]), mn = Math.min(px[i], px[i + 1], px[i + 2]);
                    if (mx > 60 && mx - mn > bestS) { bestS = mx - mn; best = [px[i], px[i + 1], px[i + 2]]; }
                }
            } catch (e) { best = null; }
            var col = (best && bestS > 45) ? Qt.rgba(best[0] / 255, best[1] / 255, best[2] / 255, 1) : null;
            glow.cache[url] = col;
            if (url === glow.pendingUrl && col) glow.target = col;
        }
    }

    // Color fijo (con un degradé suave hacia abajo para que no sea plano)
    Rectangle {
        visible: glow.theme.bg === "color"
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(glow.theme.bgColor || "#1d2740", 1.25) }
            GradientStop { position: 1.0; color: glow.theme.bgColor || "#1d2740" }
        }
    }
    // Foto de fondo, oscurecida
    Image {
        id: photo
        visible: glow.theme.bg === "photo" && !!glow.theme.photo && status === Image.Ready
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true; cache: false; smooth: true
        sourceSize.width: 1920; sourceSize.height: 1080
        source: glow.theme.bg === "photo" && glow.theme.photo ? glow.fondos + glow.theme.photo : ""
    }
    Rectangle {
        visible: photo.visible
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Math.max(0, Math.min(0.85, glow.theme.photoDim !== undefined ? glow.theme.photoDim : 0.35)))
    }

    // Resplandor arriba a la izquierda + uno más suave abajo a la derecha (fondo "dinámico")
    RadialGradient {
        visible: glow.dynamic
        anchors.fill: parent
        horizontalOffset: -width * 0.30
        verticalOffset: -height * 0.58
        horizontalRadius: width * 0.95
        verticalRadius: height * 0.95
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(glow.current.r, glow.current.g, glow.current.b, 0.55) }
            GradientStop { position: 0.7; color: Qt.rgba(glow.current.r, glow.current.g, glow.current.b, 0.0) }
        }
    }
    RadialGradient {
        visible: glow.dynamic
        anchors.fill: parent
        horizontalOffset: width * 0.5
        verticalOffset: height * 0.55
        horizontalRadius: width * 0.6
        verticalRadius: height * 0.6
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(glow.current.r, glow.current.g, glow.current.b, 0.22) }
            GradientStop { position: 0.7; color: Qt.rgba(glow.current.r, glow.current.g, glow.current.b, 0.0) }
        }
    }
}
