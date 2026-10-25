// CleanDetail.qml — ventana de detalle a pantalla completa que abren los paneles de CleanTop (OK o click).
// Lo carga MainView.qml (z 1002) y se abre con open(tipo, datos):
//   "day" → calendario: todos los eventos del día tocado, con horario, título completo, lugar y descripción.
//   "wx"  → clima: las próximas 24 horas (hora, ícono, temperatura, lluvia y viento) + resumen del día.
//   "fx"  → mercados: dólar blue, oficial, MEP y cripto (compra y venta), Bitcoin y Ethereum, con variación del día,
//           variación en 30 días y gráfico de 30 días. MEP y ETH aparecen solo acá.
//   "saver" → abre directo el protector de pantalla, con un botón "Editar" arriba (OK) y ✕ para salir (ATRÁS).
//             Los botones se esconden a los 5 s y vuelven con cualquier tecla o moviendo el puntero.
//             "Editar" abre SaverEditor.qml encima del mismo protector (partes de la pantalla, encendido, segundos, álbum).
// Botón "Editar" (o OK) abre CleanEdit.qml con los ajustes de ese panel; ATRÁS ahí vuelve sin guardar.
// ▲ ▼ desplazan el contenido si no entra; ATRÁS (al soltar, como el Home de LG) o ✕ cierran. Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import "settings.js" as Settings

FocusScope {
    id: det

    property bool opened: false
    signal closeRequested()

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real s: width / 1920
    function r(v) { return v * s; }

    property string mode: ""        // day | wx | fx | saver
    property bool editing: false
    property bool previewing: false
    property bool ctrls: true        // botones sobre el protector (se esconden solos)
    property bool saverEditing: false // editor visual del protector abierto
    property var payload: null

    enabled: opened
    visible: opacity > 0.01
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    readonly property color cFg: "#eef1f6"
    readonly property color cMuted: "#9aa3b5"
    readonly property color cFaint: "#5d6576"
    readonly property color cRain: "#6fa8ff"
    readonly property color cUp: "#3ddc97"
    readonly property color cDown: "#ff6b6b"
    readonly property var palette: ["#6fa8ff", "#3ddc97", "#f5b83d", "#ff8fa3", "#b18cff", "#5ad1e6", "#ff9f5a"]

    FontLoader { id: fDispB; source: det.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fDispM; source: det.base + "fonts/Bricolage-Medium.ttf" }
    FontLoader { id: fUi; source: det.base + "fonts/InstrumentSans-Regular.ttf" }
    property string fTitle: fDispB.status === FontLoader.Ready ? fDispB.name : "Droid Sans"
    property string fDisplay: fDispM.status === FontLoader.Ready ? fDispM.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    // ---------- Utilidades ----------
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function hhmm(t) { var d = new Date(t); return pad2(d.getHours()) + ":" + pad2(d.getMinutes()); }
    function fmtInt(n) {
        var str = String(Math.round(Math.abs(n))), out = "";
        while (str.length > 3) { out = "." + str.slice(-3) + out; str = str.slice(0, -3); }
        return (n < 0 ? "-" : "") + str + out;
    }
    function fmtPct(p) {
        if (p === null || p === undefined || isNaN(p)) return "";
        return (p > 0.005 ? "+" : (p < -0.005 ? "−" : "")) + Math.abs(p).toFixed(2).replace(".", ",") + "%";
    }
    function pct(cur, prev) { return (cur && prev) ? (cur - prev) / prev * 100 : null; }
    function colorOf(title) {
        var h = 0;
        for (var i = 0; i < title.length; i++) h = (h * 31 + title.charCodeAt(i)) & 0xffff;
        return palette[h % palette.length];
    }
    function wxInfo(code) {
        if (code === 0) return ["sun", "Despejado"];
        if (code === 1) return ["partly", "Mayormente despejado"];
        if (code === 2) return ["partly", "Parcialmente nublado"];
        if (code === 3) return ["cloud", "Nublado"];
        if (code === 45 || code === 48) return ["fog", "Niebla"];
        if (code >= 51 && code <= 57) return ["drizzle", "Llovizna"];
        if (code >= 61 && code <= 67) return ["rain", "Lluvia"];
        if (code >= 80 && code <= 82) return ["rain", "Chaparrones"];
        if (code >= 95) return ["storm", "Tormenta"];
        return ["cloud", "Nublado"];
    }
    function wxIcon(code, isDay) {
        var k = wxInfo(code)[0];
        if (!isDay && k === "sun") return "moon";
        if (!isDay && k === "partly") return "moon-partly";
        return k;
    }
    function getJSON(url, cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var j = null;
            if (x.status === 200) { try { j = JSON.parse(x.responseText); } catch (e) { j = null; } }
            cb(j);
        };
        x.open("GET", url);
        x.send();
    }

    // ---------- Abrir / cerrar ----------
    function isBack(k) { return k === WebOS.Key_webOS_Back || k === Qt.Key_Escape || k === Qt.Key_Back; }
    function open(kind, data) {
        mode = kind;
        payload = data;
        editing = false;
        previewing = false;
        flick.contentY = 0;
        if (kind === "wx") buildHours();
        if (kind === "fx") loadMarkets();
        opened = true;
        if (kind === "saver") previewing = true;
        det.forceActiveFocus();
    }
    function close() {
        if (!opened) return;
        if (saverEditing) { saverEditing = false; if (saverLoader.item) { saverLoader.item.editing = false; saverLoader.item.layoutOverride = null; } }
        Qt.inputMethod.hide();
        opened = false;
        editing = false;
        previewing = false;
        closeRequested();
    }
    function startEdit() {
        if (mode === "saver") {
            if (!saverLoader.item) return;
            saverEditing = true;
            saverEd.open(saverLoader.item);
            return;
        }
        editing = true;
        editor.open(mode);
    }
    function endSaverEdit(saved) {
        saverEditing = false;
        det.forceActiveFocus();
        if (saved) { previewing = false; reopenSaver.restart(); }   // se vuelve a crear con los ajustes nuevos
        else showCtrls();
    }
    function endEdit(saved) {
        Qt.inputMethod.hide();
        editing = false;
        if (saved) det.close();          // al guardar se vuelve a la pantalla de inicio, que ya toma los cambios
        else det.forceActiveFocus();
    }
    // el protector se vuelve a crear para que lea los ajustes recién guardados
    Timer { id: reopenSaver; interval: 50; onTriggered: if (det.opened && det.mode === "saver") det.previewing = true }
    function showCtrls() { ctrls = true; hideCtrls.restart(); }
    Timer { id: hideCtrls; interval: 5000; onTriggered: det.ctrls = false }
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: det.close()
    }
    Keys.onPressed: {
        if (saverEditing) { event.accepted = true; return; }
        if (previewing) { event.accepted = true; showCtrls(); return; }
        if (isBack(event.key)) { event.accepted = true; return; }
        if (editing) { event.accepted = true; return; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) { event.accepted = true; return; }
        var step = r(160);
        if (event.key === Qt.Key_Down) { flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + step); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { flick.contentY = Math.max(0, flick.contentY - step); event.accepted = true; }
        else event.accepted = true;     // nada se escapa a la pantalla de abajo mientras la ventana está abierta
    }
    Keys.onReleased: {
        event.accepted = true;
        if (saverEditing) return;
        if (previewing) {                                                     // sobre el protector: OK edita, ATRÁS sale
            if (isBack(event.key)) det.close();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) det.startEdit();
            return;
        }
        if (isBack(event.key)) { if (editing) det.endEdit(false); else det.close(); return; }
        if (!editing && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select)) det.startEdit();
    }

    // ---------- Clima: próximas 24 horas ----------
    property var hours: []
    function buildHours() {
        var wx = payload ? payload.wx : null, out = [];
        if (wx && wx.hourly) {
            var h = wx.hourly, now = new Date();
            var key = now.getFullYear() + "-" + pad2(now.getMonth() + 1) + "-" + pad2(now.getDate()) + "T" + pad2(now.getHours()) + ":00";
            var i0 = Math.max(0, h.time.indexOf(key));
            for (var i = i0; i < h.time.length && out.length < 24; i++)
                out.push({ t: h.time[i].slice(11, 16), temp: h.temperature_2m[i], code: h.weather_code[i], day: h.is_day[i] === 1,
                           pop: h.precipitation_probability ? h.precipitation_probability[i] : 0,
                           wind: h.wind_speed_10m ? h.wind_speed_10m[i] : null, hum: h.relative_humidity_2m ? h.relative_humidity_2m[i] : null });
        }
        hours = out;
    }

    // ---------- Mercados ----------
    property var markets: []
    property var histCache: ({})          // casa -> [{fecha, compra, venta}] (se guarda 30 min)
    property real histT: 0
    property var ethSerie: []
    function seriesOf(list, key) {
        var out = [];
        if (!list) return out;
        for (var k = Math.max(0, list.length - 30); k < list.length; k++) out.push(list[k][key]);
        return out;
    }
    function ayerOf(list) {
        if (!list || !list.length) return null;
        var t = new Date(), today = t.getFullYear() + "-" + pad2(t.getMonth() + 1) + "-" + pad2(t.getDate());
        for (var i = list.length - 1; i >= 0; i--) if (list[i].fecha < today) return list[i];
        return null;
    }
    function rebuildMarkets() {
        var fx = payload ? payload.fx : null, out = [];
        var casas = [["Dólar blue", "blue"], ["Dólar oficial", "oficial"], ["Dólar MEP", "bolsa"], ["Dólar cripto", "cripto"]];
        for (var i = 0; i < casas.length; i++) {
            var q = fx ? fx[casas[i][1]] : null;
            if (!q) continue;
            var h = histCache[casas[i][1]];
            var serie = seriesOf(h, "venta").concat([q.venta]);
            var ay = ayerOf(h);
            out.push({ name: casas[i][0], dollar: true, compra: q.compra, venta: q.venta, serie: serie,
                       day: pct(q.venta, ay ? ay.venta : 0), long: serie.length > 1 ? pct(q.venta, serie[0]) : null });
        }
        var btc = payload && payload.btc ? payload.btc.map(function (p) { return p[1]; }) : [];
        if (btc.length > 1) out.push({ name: "Bitcoin", sub: "BTC", dollar: false, price: btc[btc.length - 1], serie: btc,
                                       day: pct(btc[btc.length - 1], btc[btc.length - 2]), long: pct(btc[btc.length - 1], btc[0]) });
        if (ethSerie.length > 1) out.push({ name: "Ethereum", sub: "ETH", dollar: false, price: ethSerie[ethSerie.length - 1], serie: ethSerie,
                                            day: pct(ethSerie[ethSerie.length - 1], ethSerie[ethSerie.length - 2]), long: pct(ethSerie[ethSerie.length - 1], ethSerie[0]) });
        markets = out;
    }
    function loadMarkets() {
        rebuildMarkets();
        if (Date.now() - histT < 30 * 60000) return;
        histT = Date.now();
        ["blue", "oficial", "bolsa", "cripto"].forEach(function (casa) {
            getJSON("https://api.argentinadatos.com/v1/cotizaciones/dolares/" + casa, function (j) {
                if (j && j.length) { var c = det.histCache; c[casa] = j.slice(-40); det.histCache = c; det.rebuildMarkets(); }
            });
        });
        getJSON("https://api.coingecko.com/api/v3/coins/ethereum/market_chart?vs_currency=usd&days=30&interval=daily", function (j) {
            if (j && j.prices) { det.ethSerie = j.prices.map(function (p) { return p[1]; }); det.rebuildMarkets(); }
        });
    }
    function drawChart(cv, s) {
        var ctx = cv.getContext("2d");
        ctx.reset();
        if (!s || s.length < 2) return;
        var w = cv.width, h = cv.height, pad = r(5);
        var mn = Math.min.apply(null, s), mx = Math.max.apply(null, s), span = Math.max(1e-9, mx - mn);
        var up = s[s.length - 1] >= s[0], col = up ? "#3ddc97" : "#ff6b6b";
        function X(i) { return pad + i / (s.length - 1) * (w - pad * 2); }
        function Y(v) { return pad + (1 - (v - mn) / span) * (h - pad * 2); }
        ctx.fillStyle = "rgba(238,241,246,0.5)";
        for (var dx = pad; dx < w - pad; dx += r(8)) ctx.fillRect(dx, Y(s[0]) - r(1), r(3), r(2));
        var g = ctx.createLinearGradient(0, 0, 0, h);
        g.addColorStop(0, up ? "rgba(61,220,151,0.22)" : "rgba(255,107,107,0.22)");
        g.addColorStop(1, "rgba(0,0,0,0)");
        ctx.beginPath(); ctx.moveTo(X(0), h);
        for (var i = 0; i < s.length; i++) ctx.lineTo(X(i), Y(s[i]));
        ctx.lineTo(X(s.length - 1), h); ctx.closePath(); ctx.fillStyle = g; ctx.fill();
        ctx.beginPath();
        for (var k = 0; k < s.length; k++) { if (k === 0) ctx.moveTo(X(k), Y(s[k])); else ctx.lineTo(X(k), Y(s[k])); }
        ctx.strokeStyle = col; ctx.lineWidth = r(2.5); ctx.lineJoin = "round"; ctx.stroke();
        ctx.beginPath(); ctx.arc(X(s.length - 1), Y(s[s.length - 1]), r(5), 0, Math.PI * 2); ctx.fillStyle = col; ctx.fill();
    }

    // ---------- Pantalla ----------
    Rectangle { anchors.fill: parent; color: Qt.rgba(11 / 255, 13 / 255, 18 / 255, 0.97) } // casi opaco
    // Tapa el puntero del control: que no seleccione lo que queda debajo
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    Text {
        id: title
        x: r(96); y: r(56)
        width: r(1500); elide: Text.ElideRight
        text: det.mode === "day" ? (det.payload ? det.payload.title : "")
            : det.mode === "wx" ? "Clima por hora · " + (det.payload && det.payload.place ? det.payload.place : "")
            : det.mode === "fx" ? "Mercados"
            : det.mode === "saver" ? "Protector de pantalla" : ""
        color: det.cFg; font.family: det.fTitle; font.pixelSize: r(64); font.weight: Font.Bold
    }
    Text {
        anchors.right: editBtn.visible ? editBtn.left : closeBtn.left; anchors.rightMargin: r(28); anchors.verticalCenter: closeBtn.verticalCenter
        text: det.editing ? "Flechas: mover  ·  OK: elegir  ·  ATRÁS: volver sin guardar" : "OK: editar  ·  ATRÁS: cerrar"
        color: "#7a8396"; font.family: det.fBody; font.pixelSize: r(26)
    }
    // Botón "Editar" (con el puntero; con el control alcanza con OK)
    Rectangle {
        id: editBtn
        visible: !det.editing
        property bool lit: editMouse.containsMouse
        anchors.right: closeBtn.left; anchors.rightMargin: r(18); anchors.verticalCenter: closeBtn.verticalCenter
        width: editTxt.implicitWidth + r(48); height: r(68); radius: height / 2
        color: lit ? "#eef1f6" : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, lit ? 0 : 0.14)
        Text {
            id: editTxt
            anchors.centerIn: parent
            text: "✎  Editar"
            color: editBtn.lit ? "#0b0d12" : "#eef1f6"; font.family: det.fBody; font.pixelSize: r(30); font.weight: Font.DemiBold
        }
        MouseArea { id: editMouse; anchors.fill: parent; hoverEnabled: true; onClicked: det.startEdit() }
    }
    Rectangle {
        id: closeBtn
        property bool lit: closeMouse.containsMouse
        x: r(1824) - width; anchors.verticalCenter: title.verticalCenter
        width: r(68); height: r(68); radius: width / 2
        color: lit ? "#eef1f6" : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, lit ? 0 : 0.14)
        Repeater {
            model: [45, -45]
            Rectangle {
                anchors.centerIn: parent
                width: r(28); height: r(3.5); radius: height / 2
                rotation: modelData
                color: closeBtn.lit ? "#0b0d12" : "#eef1f6"
            }
        }
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: det.close() }
    }

    CleanEdit {
        id: editor
        visible: det.editing
        x: r(96); y: r(170); width: r(1728); height: parent.height - y - r(50)
        s: det.s; fBody: det.fBody; fTitle: det.fTitle
        onDone: det.endEdit(saved)
    }

    Flickable {
        id: flick
        visible: !det.editing
        x: r(96); y: r(170); width: r(1728); height: parent.height - y - r(50)
        contentWidth: width; contentHeight: content.height
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentY { NumberAnimation { duration: 160 } }

        Item {
            id: content
            width: flick.width
            height: det.mode === "day" ? dayCol.height : det.mode === "wx" ? wxBox.height : det.mode === "fx" ? fxCol.height : 0

            // ===== Día del calendario =====
            Column {
                id: dayCol
                visible: det.mode === "day"
                width: parent.width
                spacing: r(28)
                Text {
                    visible: !det.payload || !det.payload.events || det.payload.events.length === 0
                    text: "Sin eventos este día"
                    color: det.cMuted; font.family: det.fBody; font.pixelSize: r(40)
                }
                Repeater {
                    model: det.mode === "day" && det.payload ? det.payload.events : []
                    delegate: Item {
                        id: evItem
                        property var e: modelData
                        property bool over: !e.allDay && e.end <= Date.now()
                        width: dayCol.width; height: evText.height + r(28)
                        opacity: over ? 0.55 : 1
                        Rectangle { anchors.fill: parent; radius: r(20); color: Qt.rgba(1, 1, 1, 0.05) }
                        Rectangle { x: r(20); y: r(18); width: r(8); height: parent.height - r(36); radius: r(4); color: det.colorOf(evItem.e.title) }
                        Column {
                            id: evText
                            x: r(52); y: r(14); width: parent.width - r(84)
                            spacing: r(6)
                            Text {
                                text: evItem.e.allDay ? "Todo el día" : (evItem.e.first ? det.hhmm(evItem.e.start) + " – " + det.hhmm(evItem.e.end) : "Sigue · hasta " + det.hhmm(evItem.e.end))
                                color: det.cMuted; font.family: det.fBody; font.pixelSize: r(34); font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: evItem.e.title
                                color: det.cFg; font.family: det.fDisplay; font.pixelSize: r(52); font.weight: Font.Medium
                            }
                            Text {
                                visible: evItem.e.location !== ""
                                width: parent.width; wrapMode: Text.Wrap
                                text: "Lugar: " + evItem.e.location
                                color: det.cMuted; font.family: det.fBody; font.pixelSize: r(32)
                            }
                            Text {
                                visible: evItem.e.description !== ""
                                width: parent.width; wrapMode: Text.Wrap
                                text: evItem.e.description
                                color: det.cMuted; font.family: det.fBody; font.pixelSize: r(32); lineHeight: 1.1
                            }
                        }
                    }
                }
            }

            // ===== Clima por hora =====
            Item {
                id: wxBox
                visible: det.mode === "wx"
                width: parent.width; height: r(820)
                property var wx: det.payload ? det.payload.wx : null
                Text {
                    visible: !!wxBox.wx
                    text: wxBox.wx ? det.wxInfo(wxBox.wx.current.weather_code)[1] + "  ·  ahora " + Math.round(wxBox.wx.current.temperature_2m) +
                                     "°  ·  máx " + Math.round(wxBox.wx.daily.temperature_2m_max[0]) + "° / mín " + Math.round(wxBox.wx.daily.temperature_2m_min[0]) +
                                     "°  ·  humedad " + wxBox.wx.current.relative_humidity_2m + "%" : ""
                    color: det.cMuted; font.family: det.fBody; font.pixelSize: r(36)
                }
                Grid {
                    y: r(80)
                    columns: 12
                    rowSpacing: r(24)
                    Repeater {
                        model: det.hours
                        delegate: Item {
                            width: wxBox.width / 12; height: r(330)
                            Rectangle {
                                anchors.fill: parent; anchors.margins: r(5); radius: r(18)
                                color: Qt.rgba(1, 1, 1, index === 0 ? 0.10 : 0.04)
                            }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: r(22); spacing: r(10)
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: index === 0 ? "Ahora" : modelData.t
                                    color: index === 0 ? det.cFg : det.cMuted; font.family: det.fBody; font.pixelSize: r(30); font.weight: Font.DemiBold
                                }
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: r(70); height: r(70); smooth: true
                                    source: det.base + "img/" + det.wxIcon(modelData.code, modelData.day) + ".png"
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(modelData.temp) + "°"
                                    color: det.cFg; font.family: det.fDisplay; font.pixelSize: r(46); font.weight: Font.Medium
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.pop + "%"
                                    color: modelData.pop >= 20 ? det.cRain : det.cFaint; font.family: det.fBody; font.pixelSize: r(28)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.wind !== null ? Math.round(modelData.wind) + " km/h" : ""
                                    color: det.cMuted; font.family: det.fBody; font.pixelSize: r(24)
                                }
                            }
                        }
                    }
                }
            }

            // ===== Mercados =====
            Column {
                id: fxCol
                visible: det.mode === "fx"
                width: parent.width
                // Encabezados de columnas
                Item {
                    width: parent.width; height: r(56)
                    Text { x: r(1060); width: r(190); horizontalAlignment: Text.AlignRight; text: "COMPRA"; color: det.cFaint; font.family: det.fBody; font.pixelSize: r(24); font.weight: Font.DemiBold; font.letterSpacing: r(1) }
                    Text { x: r(1270); width: r(190); horizontalAlignment: Text.AlignRight; text: "VENTA / PRECIO"; color: det.cFaint; font.family: det.fBody; font.pixelSize: r(24); font.weight: Font.DemiBold; font.letterSpacing: r(1) }
                    Text { x: r(1480); width: r(240); horizontalAlignment: Text.AlignRight; text: "HOY · 30 DÍAS"; color: det.cFaint; font.family: det.fBody; font.pixelSize: r(24); font.weight: Font.DemiBold; font.letterSpacing: r(1) }
                }
                Text {
                    visible: det.markets.length === 0
                    text: "Cargando cotizaciones…"
                    color: det.cMuted; font.family: det.fBody; font.pixelSize: r(36)
                }
                Repeater {
                    model: det.markets
                    delegate: Item {
                        id: mk
                        property var m: modelData
                        width: fxCol.width; height: r(132)
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: mk.m.name; color: det.cFg; font.family: det.fBody; font.pixelSize: r(44); font.weight: Font.DemiBold }
                            Text { text: mk.m.dollar ? "pesos por dólar" : mk.m.sub + " · en dólares"; color: det.cMuted; font.family: det.fBody; font.pixelSize: r(28) }
                        }
                        Canvas {
                            id: chart
                            x: r(560); width: r(440); height: r(96)
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: det.drawChart(chart, mk.m.serie)
                            Component.onCompleted: requestPaint()
                        }
                        Text {
                            x: r(1060); width: r(190); anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: mk.m.dollar ? "$" + det.fmtInt(mk.m.compra) : "—"
                            color: mk.m.dollar ? det.cFg : det.cFaint; font.family: det.fDisplay; font.pixelSize: r(44)
                        }
                        Text {
                            x: r(1270); width: r(190); anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: mk.m.dollar ? "$" + det.fmtInt(mk.m.venta) : "US$ " + det.fmtInt(mk.m.price)
                            color: det.cFg; font.family: det.fDisplay; font.pixelSize: r(44); font.weight: Font.Medium
                        }
                        Column {
                            x: r(1480); width: r(240); anchors.verticalCenter: parent.verticalCenter
                            spacing: r(6)
                            Rectangle {
                                visible: mk.m.day !== null
                                anchors.right: parent.right
                                width: dayPct.implicitWidth + r(20); height: r(44); radius: r(8)
                                color: mk.m.day >= 0 ? "#1f9d63" : "#d9434b"
                                Text { id: dayPct; anchors.centerIn: parent; text: det.fmtPct(mk.m.day); color: "#ffffff"; font.family: det.fBody; font.pixelSize: r(30); font.weight: Font.DemiBold }
                            }
                            Text {
                                anchors.right: parent.right
                                visible: mk.m.long !== null
                                text: "30 días: " + det.fmtPct(mk.m.long)
                                color: mk.m.long >= 0 ? det.cUp : det.cDown; font.family: det.fBody; font.pixelSize: r(26)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- Protector a pantalla completa, con "Editar" y ✕ arriba ----------
    Loader {
        id: saverLoader
        anchors.fill: parent
        z: 100
        active: det.previewing
        source: active ? det.base + "CleanSaver.qml" : ""
    }
    MouseArea {      // mover el puntero o tocar la pantalla muestra los botones
        anchors.fill: parent; z: 101
        enabled: det.previewing && !det.saverEditing; visible: enabled
        hoverEnabled: true
        onPositionChanged: det.showCtrls()
        onClicked: det.showCtrls()
    }
    Item {
        z: 102
        anchors.fill: parent
        visible: det.previewing && !det.saverEditing && opacity > 0.01
        opacity: det.ctrls ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Rectangle {        // sombra arriba para que se lean los botones sobre cualquier foto
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: det.r(200)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: det.r(56)   // al centro: a los costados van los eventos
            spacing: det.r(18)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "OK: editar  ·  ATRÁS: salir"
                color: "#eef1f6"; opacity: 0.8; font.family: det.fBody; font.pixelSize: det.r(26)
            }
            CButton {
                anchors.verticalCenter: parent.verticalCenter
                s: det.s; family: det.fBody; text: "✎  Editar"
                onClicked: det.startEdit()
            }
            RoundIcon { anchors.verticalCenter: parent.verticalCenter; s: det.s; cross: true; onClicked: det.close() }
        }
    }
    SaverEditor {
        id: saverEd
        anchors.fill: parent
        z: 103
        visible: det.saverEditing
        enabled: det.saverEditing
        s: det.s; fBody: det.fBody; fTitle: det.fTitle
        onDone: det.endSaverEdit(saved)
    }
    onPreviewingChanged: { det.forceActiveFocus(); if (previewing) showCtrls(); }
}
