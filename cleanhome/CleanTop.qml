// CleanTop.qml — bloque superior del Home limpio: reloj y los widgets (clima, mercados, calendario familiar) en una
// cuadrícula de 4×4 casillas. Dónde va cada uno y de qué tamaño lo elige la persona en Configuración → Widgets
// (settings.json → home.grid, ver settings.js); cada widget se acomoda al lugar que le toca.
// Los colores y el tamaño de letra salen del tema (settings.json → theme).
// Los paneles se seleccionan como las apps (flechas o puntero del control) y con OK/click abren su ventana de
// detalle (CleanDetail.qml, cargado en MainView). ▲ desde arriba sale a los íconos y ▼ desde abajo a las apps
// (señales exitUp / exitDown, las atiende TopShelf.qml).
// Lo carga TopShelf.qml con un Loader: si este archivo falla, el Home de LG sigue funcionando.
// Qt 5.6 / QtQuick 2.6. Medidas en base 1920, escaladas con r() (igual que getRValue() del Home).
import QtQuick 2.6
import QtGraphicalEffects 1.0
import "settings.js" as Settings
import "botones.js" as Botones

FocusScope {
    id: root

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real s: width / 1920
    function r(v) { return v * s; }
    // Letra de los widgets un 65% más grande (pedido del usuario: se veía chica en la TV), por el tamaño del tema
    property real fs: 1.65 * Settings.fontFactor(st.theme ? st.theme.font : "m")
    function f(v) { return v * s * fs; }
    // Textos secundarios (pronóstico por día, tabla de cotizaciones, fechas del gráfico) +50% extra
    property real fs2: 1.5
    function f2(v) { return v * s * fs * fs2; }

    // ---------- Selección (como las apps) ----------
    signal exitUp()
    signal exitDown()
    property int sel: 0              // 0 clima · 1 mercados · 2 calendario
    readonly property var selIds: ["wx", "fx", "cal"]
    property bool okDown: false
    function focusWidgets() {
        if (!grid.length) { exitDown(); return; }
        if (!placeOf(selIds[sel])) sel = selIds.indexOf(grid[0].w);
        root.forceActiveFocus();
    }
    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function openDetail(kind, payload) {
        var mv = uiController.mainView;
        if (mv && mv.cleanDetail && mv.cleanDetail.item) mv.cleanDetail.item.open(kind, payload);
    }
    // un botón del control con "Abrir un panel → Calendario de hoy / Clima por hora" (ver botones.js → readPanel)
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: if (uiController.homeShown) askPanel.restart()
    }
    Timer {
        id: askPanel; interval: 900
        onTriggered: Botones.readPanel(function (p) {
            if (p === "wx") { Botones.clearPanel(); root.openDetail("wx", { wx: root.wx, place: root.st && root.st.wx ? root.st.wx.name : "" }); }
            else if (p === "day") { Botones.clearPanel(); root.openDetail("day", calendar.dayPayload(1)); }
        })
    }
    function openSel() {
        if (sel === 0) openDetail("wx", { wx: wx, place: st.wx.name });       // abre aunque esté apagado: ahí se edita
        else if (sel === 1) openDetail("fx", { fx: fx, blueHist: blueHist, criptoHist: criptoHist, btc: btc });
        else openDetail("day", calendar.dayPayload(calendar.selDay));
    }
    // OK actúa al SOLTAR (como el Home de LG) y se aceptan las dos mitades del evento
    Keys.onPressed: {
        var k = event.key;
        if (isOk(k)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; return; }
        // en el calendario, ◀ ▶ primero recorren los días; en los bordes pasan al widget de al lado
        if (k === Qt.Key_Up) { if (!go(0, -1)) exitUp(); event.accepted = true; }
        else if (k === Qt.Key_Down) { if (!go(0, 1)) exitDown(); event.accepted = true; }
        else if (k === Qt.Key_Left) {
            if (sel === 2 && calendar.selDay > 0) calendar.selDay--; else go(-1, 0);
            event.accepted = true;
        } else if (k === Qt.Key_Right) {
            if (sel === 2 && calendar.selDay < 6) calendar.selDay++; else go(1, 0);
            event.accepted = true;
        }
    }
    Keys.onReleased: {
        if (isOk(event.key)) {
            event.accepted = true;
            if (okDown && !event.isAutoRepeat) openSel();
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false
    function selBorder(k) { return root.activeFocus && root.sel === k; }
    // Pasa al widget más cercano en esa dirección (dx/dy = -1, 0, 1). false si no hay ninguno.
    function go(dx, dy) {
        var cur = placeOf(selIds[sel]);
        if (!cur) return false;
        var best = -1, bestD = 1e9;
        for (var i = 0; i < grid.length; i++) {
            var g = grid[i];
            if (g === cur) continue;
            var ok = dx > 0 ? g.c >= cur.c + cur.cw : dx < 0 ? g.c + g.cw <= cur.c : dy > 0 ? g.r >= cur.r + cur.rh : g.r + g.rh <= cur.r;
            if (!ok) continue;
            // distancia entre centros, pesando más el desvío hacia los costados
            var ax = cur.c + cur.cw / 2, ay = cur.r + cur.rh / 2, bx = g.c + g.cw / 2, by = g.r + g.rh / 2;
            var d = dx !== 0 ? Math.abs(bx - ax) + 2 * Math.abs(by - ay) : Math.abs(by - ay) + 2 * Math.abs(bx - ax);
            if (d < bestD) { bestD = d; best = i; }
        }
        if (best < 0) return false;
        sel = selIds.indexOf(grid[best].w);
        if (sel === 2) calendar.selDay = dx < 0 ? 6 : 1;       // al calendario se entra por HOY (o por el final desde la derecha)
        return true;
    }

    // ---------- Paleta y fuentes ----------
    readonly property color cFg: "#eef1f6"
    readonly property color cMuted: "#9aa3b5"
    readonly property color cFaint: "#5d6576"
    readonly property color cRain: "#6fa8ff"
    property color cAccent: st.theme && st.theme.accent ? st.theme.accent : "#ffffff"      // borde de lo seleccionado
    property color cPanel: Settings.panelColor(st.theme ? st.theme.panel : "dark")

    FontLoader { id: fDispM; source: root.base + "fonts/Bricolage-Medium.ttf" }
    FontLoader { id: fDispB; source: root.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fUi; source: root.base + "fonts/InstrumentSans-Regular.ttf" }
    FontLoader { id: fUiB; source: root.base + "fonts/InstrumentSans-SemiBold.ttf" }
    property string fDisplay: fDispM.status === FontLoader.Ready ? fDispM.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    // ---------- Estado ----------
    property var wx: null
    property real wxT: 0
    property var fx: null
    property real fxT: 0
    property var blueHist: null
    property var criptoHist: null
    property var btc: null
    property string now: ""
    property string today: ""
    property string todayYmd: ""

    readonly property var dias: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var diasC: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var mesesC: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    // ---------- Utilidades ----------
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function fmtInt(n) {
        var str = String(Math.round(Math.abs(n))), out = "";
        while (str.length > 3) { out = "." + str.slice(-3) + out; str = str.slice(0, -3); }
        return (n < 0 ? "-" : "") + str + out;
    }
    function fmtPct(n, d) { return Math.abs(n).toFixed(d).replace(".", ","); }
    function hhmm(t) { var d = new Date(t); return pad2(d.getHours()) + ":" + pad2(d.getMinutes()); }
    function ymd(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
    function parseDay(str) { var p = str.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]); }
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

    function getJSON(url, cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status === 200) {
                var j = null;
                try { j = JSON.parse(x.responseText); } catch (e) { console.log("CleanTop parse error " + url + ": " + e); }
                cb(j);
            } else {
                console.log("CleanTop HTTP " + x.status + " " + url);
                cb(null);
            }
        };
        x.open("GET", url);
        x.send();
    }

    function reduceHist(list) {
        var t = new Date(), todayS = ymd(t);
        var m = new Date(t.getFullYear(), t.getMonth() - 1, t.getDate());
        if (m.getMonth() === t.getMonth()) m = new Date(t.getFullYear(), t.getMonth(), 0);
        var target = ymd(m), ayer = null, mes = null;
        for (var i = list.length - 1; i >= 0; i--) {
            var it = list[i];
            if (!ayer && it.fecha < todayS) ayer = { fecha: it.fecha, venta: it.venta };
            if (!mes && it.fecha <= target) mes = { fecha: it.fecha, venta: it.venta };
            if (ayer && mes) break;
        }
        var serie = [];
        for (var k = Math.max(0, list.length - 30); k < list.length; k++) serie.push(list[k].venta);
        return { ayer: ayer, mes: mes, serie: serie };
    }

    // ---------- Ajustes del usuario (settings.json, se editan desde las ventanas de detalle) ----------
    property var st: Settings.defaults()
    property string stText: ""
    function loadSettings() {
        Settings.load(function (n) {
            var txt = JSON.stringify(n);
            if (txt === root.stText) return;
            var old = root.st;
            root.stText = txt;
            root.st = n;
            // si cambió la ciudad, la unidad o lo que se mira en mercados, se vuelve a pedir enseguida
            if (old.wx.lat !== n.wx.lat || old.wx.lon !== n.wx.lon || old.wx.unit !== n.wx.unit || old.wx.enabled !== n.wx.enabled) { root.wx = null; root.lastWx = 0; }
            if (JSON.stringify(old.fx.widget) !== JSON.stringify(n.fx.widget) || old.fx.enabled !== n.fx.enabled) { root.lastFx = 0; root.lastCoins = 0; root.lastHist = 0; }
            root.refresh();
        });
    }
    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.loadSettings() }
    // Configuración (widgets, tema) avisa cuando guarda: se relee enseguida
    Connections {
        target: uiController.mainView
        ignoreUnknownSignals: true
        onCleanRevChanged: root.loadSettings()
    }

    // ---------- Cuadrícula de widgets (4×4 casillas sobre la zona de x 64…1856, y 96…790) ----------
    property var grid: Settings.cleanGrid(st.home ? st.home.grid : [])
    readonly property real gx: 64
    readonly property real gy: 96
    readonly property real gGap: 20
    readonly property real cellW: (1792 - 3 * gGap) / 4
    readonly property real cellH: (694 - 3 * gGap) / 4
    function placeOf(id) { for (var i = 0; i < grid.length; i++) if (grid[i].w === id) return grid[i]; return null; }
    // Rectángulo en píxeles de pantalla del widget (o uno vacío si no está en la cuadrícula)
    function rectOf(id) {
        var g = placeOf(id);
        if (!g) return { x: 0, y: 0, w: 0, h: 0 };
        return { x: r(gx + g.c * (cellW + gGap)), y: r(gy + g.r * (cellH + gGap)),
                 w: r(g.cw * cellW + (g.cw - 1) * gGap), h: r(g.rh * cellH + (g.rh - 1) * gGap) };
    }

    // Indicadores posibles del panel de mercados (clave → cómo se pide)
    readonly property var fxDefs: ({
        blue: { name: "Dólar blue", casa: "blue" }, oficial: { name: "Dólar oficial", casa: "oficial" },
        bolsa: { name: "Dólar MEP", casa: "bolsa" }, cripto: { name: "Dólar cripto", casa: "cripto" },
        contadoconliqui: { name: "Dólar CCL", casa: "contadoconliqui" }, tarjeta: { name: "Dólar tarjeta", casa: "tarjeta" },
        mayorista: { name: "Dólar mayorista", casa: "mayorista" },
        btc: { name: "Bitcoin", coin: "bitcoin", sub: "BTC · dólares" }, eth: { name: "Ethereum", coin: "ethereum", sub: "ETH · dólares" }
    })
    property var hist: ({})          // casa → { ayer, mes, serie }
    property var coins: ({})         // coin → [[ms, precio], …] últimos 30 días

    // ---------- Refresco: cada panel cada tantos segundos como diga su ajuste (si falla, reintenta al rato) ----------
    property real lastWx: 0
    property real lastFx: 0
    property real lastHist: 0
    property real lastCoins: 0
    function refresh() {
        var t = Date.now();
        var w = st.wx, f = st.fx;
        if (w.enabled !== false && t - lastWx > Math.max(300, w.refresh || 1800) * 1000) {
            lastWx = t;
            getJSON("https://api.open-meteo.com/v1/forecast?latitude=" + w.lat + "&longitude=" + w.lon +
                    "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,precipitation_probability,is_day" +
                    "&hourly=temperature_2m,weather_code,is_day,precipitation_probability,wind_speed_10m,relative_humidity_2m" +
                    "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
                    "&timezone=" + encodeURIComponent(w.tz || "auto") + "&forecast_days=8" +
                    (w.unit === "fahrenheit" ? "&temperature_unit=fahrenheit" : ""),
                    function (j) { if (j && j.daily) { root.wx = j; root.wxT = Date.now(); } else root.lastWx = 0; });
        }
        if (f.enabled === false) return;
        var every = Math.max(60, f.refresh || 600) * 1000;
        if (t - lastFx > every) {
            lastFx = t;
            getJSON("https://dolarapi.com/v1/dolares", function (j) {
                if (j && j.length) {
                    var by = {};
                    for (var i = 0; i < j.length; i++) by[j[i].casa] = j[i];
                    root.fx = by; root.fxT = Date.now();
                } else root.lastFx = 0;
            });
        }
        var sel = f.widget || [];
        if (t - lastHist > 12 * 3600000) {
            lastHist = t;
            sel.forEach(function (k) {
                var d = root.fxDefs[k];
                if (!d || !d.casa) return;
                getJSON("https://api.argentinadatos.com/v1/cotizaciones/dolares/" + d.casa, function (j) {
                    if (!j || !j.length) { root.lastHist = 0; return; }
                    var h = root.hist; h[d.casa] = reduceHist(j); root.hist = h; root.histChanged();
                    if (d.casa === "blue") root.blueHist = h.blue;
                    if (d.casa === "cripto") root.criptoHist = h.cripto;
                });
            });
        }
        if (t - lastCoins > Math.max(every, 5 * 60000)) {      // CoinGecko gratis: no más de una vez cada 5 min
            lastCoins = t;
            sel.forEach(function (k) {
                var d = root.fxDefs[k];
                if (!d || !d.coin) return;
                getJSON("https://api.coingecko.com/api/v3/coins/" + d.coin + "/market_chart?vs_currency=usd&days=30&interval=daily", function (j) {
                    if (!j || !j.prices) { root.lastCoins = 0; return; }
                    var c = root.coins; c[d.coin] = j.prices; root.coins = c; root.coinsChanged();
                    if (d.coin === "bitcoin") root.btc = j.prices;
                });
            });
        }
    }
    function tick() {
        var d = new Date();
        now = pad2(d.getHours()) + ":" + pad2(d.getMinutes());
        var str = dias[d.getDay()] + ", " + d.getDate() + " de " + meses[d.getMonth()];
        today = str.charAt(0).toUpperCase() + str.slice(1);
        todayYmd = ymd(d);
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    // Dólar: chips contra ayer y contra el mismo día del mes pasado
    function chipKind(prev) {
        if (!prev || !fx || !fx.blue) return "flat";
        var d = fx.blue.venta - prev.venta;
        return Math.abs(d) < 0.5 ? "flat" : (d > 0 ? "up" : "down");
    }
    function chipText(prev, label) {
        if (!prev || !fx || !fx.blue) return "";
        var d = fx.blue.venta - prev.venta;
        if (Math.abs(d) < 0.5) return "= " + label;
        return (d > 0 ? "▲ " : "▼ ") + fmtPct(d / prev.venta * 100, 1) + "% " + label;
    }
    function mesLabel() {
        if (!blueHist || !blueHist.mes) return "";
        var p = blueHist.mes.fecha.split("-");
        return "vs " + (+p[2]) + "/" + (+p[1]);
    }

    // ---------- Reloj (35 % más chico) con la fecha a la derecha: libera alto para los paneles ----------
    Text {
        id: clock
        x: r(64); y: r(14)
        text: root.now
        color: root.cFg
        font.family: root.fDisplay; font.pixelSize: r(55); font.weight: Font.Medium
        font.letterSpacing: -r(1)
    }
    Text {
        anchors.left: clock.right; anchors.leftMargin: r(22); anchors.baseline: clock.baseline
        text: root.today
        color: root.cMuted
        font.family: root.fBody; font.pixelSize: f(20)
    }

    // ================= COLUMNA IZQUIERDA =================
    // ---------- Clima: arriba el actual (temperatura grande + ícono + condición); abajo la semana (7 días con
    // ícono y máxima/mínima). OK/click abre el detalle por hora (CleanDetail "wx"). ----------
    function wxIcon(code, isDay) {
        var k = wxInfo(code)[0];
        if (!isDay && k === "sun") return "moon";
        if (!isDay && k === "partly") return "moon-partly";
        return k;
    }
    Panel {
        id: wxPanel
        s: root.s
        property var rc: root.rectOf("wx")
        visible: !!root.placeOf("wx")
        color: root.cPanel
        x: rc.x; y: rc.y; width: rc.w; height: rc.h
        // angosto (1 casilla): solo temperatura, ícono y ciudad · bajo (1 fila): sin la semana
        property bool narrow: width < r(600)
        property bool showDays: height > r(250)
        border.width: root.selBorder(0) ? r(4) : 1
        border.color: root.selBorder(0) ? root.cAccent : Qt.rgba(1, 1, 1, 0.08)

        property int nDays: root.wx ? Math.min(7, root.wx.daily.time.length) : 0
        property real lo: root.wx ? Math.min.apply(null, root.wx.daily.temperature_2m_min.slice(0, nDays)) : 0
        property real hi: root.wx ? Math.max.apply(null, root.wx.daily.temperature_2m_max.slice(0, nDays)) : 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { root.sel = 0; root.forceActiveFocus(); }
            onClicked: { root.sel = 0; root.openSel(); }
        }
        // Panel apagado desde "Editar": tarjeta que se puede elegir para volver a encenderlo
        Rectangle {
            visible: root.st.wx.enabled === false
            anchors.fill: parent; anchors.margins: r(4); z: 5
            radius: r(20); color: "#151922"
            Text {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: "Clima apagado\nOK para editar"
                color: root.cFaint; font.family: root.fBody; font.pixelSize: f2(11)
            }
        }
        Text {
            visible: !root.wx
            x: r(24); y: r(24)
            text: "Cargando clima…"
            color: root.cFaint; font.family: root.fBody; font.pixelSize: f(16)
        }
        // Fila de arriba: temperatura + ícono, humedad y viento con su ícono; la ciudad elegida a la derecha
        Row {
            visible: !!root.wx
            x: r(30); y: r(16); height: r(84)
            spacing: r(16)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wx ? Math.round(root.wx.current.temperature_2m) + "°" : ""
                color: root.cFg; font.family: root.fDisplay; font.pixelSize: f(44); font.weight: Font.Medium
                font.letterSpacing: -r(1)
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: r(70); height: r(70); smooth: true
                source: root.wx ? root.base + "img/" + root.wxIcon(root.wx.current.weather_code, root.wx.current.is_day === 1) + ".png" : ""
            }
            Item { width: r(10); height: 1; visible: !wxPanel.narrow }
            Row {
                visible: !wxPanel.narrow
                anchors.verticalCenter: parent.verticalCenter
                spacing: r(8)
                Image { anchors.verticalCenter: parent.verticalCenter; width: r(36); height: r(36); smooth: true; source: root.base + "img/drop.png" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wx ? root.wx.current.relative_humidity_2m + "%" : ""
                    color: root.cFg; font.family: root.fBody; font.pixelSize: f2(11)
                }
            }
            Item { width: r(6); height: 1; visible: !wxPanel.narrow }
            Row {
                visible: !wxPanel.narrow
                anchors.verticalCenter: parent.verticalCenter
                spacing: r(8)
                Image { anchors.verticalCenter: parent.verticalCenter; width: r(36); height: r(36); smooth: true; source: root.base + "img/wind.png" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wx ? Math.round(root.wx.current.wind_speed_10m) + " km/h" : ""
                    color: root.cFg; font.family: root.fBody; font.pixelSize: f2(11)
                }
            }
        }
        Text {
            visible: !!root.wx
            // angosto: la ciudad va abajo de la temperatura
            x: wxPanel.narrow ? r(30) : parent.width - width - r(30)
            y: wxPanel.narrow ? r(100) : r(16) + (r(84) - height) / 2
            width: wxPanel.narrow ? parent.width - r(60) : implicitWidth; elide: Text.ElideRight
            text: root.st.wx.name
            color: root.cMuted; font.family: root.fBody; font.pixelSize: f2(10)
        }
        Rectangle { visible: !!root.wx && wxPanel.showDays; x: r(24); y: r(112); width: parent.width - r(48); height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
        // La semana: 7 días repartidos en todo el ancho
        Row {
            id: days
            visible: !!root.wx && wxPanel.showDays
            x: r(20); y: r(118); width: parent.width - r(40); height: Math.max(r(192), parent.height - r(138))
            Repeater {
                model: wxPanel.nDays
                delegate: Item {
                    id: dayItem
                    width: days.width / wxPanel.nDays; height: days.height
                    property bool isToday: root.wx.daily.time[index] === root.todayYmd
                    property real mn: root.wx.daily.temperature_2m_min[index]
                    property real mx: root.wx.daily.temperature_2m_max[index]
                    property int pop: root.wx.daily.precipitation_probability_max[index]
                    // Resaltado de HOY: envuelve los textos con aire (antes quedaba pegado al % de lluvia)
                    Rectangle {
                        x: r(4); width: parent.width - r(8)
                        y: dayCol.y - r(10); height: dayCol.height + r(20)
                        radius: r(14); color: Qt.rgba(1, 1, 1, 0.07); visible: dayItem.isToday
                    }
                    Column {
                        id: dayCol
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: r(12); spacing: r(1)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayItem.isToday ? "Hoy" : root.diasC[root.parseDay(root.wx.daily.time[index]).getDay()]
                            color: root.cFg; font.family: root.fBody; font.pixelSize: f2(10); font.weight: Font.DemiBold
                        }
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: r(44); height: r(44); smooth: true
                            source: root.base + "img/" + root.wxInfo(root.wx.daily.weather_code[index])[0] + ".png"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(dayItem.mx) + "°"
                            color: root.cFg; font.family: root.fBody; font.pixelSize: f2(11); font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(dayItem.mn) + "°"
                            color: root.cMuted; font.family: root.fBody; font.pixelSize: f2(10)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayItem.pop >= 20 ? dayItem.pop + "%" : " "
                            color: root.cRain; font.family: root.fBody; font.pixelSize: f2(8)
                        }
                    }
                }
            }
        }
    }

    // ---------- Mercados: lista estilo "watchlist" (nombre | gráfico chico | valor + variación) ----------
    // Variación del día contra ayer; abajo, contra el mes pasado / 30 días. OK/click abre el detalle (CleanDetail "fx").
    function pct(cur, prev) { return (cur && prev) ? (cur - prev) / prev * 100 : null; }
    function pctText(p) { return p === null ? "" : (p > 0.005 ? "+" : (p < -0.005 ? "−" : "")) + fmtPct(p, 2) + "%"; }
    // Los 3 que eligió el usuario (ajuste fx.widget; por defecto dólar blue, dólar cripto, Bitcoin), en ese orden
    function vsLabel(h) {
        if (!h || !h.mes) return "";
        var p = h.mes.fecha.split("-");
        return "vs " + (+p[2]) + "/" + (+p[1]);
    }
    property var markets: {
        var out = [], sel = (st.fx.widget || []).slice(0, 3);
        var dummy = [hist, coins, fx];     // dependencias de la vinculación
        for (var i = 0; i < sel.length; i++) {
            var d = fxDefs[sel[i]];
            if (!d) continue;
            if (d.casa) {
                var q = fx ? fx[d.casa] : null;
                if (!q) continue;
                var h = hist[d.casa];
                out.push({ name: d.name, sub: "venta · pesos", value: "$" + fmtInt(q.venta),
                           serie: h && h.serie ? h.serie.concat([q.venta]) : [],
                           day: pct(q.venta, h && h.ayer ? h.ayer.venta : 0),
                           long: pct(q.venta, h && h.mes ? h.mes.venta : 0), longLabel: vsLabel(h) });
            } else if (d.coin) {
                var c = coins[d.coin];
                if (!c || c.length < 2) continue;
                var cs = c.map(function (p) { return p[1]; });
                out.push({ name: d.name, sub: d.sub, value: "US$ " + fmtInt(cs[cs.length - 1]), serie: cs,
                           day: pct(cs[cs.length - 1], cs[cs.length - 2]), long: pct(cs[cs.length - 1], cs[0]), longLabel: "30 días" });
            }
        }
        return out;
    }
    // Línea punteada a la altura del primer valor (referencia, como en la foto del usuario)
    function drawWatch(cv, s) {
        var ctx = cv.getContext("2d");
        ctx.reset();
        if (!s || s.length < 2) return;
        var w = cv.width, h = cv.height, pad = r(4);
        var mn = Math.min.apply(null, s), mx = Math.max.apply(null, s), span = Math.max(1e-9, mx - mn);
        var up = s[s.length - 1] >= s[0];
        var col = up ? "#3ddc97" : "#ff6b6b";
        function X(i) { return pad + i / (s.length - 1) * (w - pad * 2); }
        function Y(v) { return pad + (1 - (v - mn) / span) * (h - pad * 2); }
        ctx.fillStyle = "rgba(238,241,246,0.55)";
        for (var dx = pad; dx < w - pad; dx += r(7)) ctx.fillRect(dx, Y(s[0]) - r(1), r(3), r(2));
        ctx.beginPath();
        for (var k = 0; k < s.length; k++) { if (k === 0) ctx.moveTo(X(k), Y(s[k])); else ctx.lineTo(X(k), Y(s[k])); }
        ctx.strokeStyle = col; ctx.lineWidth = r(2.2); ctx.lineJoin = "round";
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(X(s.length - 1), Y(s[s.length - 1]), r(4), 0, Math.PI * 2);
        ctx.fillStyle = col;
        ctx.fill();
    }

    Panel {
        id: mkPanel
        s: root.s
        property var rc: root.rectOf("fx")
        visible: !!root.placeOf("fx")
        color: root.cPanel
        x: rc.x; y: rc.y; width: rc.w; height: rc.h
        // cuántos entran a lo alto (cada fila mide entre 105 y 111) y, si es angosto, sin gráfico
        property int rows: Math.max(1, Math.min(3, Math.floor((height - r(8)) / r(105))))
        property real rowH: Math.min(r(111), (height - r(8)) / rows)
        property bool narrow: width < r(600)
        border.width: root.selBorder(1) ? r(4) : 1
        border.color: root.selBorder(1) ? root.cAccent : Qt.rgba(1, 1, 1, 0.08)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { root.sel = 1; root.forceActiveFocus(); }
            onClicked: { root.sel = 1; root.openSel(); }
        }
        // Panel apagado desde "Editar": tarjeta que se puede elegir para volver a encenderlo
        Rectangle {
            visible: root.st.fx.enabled === false
            anchors.fill: parent; anchors.margins: r(4); z: 5
            radius: r(20); color: "#151922"
            Text {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: "Mercados apagado\nOK para editar"
                color: root.cFaint; font.family: root.fBody; font.pixelSize: f2(11)
            }
        }

        Text {
            visible: root.markets.length === 0
            x: r(24); y: r(24)
            text: "Cargando cotizaciones…"
            color: root.cFaint; font.family: root.fBody; font.pixelSize: f(16)
        }
        Column {
            x: r(24); y: r(6); width: parent.width - r(48)
            Repeater {
                model: root.markets.slice(0, mkPanel.rows)
                delegate: Item {
                    id: mrow
                    property var m: modelData
                    width: parent.width; height: mkPanel.rowH

                    Rectangle { visible: index > 0; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: mkPanel.narrow ? parent.width - r(190) : r(290)
                        spacing: r(2)
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: mrow.m.name
                            color: root.cFg; font.family: root.fBody; font.pixelSize: f(19); font.weight: Font.DemiBold
                        }
                        Text {
                            text: mrow.m.sub
                            color: root.cMuted; font.family: root.fBody; font.pixelSize: f2(10)
                        }
                    }
                    Canvas {
                        id: watch
                        visible: !mkPanel.narrow
                        x: r(300); y: r(14); width: r(250); height: r(62)
                        onPaint: root.drawWatch(watch, mrow.m.serie)
                        onWidthChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                    }
                    Column {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: r(3)
                        Text {
                            anchors.right: parent.right
                            text: mrow.m.value
                            color: root.cFg; font.family: root.fDisplay; font.pixelSize: f(21); font.weight: Font.Medium
                        }
                        Rectangle {
                            visible: mrow.m.day !== null
                            anchors.right: parent.right
                            width: dayTxt.implicitWidth + r(16); height: r(38); radius: r(6)
                            color: mrow.m.day >= 0 ? "#1f9d63" : "#d9434b"
                            Text {
                                id: dayTxt
                                anchors.centerIn: parent
                                text: root.pctText(mrow.m.day)
                                color: "#ffffff"; font.family: root.fBody; font.pixelSize: f(15); font.weight: Font.DemiBold
                            }
                        }
                    }
                    Text {
                        visible: !mkPanel.narrow && mrow.m.long !== null && mrow.m.longLabel !== ""
                        anchors.right: watch.right; anchors.top: watch.bottom; anchors.topMargin: r(2)
                        text: mrow.m.longLabel + ": " + root.pctText(mrow.m.long)
                        color: mrow.m.long >= 0 ? "#3ddc97" : "#ff6b6b"
                        font.family: root.fBody; font.pixelSize: f2(9)
                    }
                }
            }
        }
    }

    // ================= COLUMNA DERECHA =================
    CleanCalendar {
        id: calendar
        s: root.s; fs: root.fs; fs2: root.fs2
        fBody: root.fBody; fDisplay: root.fDisplay; base: root.base
        property var rc: root.rectOf("cal")
        visible: !!root.placeOf("cal")
        color: root.cPanel
        accent: root.cAccent
        x: rc.x; y: rc.y; width: rc.w; height: rc.h
        focused: root.selBorder(2)
        onDayHovered: { root.sel = 2; calendar.selDay = i; root.forceActiveFocus(); }
        onDayClicked: { root.sel = 2; calendar.selDay = i; root.openSel(); }
    }
    // Calendario apagado desde "Editar": tarjeta encima (el panel sigue seleccionable para volver a encenderlo)
    Rectangle {
        visible: root.st.cal.enabled === false && calendar.visible
        x: calendar.x + r(4); y: calendar.y + r(4); width: calendar.width - r(8); height: calendar.height - r(8)
        radius: r(20); color: "#151922"
        border.width: root.selBorder(2) ? r(4) : 0; border.color: root.cAccent
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Calendario apagado\nOK para editar"
            color: root.cFaint; font.family: root.fBody; font.pixelSize: f2(11)
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { root.sel = 2; root.forceActiveFocus(); }
            onClicked: { root.sel = 2; root.openSel(); }
        }
    }
}
