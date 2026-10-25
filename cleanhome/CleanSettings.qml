// CleanSettings.qml — panel "Configuración" propio, con el mismo formato que el panel de Entradas (CleanInputs.qml).
// Lo abre el engranaje de la barra de arriba (MainView, z 1003).
//   1) Secciones en tarjetas: "Wi-Fi", "Widgets" (WidgetsEditor.qml: qué widgets van en el inicio, dónde y de qué
//      tamaño), "Tema" (ThemeEditor.qml: fondo, colores y letra; "Agregar foto" de fondo en FondoAgregar.qml),
//      "Control remoto" (RemoteEditor.qml: qué hace cada botón del control) y "Ajustes de LG" (abre la de LG).
//      Se pueden sumar más.
//   2) Wi-Fi: una FILA por red, con la señal dibujada y a la derecha: cartel verde "Conectada", llave verde = guardada,
//      candado = con contraseña. La red conectada aparece primera y enseguida (no espera a que termine la búsqueda).
//      Busca sola cada 5 s mientras está abierta (la rueda ⟳ gira mientras busca); ⟳ busca ya.
//      Elegir una red abre una ventanita que pregunta qué hacer: "Conectar", "Cambiar contraseña", "Olvidar esta red"
//      (según el caso). Una red nueva con clave pide la contraseña directamente. Si una guardada ya no sirve, se
//      olvida y se pide de nuevo. Olvidar la conectada también la borra del sistema de LG (la tele se desconecta).
//      Las redes sin clave se conectan mandando solo el nombre: con securityType "none" el sistema contesta
//      "Invalid parameters".
// La tele de fábrica recuerda solo la red actual: las contraseñas las guardamos en /var/lib/webosbrew/privado/wifi.json
// (carpeta solo para root, 700). Usa com.webos.service.wifi (scan, findnetworks, connect, getstatus) con el mismo
// componente que el Home de LG (WebOSServices). Flechas, OK (al soltar) y ATRÁS (al soltar: vuelve/cierra). Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import WebOSServices 1.0
import "botones.js" as Botones

FocusScope {
    id: cfg

    property bool opened: false
    signal closeRequested()

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    readonly property string store: "file:///var/lib/webosbrew/privado/wifi.json"
    // Si existe esta marca (la instalación pregunta), no se guarda ninguna contraseña ni se reconecta solo.
    readonly property string noStoreMark: "file:///var/lib/webosbrew/no-guardar-wifi"
    // Aviso para wifi/reconecta.js: "estoy usando el panel de wifi, no te metas" (lo renueva cada búsqueda).
    readonly property string busyMark: "file:///tmp/cytv-wifi-ocupado"
    property bool noStore: false
    property real s: width / 1920
    function r(v) { return v * s; }
    readonly property int cols: 3

    // picking: se está eligiendo una app en el listado de apps (Control remoto): este panel se esconde mientras tanto
    property bool picking: false
    property string pickKey: ""
    property bool capFromMenu: false    // "Asignar a un botón" desde el menú de una app: al terminar se cierra
    property Item capReturn: null       // y el foco vuelve a donde estaba (el listado de apps o los recientes)
    enabled: opened && !picking
    visible: opacity > 0.01
    opacity: opened && !picking ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    FontLoader { id: fDispB; source: cfg.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fUi; source: cfg.base + "fonts/InstrumentSans-Regular.ttf" }
    property string fDisplay: fDispB.status === FontLoader.Ready ? fDispB.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    // ---------- Estado ----------
    property string view: "menu"        // menu | wifi | widgets | theme | remote
    property var networks: []           // [{ ssid, security, bars, connected, saved }]
    property var saved: ({})            // ssid → { security, pass, last } (last = cuándo se conectó por última vez, en ms)
    property string current: ""
    property int currentBars: 0
    property int currentProfile: -1     // número con el que el sistema de LG recuerda la red conectada (para olvidarla)
    property string status: ""
    property color statusColor: "#9aa3b5"
    property bool scanning: false       // buscando redes: la rueda ⟳ gira
    // Después de pedir una búsqueda, la tele tarda ~4 s en tener la lista: antes findnetworks devuelve solo la red
    // conectada. Se vuelve a leer cada 1,5 s hasta que llegan más redes (o 10 intentos); recién ahí se muestra la
    // lista y para la rueda. "reading" = hay una búsqueda en curso (la automática de cada 5 s espera a que termine).
    property bool reading: false
    property int readTries: 0
    property string dialog: ""          // "" | "pass" (pide contraseña) | "actions" (qué hacer con la red)
    property string dlgSsid: ""
    property string dlgSec: "psk"       // "" = todavía no se sabe (la conectada antes de la primera búsqueda)
    property bool dlgConnected: false
    property bool dlgSaved: false
    property string trySsid: ""
    property string tryPass: ""
    property string trySec: "psk"
    property bool trySaved: false
    property real tryStart: 0

    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function isBack(k) { return k === WebOS.Key_webOS_Back || k === Qt.Key_Escape || k === Qt.Key_Back; }
    function wifiIcon(b) { return base + "img/wifi-" + Math.max(0, Math.min(4, b)) + ".png"; }

    property var menuItems: [
        { id: "wifi", title: "Wi-Fi", sub: current ? current : "Sin conexión", icon: wifiIcon(current ? Math.max(1, currentBars) : 0), badge: current ? "Conectada" : "" },
        { id: "widgets", title: "Widgets", sub: "Qué se ve en el inicio", icon: base + "img/widgets.png", badge: "" },
        { id: "theme", title: "Tema", sub: "Fondo, colores y letra", icon: base + "img/theme.png", badge: "" },
        { id: "remote", title: "Control remoto", sub: "Elegí qué hace cada botón", icon: base + "img/remote.png", badge: "" },
        { id: "tv", title: "Ajustes de LG", sub: "Imagen, sonido y más", icon: base + "img/gear.png", badge: "" }
    ]

    function open() {
        opened = true;
        view = "menu";
        dialog = "";
        status = "";
        loadSaved();
        statusSvc.callService({});
        menuGrid.currentIndex = 0;
        menuGrid.forceActiveFocus();
    }
    function close() {
        if (!opened) return;
        leaveSection();
        Qt.inputMethod.hide();
        opened = false;
        poll.stop();
        closeRequested();
    }
    function openSection(id) {
        if (id === "tv") { close(); interfaces.application.goToSettingsMain(); return; }
        status = "";
        if (id === "widgets") { view = "widgets"; widgetsEd.open(); return; }
        if (id === "theme") { view = "theme"; themeEd.open(); return; }
        if (id === "remote") { view = "remote"; remoteEd.open(); return; }
        view = "wifi";
        status = "";
        syncCurrent();          // la red conectada se ve de entrada, sin esperar la búsqueda
        refresh(true);
        netList.currentIndex = 0;
        netList.forceActiveFocus();
    }
    // Lo de abajo del encabezado en la sección que se ve (para ▼ desde ‹ o ✕)
    function sectionBody() { return view === "wifi" ? netList : view === "widgets" ? widgetsEd : view === "theme" ? themeEd : view === "remote" ? remoteEd : menuGrid; }
    function leaveSection() {
        if (view === "widgets") widgetsEd.leave();
        else if (view === "theme") themeEd.leave();
        else if (view === "remote") remoteEd.leave();
    }
    function goBack() {
        if (dialog) { closeDialog(); return; }
        if (view === "theme" && themeEd.back()) return;      // de "Agregar foto" vuelve a Tema
        if (view === "remote" && remoteEd.back()) return;    // cierra la ventanita o cancela el "modo elegir"
        leaveSection();
        if (view !== "menu") { view = "menu"; menuGrid.forceActiveFocus(); return; }
        close();
    }
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: { cfg.close(); if (uiController.homeShown) askPanel.restart(); }
    }
    // un botón del control con "Abrir un panel → Wi-Fi" (ver botones.js → readPanel). Se espera a que el inicio se
    // acomode (si no, se queda con el foco).
    Timer {
        id: askPanel; interval: 900
        onTriggered: Botones.readPanel(function (p) { if (p === "wifi") { Botones.clearPanel(); cfg.open(); cfg.openSection("wifi"); } })
    }

    // ---------- Control remoto ----------
    // "Asignar a un botón" (menú de una app, CleanAppMenu.qml): abre directo el "modo elegir"
    function openCapture(entry, returnTo) {
        if (!entry) return;
        capReturn = returnTo || null;
        if (!opened) { opened = true; loadSaved(); }
        dialog = "";
        status = "";
        view = "remote";
        capFromMenu = true;
        remoteEd.openCapture(entry);
    }
    // "Abrir una app": se elige en el listado de apps (CleanDrawer en "modo elegir"); mientras, este panel se esconde
    function pickAppFor(key) {
        var mv = uiController.mainView;
        var dr = mv && mv.cleanDrawer ? mv.cleanDrawer.item : null;
        if (!dr) { setStatus("No pude abrir el listado de apps", true); return; }
        pickKey = key;
        picking = true;
        var k = Botones.keyById(key);
        dr.openPick("Elegí la app para " + (k ? k.name : key), function (entry) {
            cfg.picking = false;
            remoteEd.appPicked(cfg.pickKey, entry);
            remoteEd.forceActiveFocus();
        });
    }

    // ---------- Contraseñas guardadas ----------
    function loadSaved() {
        var m = new XMLHttpRequest();
        m.onreadystatechange = function () {
            if (m.readyState !== XMLHttpRequest.DONE) return;
            cfg.noStore = (m.responseText || "").length > 0;
            if (cfg.noStore) { cfg.saved = {}; cfg.markSaved(); }
        };
        m.open("GET", noStoreMark);
        m.send();
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var j = {};
            try { j = JSON.parse(x.responseText) || {}; } catch (e) { j = {}; }
            cfg.saved = cfg.noStore ? {} : j;
            cfg.markSaved();
        };
        x.open("GET", store);
        x.send();
    }
    function writeSaved() {
        if (noStore) { markSaved(); return; }
        var x = new XMLHttpRequest();
        x.open("PUT", store);
        x.send(JSON.stringify(saved));
        markSaved();
    }
    function remember(ssid, sec, pass) {
        if (noStore) return;
        var m = saved; m[ssid] = { security: sec, pass: pass, last: Date.now() }; saved = m; writeSaved();
    }
    function markBusy() { var x = new XMLHttpRequest(); x.open("PUT", busyMark); x.send(String(Date.now())); }
    function forget(ssid) { var m = saved; delete m[ssid]; saved = m; writeSaved(); }
    // "Olvidar esta red": la saca de nuestra lista y, si es la conectada, también del sistema de LG (que solo
    // recuerda la red actual); así la tele se desconecta y no vuelve a entrar sola.
    function forgetNetwork(ssid, wasConnected) {
        forget(ssid);
        if (wasConnected && currentProfile >= 0) {
            deleteSvc.callService({ profileId: currentProfile });
            current = ""; currentProfile = -1;
            syncCurrent();
        }
        setStatus("Se olvidó " + ssid, false);
        refresh(false);
    }

    // ---------- Servicio de wifi ----------
    Service {
        id: scanSvc
        appId: "com.webos.app.fullhome"; service: "com.webos.service.wifi"; method: "scan"
        onCallSuccess: readLater.restart()
        onCallFailure: readLater.restart()
        onError: { console.warn("[cytv wifi] scan: " + errorText); readLater.restart(); }
    }
    Service {
        id: findSvc
        appId: "com.webos.app.fullhome"; service: "com.webos.service.wifi"; method: "findnetworks"
        onCallSuccess: cfg.gotNetworks(response)
        onCallFailure: { cfg.scanning = false; cfg.reading = false; cfg.setStatus("No pude leer las redes", true); console.warn("[cytv wifi] findnetworks falló: " + JSON.stringify(response)); }
        onError: { cfg.scanning = false; cfg.reading = false; cfg.setStatus("No pude leer las redes", true); console.warn("[cytv wifi] findnetworks: " + errorText); }
    }
    Service {
        id: connectSvc
        appId: "com.webos.app.fullhome"; service: "com.webos.service.wifi"; method: "connect"
        onCallSuccess: console.warn("[cytv wifi] connect aceptado")
        onCallFailure: cfg.connectFailed(response && response.errorText ? response.errorText : "")
        onError: cfg.connectFailed(errorText)
    }
    Service {
        id: statusSvc
        appId: "com.webos.app.fullhome"; service: "com.webos.service.wifi"; method: "getstatus"
        onCallSuccess: cfg.gotStatus(response)
    }
    Service {
        id: deleteSvc
        appId: "com.webos.app.fullhome"; service: "com.webos.service.wifi"; method: "deleteprofile"
        onCallFailure: console.warn("[cytv wifi] deleteprofile falló: " + JSON.stringify(response))
        onError: console.warn("[cytv wifi] deleteprofile: " + errorText)
    }

    function setStatus(t, bad) { status = t; statusColor = bad ? "#ff6b6b" : "#9aa3b5"; }
    // refresh(true) = búsqueda "a la vista" (al entrar y con el botón ⟳): la rueda gira y el botón se pone azul hasta
    // que llegan las redes. La automática de cada 5 s es silenciosa (si no, la rueda giraría todo el tiempo).
    function refresh(visible) {
        if (visible) scanning = true;
        reading = true; readTries = 0;
        markBusy();
        scanSvc.callService({});
        statusSvc.callService({});
    }
    Timer { id: readLater; interval: 1500; onTriggered: findSvc.callService({}) }
    // Busca sola cada 5 s mientras se ve la lista (no mientras se conecta o se escribe una contraseña)
    Timer {
        interval: 5000; repeat: true
        running: cfg.opened && cfg.view === "wifi" && cfg.dialog === "" && cfg.trySsid === "" && !cfg.reading
        onTriggered: cfg.refresh(false)
    }
    function gotNetworks(resp) {
        var raw = (resp && resp.foundNetworks) || [];
        // ¿la búsqueda todavía no terminó? (solo trae la conectada, o nada): se espera y se vuelve a leer
        if (raw.length <= 1 && readTries < 10) {
            readTries++;
            readLater.restart();
            return;
        }
        scanning = false;
        reading = false;
        var list = [], seen = {};
        var found = (resp && resp.foundNetworks) || [];
        for (var i = 0; i < found.length; i++) {
            var n = found[i].networkInfo;
            if (!n || !n.ssid || seen[n.ssid]) continue;
            seen[n.ssid] = true;
            var sec = (n.availableSecurityTypes && n.availableSecurityTypes.length) ? n.availableSecurityTypes[0] : "none";
            var con = n.connectState === "ipConfigured";
            if (con) {
                current = n.ssid; currentBars = n.signalBars || 0;
                if (n.profileId !== undefined) currentProfile = n.profileId;
            }
            list.push({ ssid: n.ssid, security: sec, bars: n.signalBars || 0, connected: con });
        }
        list.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            var sa = !!cfg.saved[a.ssid], sb = !!cfg.saved[b.ssid];
            if (sa !== sb) return sa ? -1 : 1;
            return b.bars - a.bars;
        });
        setNetworks(list);
    }
    // Cambia la lista manteniendo el foco en la misma red aunque cambie el orden. Si nada cambió, no la toca
    // (reasignar la lista rearma las filas y se notaría un parpadeo cada 5 s).
    function setNetworks(list) {
        var l = [];     // copias nuevas: nunca se modifican los objetos que está mostrando la lista
        for (var i = 0; i < list.length; i++) {
            var o = list[i];
            l.push({ ssid: o.ssid, security: o.security, bars: o.bars, connected: o.connected, saved: !!saved[o.ssid] });
        }
        if (JSON.stringify(l) === JSON.stringify(networks)) return;
        var keep = netList.currentItem && netList.currentItem.n ? netList.currentItem.n.ssid : "";
        networks = l;
        if (keep) for (var k = 0; k < l.length; k++) if (l[k].ssid === keep) { netList.currentIndex = k; break; }
    }
    // La red conectada va primera y se ve aunque la búsqueda todavía no haya terminado (o no la haya traído).
    function syncCurrent() {
        var l = [], cur = null;
        for (var i = 0; i < networks.length; i++) {
            var o = networks[i];
            var c = current !== "" && o.ssid === current;
            var x = { ssid: o.ssid, security: o.security, bars: o.bars, connected: c };
            if (c) cur = x; else l.push(x);
        }
        if (current !== "" && !cur) {
            var sv = saved[current];
            cur = { ssid: current, security: sv ? sv.security : "", bars: Math.max(1, currentBars), connected: true };
        }
        if (cur) l.unshift(cur);
        setNetworks(l);
    }
    function markSaved() { setNetworks(networks.slice(0)); }

    // ---------- Conectar ----------
    // Elegir una red pregunta qué hacer. Solo una red nueva con clave va directo a pedir la contraseña.
    function choose(n) {
        if (!n || trySsid !== "") return;
        if (!n.connected && !saved[n.ssid] && n.security !== "none" && n.security !== "") {
            openDialog("pass", n.ssid, n.security);
            return;
        }
        dlgConnected = n.connected;
        openDialog("actions", n.ssid, n.security);
    }
    function connectTo(ssid, sec) {
        var sv = saved[ssid];
        if (sec === "none") { startConnect(ssid, "none", "", false); return; }
        if (sv && sv.pass) { startConnect(ssid, sec, sv.pass, true); return; }
        openDialog("pass", ssid, sec);
    }
    function openDialog(kind, ssid, sec) {
        dialog = kind; dlgSsid = ssid; dlgSec = sec;
        dlgSaved = !!saved[ssid];
        if (kind === "pass") { passField.text = ""; passField.forceActiveFocus(); }
        else dlgButtons()[0].forceActiveFocus();
    }
    // Botones visibles de la ventanita, en orden (para moverse con ◀ ▶)
    function dlgButtons() {
        var all = dialog === "pass" ? [connectBtn, cancelBtn] : [actConnect, actPass, actForget, cancelBtn];
        var l = [];
        for (var i = 0; i < all.length; i++) if (all[i].visible) l.push(all[i]);
        return l;
    }
    function dlgMove(from, step) {
        var l = dlgButtons();
        for (var i = 0; i < l.length; i++) if (l[i] === from) { var j = i + step; if (j >= 0 && j < l.length) l[j].forceActiveFocus(); return; }
    }
    function closeDialog() {
        Qt.inputMethod.hide();
        dialog = "";
        netList.forceActiveFocus();
    }
    function startConnect(ssid, sec, pass, usingSaved) {
        if (dialog) closeDialog();
        trySsid = ssid; tryPass = pass; trySec = sec; trySaved = usingSaved; tryStart = Date.now();
        setStatus("Conectando a " + ssid + "…", false);
        // Red sin clave: solo el nombre. Con { securityType: "none" } el sistema contesta "Invalid parameters".
        var p = { ssid: ssid };
        if (sec !== "none") p.security = { securityType: sec, simpleSecurity: { passKey: pass } };
        connectSvc.callService(p);
        markBusy();
        poll.restart();
    }
    // El servicio avisa la falla dos veces (onCallFailure y onError): solo cuenta la primera.
    function connectFailed(why) { console.warn("[cytv wifi] connect falló: " + why); if (trySsid) endTry(false); }
    function gotStatus(resp) {
        var n = resp && resp.networkInfo;
        if (!trySsid) {
            if (n && n.connectState === "ipConfigured") {
                current = n.ssid || current; currentBars = n.signalBars || currentBars;
                if (n.profileId !== undefined) currentProfile = n.profileId;
            } else if (resp && resp.returnValue) {
                current = ""; currentProfile = -1;      // ya no está conectada a ninguna
            }
            if (view === "wifi") syncCurrent();
            return;
        }
        if (n && n.ssid === trySsid && n.connectState === "ipConfigured") { endTry(true); return; }
        if (Date.now() - tryStart > 35000) endTry(false);
    }
    function endTry(ok) {
        poll.stop();
        var ssid = trySsid, sec = trySec, pass = tryPass, usedSaved = trySaved;
        trySsid = "";
        if (ok) {
            current = ssid;
            if (pass || sec === "none") remember(ssid, sec, pass);   // las abiertas también, para reconectarse solas
            setStatus("", false);
            refresh(false);
        } else if (usedSaved) {
            forget(ssid);                                   // la guardada ya no sirve: se olvida y se pide de nuevo
            setStatus("La contraseña guardada no funcionó", true);
            openDialog("pass", ssid, sec);
        } else if (pass) {
            setStatus("No pude conectar: revisá la contraseña", true);
            openDialog("pass", ssid, sec);
        } else {
            setStatus("No pude conectar a " + ssid, true);
        }
    }
    Timer { id: poll; interval: 2000; repeat: true; onTriggered: statusSvc.callService({}) }

    // ATRÁS actúa al soltar (como el Home de LG); nada se escapa a la pantalla de abajo
    Keys.onPressed: { if (isBack(event.key)) event.accepted = true; }
    Keys.onReleased: { if (isBack(event.key)) { event.accepted = true; cfg.goBack(); } }

    // ---------- Pantalla ----------
    Rectangle { anchors.fill: parent; color: Qt.rgba(11 / 255, 13 / 255, 18 / 255, 0.97) }
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    Item {
        id: panel
        width: r(1350); height: r(840)
        anchors.centerIn: parent

        // Encabezado: ‹ (en Wi-Fi) + título · ⟳ (en Wi-Fi) + ✕
        Row {
            id: head
            spacing: r(14)
            RoundIcon {
                id: backBtn
                visible: cfg.view !== "menu"
                anchors.verticalCenter: parent.verticalCenter
                s: cfg.s; icon: cfg.base + "img/back.png"
                onClicked: cfg.goBack()
                Keys.onRightPressed: (refreshBtn.visible ? refreshBtn : closeBtn).forceActiveFocus()
                Keys.onDownPressed: cfg.sectionBody().forceActiveFocus()
            }
            Text {
                text: cfg.view === "wifi" ? "Wi-Fi" : cfg.view === "widgets" ? "Widgets" : cfg.view === "theme" ? (themeEd.adding ? "Agregar foto" : "Tema")
                      : cfg.view === "remote" ? (remoteEd.capturing ? "Asignar a un botón" : "Control remoto") : "Configuración"
                color: "#eef1f6"; font.family: cfg.fDisplay; font.pixelSize: r(60); font.weight: Font.Bold
            }
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: head.verticalCenter
            spacing: r(18)
            RoundIcon {
                id: refreshBtn
                visible: cfg.view === "wifi"
                s: cfg.s; icon: cfg.base + "img/refresh.png"
                spinning: cfg.scanning || cfg.trySsid !== ""
                busy: spinning
                Keys.onLeftPressed: if (backBtn.visible) backBtn.forceActiveFocus()
                onClicked: cfg.refresh(true)
                Keys.onRightPressed: closeBtn.forceActiveFocus()
                Keys.onDownPressed: netList.forceActiveFocus()
            }
            RoundIcon {
                id: closeBtn
                s: cfg.s; cross: true
                onClicked: cfg.close()
                Keys.onLeftPressed: { if (refreshBtn.visible) refreshBtn.forceActiveFocus(); else if (backBtn.visible) backBtn.forceActiveFocus(); }
                Keys.onDownPressed: cfg.sectionBody().forceActiveFocus()
            }
        }
        Text {
            id: statusLine
            visible: cfg.status !== ""
            anchors.top: head.bottom; anchors.topMargin: r(10)
            text: cfg.status
            color: cfg.statusColor; font.family: cfg.fBody; font.pixelSize: r(28)
        }

        // ----- Secciones -----
        GridView {
            id: menuGrid
            visible: cfg.view === "menu"
            y: r(110); width: parent.width; height: parent.height - y
            cellWidth: width / cfg.cols; cellHeight: r(250)
            interactive: true; focus: true; keyNavigationWraps: false
            model: cfg.menuItems
            property bool okDown: false
            delegate: Card {
                width: menuGrid.cellWidth; height: menuGrid.cellHeight
                s: cfg.s; fDisplay: cfg.fDisplay; fBody: cfg.fBody
                sel: GridView.isCurrentItem && menuGrid.activeFocus
                icon: modelData.icon; title: modelData.title; sub: modelData.sub; badge: modelData.badge
                onHovered: { menuGrid.currentIndex = index; menuGrid.forceActiveFocus(); }
                onClicked: cfg.openSection(modelData.id)
            }
            Keys.onUpPressed: { if (currentIndex < cfg.cols) closeBtn.forceActiveFocus(); else event.accepted = false; }
            Keys.onPressed: { if (cfg.isOk(event.key)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
            Keys.onReleased: {
                if (cfg.isOk(event.key)) { event.accepted = true; if (okDown && !event.isAutoRepeat) cfg.openSection(cfg.menuItems[currentIndex].id); okDown = false; }
            }
        }

        // ----- Redes: una fila por red -----
        ListView {
            id: netList
            visible: cfg.view === "wifi"
            y: r(130); width: parent.width; height: parent.height - y
            spacing: r(12)
            interactive: true; clip: true; keyNavigationWraps: false
            highlightMoveDuration: 150
            model: cfg.networks
            property bool okDown: false
            delegate: Item {
                id: row
                property var n: modelData
                property bool sel: ListView.isCurrentItem && netList.activeFocus
                width: netList.width; height: cfg.r(104)
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: cfg.r(6); anchors.rightMargin: cfg.r(6)
                    radius: cfg.r(22)
                    color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 0.98)
                    border.width: row.sel ? cfg.r(4) : 1
                    border.color: row.sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
                    opacity: cfg.trySsid !== "" && cfg.trySsid !== row.n.ssid && !row.sel ? 0.45 : 1
                    Image {
                        x: cfg.r(30); anchors.verticalCenter: parent.verticalCenter
                        width: cfg.r(60); height: cfg.r(50); smooth: true
                        source: cfg.wifiIcon(row.n.bars)
                    }
                    Text {
                        x: cfg.r(120); anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - cfg.r(260); elide: Text.ElideRight
                        text: row.n.ssid
                        color: "#eef1f6"; font.family: cfg.fDisplay; font.pixelSize: cfg.r(38); font.weight: Font.Bold
                    }
                    // a la derecha: cartel verde (conectada / conectando) o ícono (llave = guardada, candado = con contraseña)
                    Rectangle {
                        property string label: row.n.connected ? "Conectada" : (cfg.trySsid === row.n.ssid ? "Conectando…" : "")
                        visible: label !== ""
                        anchors.right: parent.right; anchors.rightMargin: cfg.r(30); anchors.verticalCenter: parent.verticalCenter
                        width: pill.implicitWidth + cfg.r(24); height: cfg.r(38); radius: height / 2
                        color: Qt.rgba(61 / 255, 220 / 255, 151 / 255, 0.16)
                        Text { id: pill; anchors.centerIn: parent; text: parent.label; color: "#3ddc97"; font.family: cfg.fBody; font.pixelSize: cfg.r(22); font.weight: Font.DemiBold }
                    }
                    Image {
                        visible: !row.n.connected && cfg.trySsid !== row.n.ssid && (row.n.saved || row.n.security !== "none")
                        anchors.right: parent.right; anchors.rightMargin: cfg.r(34); anchors.verticalCenter: parent.verticalCenter
                        width: cfg.r(42); height: cfg.r(42); smooth: true
                        source: cfg.base + "img/" + (row.n.saved ? "key.png" : "lock.png")
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: { netList.currentIndex = index; netList.forceActiveFocus(); }
                    onClicked: { netList.currentIndex = index; cfg.choose(row.n); }
                }
            }
            // debajo de la lista (o sola, si todavía no hay ninguna): "Buscando redes…" mientras gira la rueda
            footer: Item {
                width: netList.width
                height: cfg.scanning || netList.count === 0 ? cfg.r(70) : 0
                Text {
                    visible: parent.height > 0
                    x: cfg.r(30); anchors.verticalCenter: parent.verticalCenter
                    text: cfg.scanning || netList.count === 0 ? "Buscando redes…" : ""
                    color: "#9aa3b5"; font.family: cfg.fBody; font.pixelSize: cfg.r(32)
                }
            }
            Keys.onUpPressed: { if (currentIndex <= 0) refreshBtn.forceActiveFocus(); else event.accepted = false; }
            Keys.onPressed: { if (cfg.isOk(event.key)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
            Keys.onReleased: {
                if (cfg.isOk(event.key)) { event.accepted = true; if (okDown && !event.isAutoRepeat && currentItem) cfg.choose(currentItem.n); okDown = false; }
            }
        }
        // ----- Widgets del inicio y tema -----
        WidgetsEditor {
            id: widgetsEd
            visible: cfg.view === "widgets"
            y: r(120); width: parent.width; height: parent.height - y
            s: cfg.s; fBody: cfg.fBody; fDisplay: cfg.fDisplay
        }
        ThemeEditor {
            id: themeEd
            visible: cfg.view === "theme"
            y: r(120); width: parent.width; height: parent.height - y
            s: cfg.s; fBody: cfg.fBody; fDisplay: cfg.fDisplay
        }
        RemoteEditor {
            id: remoteEd
            visible: cfg.view === "remote"
            y: r(120); width: parent.width; height: parent.height - y
            s: cfg.s; fBody: cfg.fBody; fDisplay: cfg.fDisplay
            onRequestAppPick: cfg.pickAppFor(key)
            onExitUp: closeBtn.forceActiveFocus()
            onCaptureFinished: {
                if (cfg.capFromMenu) {
                    var rt = cfg.capReturn;
                    cfg.capFromMenu = false; cfg.capReturn = null;
                    cfg.close();
                    if (rt) rt.forceActiveFocus();
                } else remoteEd.open();
            }
        }
    }

    // ----- Ventanita: qué hacer con la red / contraseña -----
    Rectangle {
        visible: cfg.dialog !== ""
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: cfg.closeDialog() }
    }
    Rectangle {
        id: dlg
        visible: cfg.dialog !== ""
        width: r(1100); height: dlgCol.height + r(80)
        anchors.centerIn: parent
        radius: r(28)
        color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 1)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
        MouseArea { anchors.fill: parent }      // los clicks adentro no cierran
        Column {
            id: dlgCol
            x: r(48); y: r(40); width: parent.width - r(96)
            spacing: r(24)
            Row {
                spacing: r(16)
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: r(48); height: r(48); smooth: true
                    source: cfg.base + "img/" + (cfg.dialog === "pass" ? "lock.png" : (cfg.dlgSaved ? "key.png" : "wifi-3.png"))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: dlgCol.width - r(64); elide: Text.ElideRight
                    text: cfg.dlgSsid
                    color: "#eef1f6"; font.family: cfg.fDisplay; font.pixelSize: r(44); font.weight: Font.Bold
                }
            }
            // Qué es esta red (solo en la de opciones)
            Text {
                visible: cfg.dialog === "actions"
                width: dlgCol.width; wrapMode: Text.WordWrap
                text: cfg.dlgConnected
                      ? (cfg.dlgSaved ? "La tele está conectada a esta red. Si la olvidás, se desconecta." : "La tele está conectada a esta red.")
                      : (cfg.dlgSaved ? "Red guardada: se conecta sin pedir la contraseña." : (cfg.dlgSec === "none" ? "Red sin contraseña." : "Red con contraseña."))
                color: "#9aa3b5"; font.family: cfg.fBody; font.pixelSize: r(28)
            }
            CField {
                id: passField
                visible: cfg.dialog === "pass"
                s: cfg.s; family: cfg.fBody; width: dlgCol.width; secret: true
                placeholder: cfg.dlgSaved || cfg.dlgConnected ? "Contraseña nueva" : "Contraseña"
                onAccepted: connectBtn.forceActiveFocus()
                Keys.onDownPressed: connectBtn.forceActiveFocus()
            }
            Text {
                visible: cfg.dialog !== "" && cfg.status !== "" && cfg.statusColor === "#ff6b6b"
                width: dlgCol.width; wrapMode: Text.WordWrap
                text: cfg.status
                color: "#ff6b6b"; font.family: cfg.fBody; font.pixelSize: r(26)
            }
            Row {
                spacing: r(20)
                // -- contraseña --
                CButton {
                    id: connectBtn
                    visible: cfg.dialog === "pass"
                    s: cfg.s; family: cfg.fBody; text: "Conectar"; primary: true
                    onClicked: {
                        if (passField.text.length < 8) { cfg.setStatus("La contraseña tiene al menos 8 caracteres", true); passField.forceActiveFocus(); }
                        else cfg.startConnect(cfg.dlgSsid, cfg.dlgSec, passField.text, false);
                    }
                    Keys.onUpPressed: passField.forceActiveFocus()
                    Keys.onRightPressed: cfg.dlgMove(connectBtn, 1)
                }
                // -- qué hacer con la red --
                CButton {
                    id: actConnect
                    visible: cfg.dialog === "actions" && !cfg.dlgConnected
                    s: cfg.s; family: cfg.fBody; text: "Conectar"; primary: true
                    onClicked: cfg.connectTo(cfg.dlgSsid, cfg.dlgSec)
                    Keys.onLeftPressed: cfg.dlgMove(actConnect, -1)
                    Keys.onRightPressed: cfg.dlgMove(actConnect, 1)
                }
                CButton {
                    id: actPass
                    visible: cfg.dialog === "actions" && (cfg.dlgSaved || cfg.dlgConnected) && cfg.dlgSec !== "none" && cfg.dlgSec !== ""
                    s: cfg.s; family: cfg.fBody; text: "Cambiar contraseña"
                    onClicked: cfg.openDialog("pass", cfg.dlgSsid, cfg.dlgSec)
                    Keys.onLeftPressed: cfg.dlgMove(actPass, -1)
                    Keys.onRightPressed: cfg.dlgMove(actPass, 1)
                }
                CButton {
                    id: actForget
                    visible: cfg.dialog === "actions" && (cfg.dlgSaved || cfg.dlgConnected)
                    s: cfg.s; family: cfg.fBody; text: "Olvidar esta red"
                    onClicked: { var ssid = cfg.dlgSsid, was = cfg.dlgConnected; cfg.closeDialog(); cfg.forgetNetwork(ssid, was); }
                    Keys.onLeftPressed: cfg.dlgMove(actForget, -1)
                    Keys.onRightPressed: cfg.dlgMove(actForget, 1)
                }
                CButton {
                    id: cancelBtn
                    s: cfg.s; family: cfg.fBody; text: "Cancelar"
                    onClicked: cfg.closeDialog()
                    Keys.onUpPressed: if (cfg.dialog === "pass") passField.forceActiveFocus()
                    Keys.onLeftPressed: cfg.dlgMove(cancelBtn, -1)
                }
            }
        }
    }
}
