// CleanRecents.qml — primera fila del Home: las últimas 5 apps usadas.
// Reemplaza la fila nativa de LG (MainRibbon). Datos 100% del Home, sin memoria extra:
//   - historial: systemProperties.recentAppsData (el Home ya está suscripto a com.webos.service.recent)
//   - apps e íconos: interfaces.launchPoints.launchPointsModel
// Si el historial trae menos de 5 apps del launcher, completa con las primeras del launcher.
// Solo maneja ◀ ▶ y OK: ▲ y ▼ siguen al Home (▲ a los íconos de arriba, ▼ abre el cajón).
import QtQuick 2.6
import "settings.js" as Settings

FocusScope {
    id: recents

    // Color del borde de la app elegida (tema → "Selección"); se relee cuando Configuración guarda
    property color accent: "#ffffff"
    function loadAccent() { Settings.load(function (st) { recents.accent = st.theme && st.theme.accent ? st.theme.accent : "#ffffff"; }); }
    Connections {
        target: uiController.mainView
        ignoreUnknownSignals: true
        onCleanRevChanged: recents.loadAccent()
    }

    readonly property int maxApps: 5
    property var apps: []
    property var currentEntry: (list.currentIndex >= 0 && list.currentIndex < apps.length) ? apps[list.currentIndex] : null
    property var objData: currentEntry          // CleanGlow toma el color de acá

    property real s: width / 1920
    function r(v) { return v * s; }

    function iconUrl(e) {
        if (!e) return "";
        var p = e.mediumLargeIcon || e.largeIcon || e.icon || "";
        if (!p) return "";
        return p.indexOf("/") === 0 ? "file://" + p : p;
    }

    function rebuild() {
        var m = interfaces.launchPoints.launchPointsModel;
        var byId = {}, order = [];
        for (var i = 0; i < m.count; i++) {
            var it = m.get(i);
            var e = it ? it.entry : null;
            if (e && e.id && !byId[e.id]) { byId[e.id] = e; order.push(e); }
        }
        var out = [], seen = {};
        var rec = systemProperties.recentAppsData;
        if (rec && rec.length) {
            for (var j = 0; j < rec.length && out.length < maxApps; j++) {
                var id = rec[j].appId;
                if (byId[id] && !seen[id]) { out.push(byId[id]); seen[id] = true; }
            }
        }
        for (var k = 0; k < order.length && out.length < maxApps; k++) {
            if (!seen[order[k].id]) { out.push(order[k]); seen[order[k].id] = true; }
        }
        // Si la fila no cambió, no se toca: reemplazar la lista vuelve a crear los 5 íconos (se cargan de a uno
        // y la fila "salta" cada vez que se abre el inicio).
        var same = out.length === apps.length;
        for (var q = 0; same && q < out.length; q++) same = out[q].id === apps[q].id;
        if (same) return;
        var keep = currentEntry ? currentEntry.id : "";
        apps = out;
        console.warn("[CleanRecents] modelo=" + m.count + " recientes=" + (rec && rec.length ? rec.length : 0) + " fila=" + out.length);
        var idx = 0;
        for (var n = 0; n < out.length; n++) if (out[n].id === keep) { idx = n; break; }
        list.currentIndex = idx;
    }

    // Marca en el registro cuándo se abre/cierra el inicio, y lo anota en /tmp/cytv-inicio-visible ("1" o "0"):
    // el vigilante (botones/vigilante.py) cierra las apps de atrás si el inicio queda a la vista 1 minuto. Hace
    // falta porque, con el inicio encima de Netflix, la tele sigue diciendo que al frente está Netflix.
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: {
            console.warn("[cytv] inicio visible=" + uiController.homeShown);
            var x = new XMLHttpRequest();
            x.open("PUT", "file:///tmp/cytv-inicio-visible");
            x.send(uiController.homeShown ? "1" : "0");
        }
    }
    Connections {
        target: systemProperties
        ignoreUnknownSignals: true
        onRecentAppsDataChanged: recents.rebuild()
    }
    Connections {
        target: interfaces.launchPoints.launchPointsModel
        ignoreUnknownSignals: true
        onCountChanged: recents.rebuild()
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: recents.rebuild() }
    // Opciones de la app elegida (Abrir · Quitar de recientes · Eliminar). Al cerrar, el foco vuelve a la fila.
    function showMenu() {
        var m = uiController.mainView ? uiController.mainView.cleanAppMenu : null;
        if (m && m.item && currentEntry) m.item.open(currentEntry, true, list);
    }
    Component.onCompleted: { rebuild(); loadAccent(); }
    onActiveFocusChanged: if (activeFocus) rebuild()

    // Mismo ancho que los widgets de arriba (x 64 a 1856 sobre 1920): los 5 tiles llenan la fila
    readonly property real gap: r(32)
    readonly property real tileW: (r(1792) - gap * (maxApps - 1)) / maxApps
    ListView {
        id: list
        x: r(64)
        y: r(10)
        width: r(1792)
        height: r(160)
        orientation: ListView.Horizontal
        spacing: recents.gap
        // En Qt 5.6 un ListView con interactive:false ignora las flechas: hay que dejarlo en true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        focus: true
        keyNavigationWraps: false
        model: recents.apps

        delegate: Rectangle {
            property var e: modelData
            property bool sel: ListView.isCurrentItem && recents.activeFocus
            width: recents.tileW; height: r(160)
            radius: r(22)
            color: (e && e.iconColor) ? e.iconColor : Qt.rgba(1, 1, 1, 0.08)
            scale: sel ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 140 } }
            border.width: sel ? r(4) : 0
            border.color: recents.accent
            Image {
                anchors.centerIn: parent
                width: parent.height * 0.92; height: width
                fillMode: Image.PreserveAspectFit
                smooth: true; asynchronous: true
                source: recents.iconUrl(e)
            }
            // Puntero del control (Magic Remote): pasar por encima selecciona, click abre
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { list.currentIndex = index; list.forceActiveFocus(); }
                onClicked: { list.currentIndex = index; if (parent.e) interfaces.launchPoints.doLaunch(parent.e); }
                onPressAndHold: { list.currentIndex = index; recents.showMenu(); }   // click largo: opciones
            }
        }

        // ◀ ▶ a mano: en los extremos el foco se queda (no salta a otro lado)
        Keys.onLeftPressed: { if (currentIndex > 0) decrementCurrentIndex(); event.accepted = true; }
        Keys.onRightPressed: { if (currentIndex < count - 1) incrementCurrentIndex(); event.accepted = true; }
        // OK: se abre al SOLTAR, como los botones de LG, y se aceptan las dos mitades del evento.
        // Si se abría al apretar, el Home empezaba a cerrarse, el foco pasaba a la fila nativa de LG (oculta)
        // y esa fila abría SU app al soltar (abría YouTube + Disney, o siempre Disney).
        // OK sostenido 0,7 s: en vez de abrir, muestra las opciones de la app (CleanAppMenu).
        property bool okDown: false
        Timer { id: hold; interval: 700; onTriggered: { list.okDown = false; recents.showMenu(); } }
        Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                if (!event.isAutoRepeat) { okDown = true; hold.restart(); }
                event.accepted = true;
            }
        }
        Keys.onReleased: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                event.accepted = true;
                if (event.isAutoRepeat) return;
                hold.stop();
                if (okDown && recents.currentEntry) interfaces.launchPoints.doLaunch(recents.currentEntry);
                okDown = false;
            }
        }
        onActiveFocusChanged: if (!activeFocus) { okDown = false; hold.stop(); }
    }
}
