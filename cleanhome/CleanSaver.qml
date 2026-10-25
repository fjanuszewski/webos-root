// CleanSaver.qml — protector de pantalla con las fotos del álbum compartido de Google Photos.
// Lo carga el MainView.qml (modificado) de la app com.webos.app.screensaver de LG, a pantalla completa.
// Lista de fotos: saver/index.json (la arma saver/sync.js como root, al prender y cada 6 h; solo URLs).
//   - de a una foto al azar, cargada directo de Google en memoria (nada en disco); como mucho 2 a la vez:
//     la que se ve y la siguiente, que se precarga mientras tanto. La vieja se vacía después del fundido.
//   - cambia cada 10 s; si la siguiente todavía no llegó, espera a que llegue;
//     si en 190 s no llegó (o dio error), prueba con otra al azar
//   - la primera foto de cada vez es, si hay, una de un día como hoy en años anteriores ("Hace N años")
//   - verticales enteras sobre la misma foto ampliada y desenfocada; horizontales llenan la pantalla
//   - movimiento lento (Ken Burns) + fundido
//   - 6 partes de la pantalla (arriba y abajo: izquierda, centro, derecha). En cada una va lo que se eligió en el
//     editor (SaverEditor.qml): hora, fecha, clima, eventos del calendario, fecha de la foto… o nada (SaverWidget.qml).
//     Por defecto: eventos arriba, fecha de la foto abajo a la izquierda, hora + fecha + clima abajo a la derecha.
//   - modo noche de 0 a 7 h
//   - ajustes (settings.json): encendido/apagado, segundos por foto y qué va en cada parte (saver.layout)
//   - el bloque de texto se corre unos píxeles cada minuto para no marcar la pantalla
// Si no hay fotos, photoCount queda en 0 y el protector de LG (burbujas) sigue como respaldo. Qt 5.6.
import QtQuick 2.6
import "settings.js" as Settings

Item {
    id: saver

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property string dir: base + "saver/"
    property real s: width / 1920
    function r(v) { return v * s; }

    property var photos: []
    property int photoCount: photos.length
    property var recent: []                   // últimas fotos mostradas, para no repetir enseguida
    property bool firstPick: true
    property real shownAt: 0
    property real waitingSince: 0
    property int minShow: 10000               // cada foto se ve al menos N s (ajuste "saver.interval")
    property var st: null                      // settings.json (encendido, segundos por foto, clima)
    // Qué va en cada parte de la pantalla (settings.json → saver.layout). Mientras se edita, el editor pone su copia
    // de trabajo en layoutOverride y se ve el cambio en vivo; "editing" dibuja el borde de cada parte.
    property var layoutOverride: null
    property var lay: layoutOverride ? layoutOverride : Settings.saverLayout(st ? st.saver : null)
    property bool editing: false
    property string selSlot: ""
    signal slotClicked(string id)
    signal slotHovered(string id)
    property var curPhoto: null              // la foto que se ve (para "Fecha de la foto")
    property bool hasTop: false             // ¿hay algo arriba / abajo? (para las sombras); lo recalcula cada parte
    property bool hasBottom: false
    function slotFilled(i) { var it = slots.itemAt(i); return !!it && it.filled; }
    function recalcShadows() {
        hasTop = slotFilled(0) || slotFilled(1) || slotFilled(2);
        hasBottom = slotFilled(3) || slotFilled(4) || slotFilled(5);
    }
    property var calEvents: []               // cal/events.json (lo arma cal/sync.js)
    property var calNow: null                // evento en curso: { title, when }
    property var calNext: null               // próximo evento: { title, when }
    readonly property int giveUp: 190000      // si la siguiente no llega en 190 s, se prueba otra
    property bool night: false
    property string clock: ""
    property string weather: ""
    property string wxIconName: ""           // ícono del clima actual (img/<nombre>.png)
    property string wxTemp: ""               // "18°"
    property string todayText: ""            // "Sáb, 24 oct"
    readonly property var diasC: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
    readonly property var mesesC: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    FontLoader { id: fDispM; source: saver.base + "fonts/Bricolage-Medium.ttf" }
    FontLoader { id: fUi; source: saver.base + "fonts/InstrumentSans-Regular.ttf" }
    FontLoader { id: fUiB; source: saver.base + "fonts/InstrumentSans-SemiBold.ttf" }
    property string fDisplay: fDispM.status === FontLoader.Ready ? fDispM.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    // ---------- Datos ----------
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function yearsAgo(p) {
        if (!p || !p.ts) return 0;
        var d = new Date(p.ts), now = new Date();
        return (d.getDate() === now.getDate() && d.getMonth() === now.getMonth() && d.getFullYear() < now.getFullYear())
               ? now.getFullYear() - d.getFullYear() : 0;
    }
    function pick() {
        var n = photos.length, i, tries;
        if (firstPick) {
            firstPick = false;
            var memories = [];
            for (i = 0; i < n; i++) if (yearsAgo(photos[i]) > 0) memories.push(i);
            if (memories.length) return memories[Math.floor(Math.random() * memories.length)];
        }
        for (tries = 0; tries < 20; tries++) {
            i = Math.floor(Math.random() * n);
            if (recent.indexOf(i) === -1) break;
        }
        var r2 = recent.slice(0);
        r2.push(i);
        if (r2.length > Math.min(30, Math.floor(n / 2))) r2.shift();
        recent = r2;
        return i;
    }
    function prefetch() {
        if (!photos.length) return;
        waitingSince = Date.now();
        back.load(photos[pick()]);
    }
    function load() {
        if (st && st.saver.enabled === false) return;   // apagado desde la pantalla de edición
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var list = [];
            try { list = JSON.parse(x.responseText).photos || []; } catch (e) { list = []; }
            if (!list.length) return;                       // si falla, se queda con la lista que tenía
            var first = saver.photos.length === 0;
            saver.photos = list;
            saver.recent = [];
            if (first) prefetch();
        };
        x.open("GET", dir + "index.json");
        x.send();
    }
    function loadWeather() {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE || x.status !== 200) return;
            try {
                var c = JSON.parse(x.responseText).current, k = c.weather_code;
                var cond = k === 0 ? "Despejado" : k <= 2 ? "Parcialmente nublado" : k === 3 ? "Nublado" : (k === 45 || k === 48) ? "Niebla"
                         : (k >= 51 && k <= 57) ? "Llovizna" : (k >= 61 && k <= 67) ? "Lluvia" : (k >= 80 && k <= 82) ? "Chaparrones" : k >= 95 ? "Tormenta" : "Nublado";
                saver.weather = cond;
                saver.wxTemp = Math.round(c.temperature_2m) + (saver.st && saver.st.wx.unit === "fahrenheit" ? "°F" : "°C");
                var icon = k === 0 ? "sun" : k <= 2 ? "partly" : (k === 45 || k === 48) ? "fog" : (k >= 51 && k <= 57) ? "drizzle"
                         : ((k >= 61 && k <= 67) || (k >= 80 && k <= 82)) ? "rain" : k >= 95 ? "storm" : "cloud";
                if (c.is_day === 0 && icon === "sun") icon = "moon";
                if (c.is_day === 0 && icon === "partly") icon = "moon-partly";
                saver.wxIconName = icon;
            } catch (e) {}
        };
        var w = saver.st ? saver.st.wx : Settings.defaults().wx;
        x.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + w.lat + "&longitude=" + w.lon + "&current=temperature_2m,weather_code,is_day&timezone=" + encodeURIComponent(w.tz || "auto") + (w.unit === "fahrenheit" ? "&temperature_unit=fahrenheit" : ""));
        x.send();
    }
    // ---------- Calendario: el evento en curso (arriba a la izquierda) y el siguiente (arriba a la derecha) ----------
    function loadCal() {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try { saver.calEvents = JSON.parse(x.responseText).events || []; } catch (e) { saver.calEvents = []; }
            saver.pickCal();
        };
        x.open("GET", base + "cal/events.json");
        x.send();
    }
    function hhmm(t) { var d = new Date(t); return pad2(d.getHours()) + ":" + pad2(d.getMinutes()); }
    function dayStart(t) { var d = new Date(t); d.setHours(0, 0, 0, 0); return d.getTime(); }
    function whenNext(t) {
        var dd = Math.round((dayStart(t) - dayStart(Date.now())) / 86400000);
        if (dd === 0) return hhmm(t);
        if (dd === 1) return "Mañana · " + hhmm(t);
        var d = new Date(t);
        return diasC[d.getDay()] + " " + d.getDate() + " · " + hhmm(t);
    }
    function pickCal() {
        var now = Date.now(), live = null, allDay = null, next = null;
        for (var i = 0; i < calEvents.length; i++) {
            var e = calEvents[i];
            if (!e || !e.title) continue;
            if (e.allDay) { if (e.start <= now && e.end > now && !allDay) allDay = e; continue; }
            if (e.start <= now && e.end > now) { if (!live || e.end < live.end) live = e; }
            else if (e.start > now && (!next || e.start < next.start)) next = e;
        }
        if (live) calNow = { title: live.title, when: "Ahora · hasta " + hhmm(live.end) };
        else if (allDay) calNow = { title: allDay.title, when: "Hoy · todo el día" };
        else calNow = null;
        calNext = next && next.start - now < 7 * 86400000 ? { title: next.title, when: whenNext(next.start) } : null;
    }
    function tick() {
        var d = new Date();
        pickCal();
        clock = pad2(d.getHours()) + ":" + pad2(d.getMinutes());
        todayText = diasC[d.getDay()] + ", " + d.getDate() + " " + mesesC[d.getMonth()];
        night = d.getHours() < 7;
    }

    // ---------- Rotación con fundido ----------
    property Item front: layerA
    property Item back: layerB
    // Cada segundo: si la siguiente ya llegó y pasaron 10 s (o todavía no se mostró nada), fundido.
    // Si no llegó en 190 s, otra al azar.
    function step() {
        if (!photos.length || freeOld.running) return;
        var now = Date.now();
        if (back.ready && (!front.photo || now - shownAt >= minShow)) swap();
        else if (!back.ready && now - waitingSince >= giveUp) prefetch();
    }
    function swap() {
        var t = front; front = back; back = t;
        front.z = 2; back.z = 1;
        front.startMotion();
        front.opacity = 1; back.opacity = 0;
        curPhoto = front.photo;
        shownAt = Date.now();
        freeOld.restart();
    }

    // Primero los ajustes: si el protector está apagado no se cargan fotos (photoCount queda en 0 → protector de LG)
    Component.onCompleted: {
        tick();
        Settings.load(function (st) {
            saver.st = st;
            saver.minShow = Math.max(5, st.saver.interval || 10) * 1000;
            if (st.saver.enabled !== false) saver.load();
            saver.loadWeather();
            saver.loadCal();
        });
    }
    Timer { interval: 1000; running: saver.photoCount > 0; repeat: true; onTriggered: saver.step() }
    // Terminado el fundido: se libera la foto vieja y en esa capa se precarga la siguiente
    Timer { id: freeOld; interval: 1700; onTriggered: { saver.back.clear(); saver.prefetch(); } }
    // Si la foto dio error, se prueba otra en 5 s
    Timer { id: retry; interval: 5000; onTriggered: saver.prefetch() }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: saver.tick() }
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: saver.loadWeather() }
    Timer { interval: 600000; running: true; repeat: true; onTriggered: saver.loadCal() }
    // La lista se actualiza cada 6 h (sync.js); si el protector queda prendido mucho tiempo, la relee cada hora
    Timer { interval: 3600000; running: true; repeat: true; onTriggered: saver.load() }

    Rectangle { anchors.fill: parent; color: "black" }

    PhotoLayer { id: layerA; anchors.fill: parent; dim: saver.night; onFailed: if (saver.back === layerA) retry.restart() }
    PhotoLayer { id: layerB; anchors.fill: parent; dim: saver.night; opacity: 0; onFailed: if (saver.back === layerB) retry.restart() }

    // ---------- Textos (con degradé para que se lean) ----------
    // z 10/11: SIEMPRE encima de las fotos (swap() sube la capa de la foto nueva a z 2)
    Rectangle {           // sombra abajo, solo si hay algo abajo (degradé vertical de Qt: sin módulo de efectos)
        z: 10
        visible: saver.editing || saver.hasBottom
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: r(320)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
        }
    }

    Rectangle {           // sombra arriba, solo si hay algo arriba
        z: 10
        visible: saver.editing || saver.hasTop
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: r(260)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    Item {
        id: overlay
        z: 11
        anchors.fill: parent
        opacity: saver.night ? 0.6 : 1
        Behavior on opacity { NumberAnimation { duration: 1500 } }
        // anti marcas: se corre unos píxeles cada minuto
        property real dx: 0
        property real dy: 0
        Timer {
            interval: 60000; running: true; repeat: true
            onTriggered: { overlay.dx = (Math.random() - 0.5) * saver.r(24); overlay.dy = (Math.random() - 0.5) * saver.r(16); }
        }
        Behavior on dx { NumberAnimation { duration: 3000 } }
        Behavior on dy { NumberAnimation { duration: 3000 } }

        // Las 6 partes de la pantalla (settings.js → SAVER_SLOTS). Cada una muestra la pieza elegida, pegada al borde.
        Repeater {
            id: slots
            model: Settings.SAVER_SLOTS
            delegate: Item {
                id: slot
                property var def: modelData
                property var cfg: saver.lay ? saver.lay[def.id] : null
                property bool sel: saver.editing && saver.selSlot === def.id
                property bool filled: piece.hasContent
                onFilledChanged: saver.recalcShadows()
                Component.onCompleted: saver.recalcShadows()
                x: r(def.x) + (saver.editing ? 0 : overlay.dx); y: r(def.y) + (saver.editing ? 0 : overlay.dy)
                width: r(def.w); height: r(def.h)
                SaverWidget {
                    id: piece
                    sv: saver
                    kind: slot.cfg ? slot.cfg.w : ""
                    k: Settings.sizeFactor(slot.cfg ? slot.cfg.size : "m")
                    align: slot.def.h_
                    x: slot.def.h_ === "left" ? 0 : slot.def.h_ === "right" ? slot.width - width : (slot.width - width) / 2
                    y: slot.def.v === "top" ? 0 : slot.height - height
                }
                // ---- solo mientras se edita: el borde de la parte, su nombre y "Nada" si está vacía ----
                Rectangle {
                    visible: saver.editing
                    anchors.fill: parent; radius: r(18)
                    color: slot.sel ? Qt.rgba(111 / 255, 168 / 255, 1, 0.22) : Qt.rgba(0, 0, 0, 0.18)
                    border.width: slot.sel ? r(5) : r(2)
                    border.color: slot.sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)
                    z: -1
                }
                Text {
                    visible: saver.editing && (!slot.cfg || slot.cfg.w === "")
                    anchors.centerIn: parent
                    text: "Nada"
                    color: Qt.rgba(1, 1, 1, 0.6); font.family: saver.fBody; font.pixelSize: r(30)
                }
                Rectangle {
                    visible: saver.editing
                    x: slot.def.h_ === "right" ? r(14) : parent.width - width - r(14)
                    y: slot.def.v === "top" ? parent.height - height - r(12) : r(12)
                    width: tag.implicitWidth + r(20); height: r(36); radius: r(8)
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Text {
                        id: tag
                        anchors.centerIn: parent
                        text: Settings.widgetName(slot.cfg ? slot.cfg.w : "") + (slot.cfg && slot.cfg.w ? " · " + (slot.cfg.size === "s" ? "chica" : slot.cfg.size === "l" ? "grande" : "mediana") : "")
                        color: "#eef1f6"; font.family: saver.fBody; font.pixelSize: r(22)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: saver.editing
                    hoverEnabled: true
                    onEntered: saver.slotHovered(slot.def.id)
                    onClicked: saver.slotClicked(slot.def.id)
                }
            }
        }
    }
}
