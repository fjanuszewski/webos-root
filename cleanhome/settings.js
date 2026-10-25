// settings.js — ajustes que el usuario elige en las pantallas de edición (CleanEdit.qml).
// Se guardan en /var/lib/webosbrew/cleanhome/settings.json (lo escribe la propia pantalla de inicio, que corre como
// root, con XMLHttpRequest PUT a file://). Lo leen CleanTop, CleanCalendar, CleanDetail y CleanSaver.
// Si el archivo no existe o le falta algo, se usan estos valores por defecto. Qt 5.6 (ES5).
.pragma library

var BASE = "file:///var/lib/webosbrew/cleanhome/";
var FILE = BASE + "settings.json";

function defaults() {
    return {
        wx: { enabled: true, refresh: 1800, name: "Córdoba", lat: -31.4201, lon: -64.1888, tz: "America/Argentina/Cordoba", unit: "celsius" },
        fx: { enabled: true, refresh: 600, widget: ["blue", "cripto", "btc"] },
        cal: { enabled: true, refresh: 600, source: "" },
        // layout: qué va en cada parte de la pantalla del protector y con qué tamaño (ver SAVER_SLOTS / SAVER_WIDGETS);
        // si falta, se arma con saverLayout() a partir de los interruptores viejos (showClock, showWeather, …)
        saver: { enabled: true, interval: 10, source: "", layout: null },  // el álbum real está en saver/config.json (no se publica)
        // Widgets de la pantalla de inicio en una cuadrícula de 4×4: w = widget (HOME_WIDGETS), c/r = columna/fila
        // de arriba a la izquierda, cw/rh = ancho/alto en casillas. Lo edita WidgetsEditor.qml (Configuración → Widgets).
        home: { grid: [ { w: "wx", c: 0, r: 0, cw: 2, rh: 2 }, { w: "fx", c: 0, r: 2, cw: 2, rh: 2 }, { w: "cal", c: 2, r: 0, cw: 2, rh: 4 } ] },
        // Tema (ThemeEditor.qml, Configuración → Tema):
        //   bg: "dynamic" (se tiñe con el color de la app) · "color" (bgColor) · "photo" (photo, de /var/lib/webosbrew/fondos/,
        //   oscurecida photoDim 0..0,7) · panel: "dark" | "gray" | "clear" · accent: color de lo seleccionado · font: s | m | l
        theme: { bg: "dynamic", bgColor: "#1d2740", photo: "", photoDim: 0.35, panel: "dark", accent: "#ffffff", font: "m" }
    };
}

// ---------- Protector: partes de la pantalla, qué se puede poner y tamaños ----------
// Partes (en píxeles de una pantalla de 1920×1080): arriba y abajo, a la izquierda, al centro y a la derecha.
var SAVER_SLOTS = [
    { id: "tl", name: "Arriba a la izquierda", x: 72,  y: 48,  w: 560, h: 200, h_: "left",   v: "top" },
    { id: "tc", name: "Arriba al centro",      x: 680, y: 48,  w: 560, h: 200, h_: "center", v: "top" },
    { id: "tr", name: "Arriba a la derecha",   x: 1288, y: 48, w: 560, h: 200, h_: "right",  v: "top" },
    { id: "bl", name: "Abajo a la izquierda",  x: 72,  y: 772, w: 560, h: 260, h_: "left",   v: "bottom" },
    { id: "bc", name: "Abajo al centro",       x: 680, y: 772, w: 560, h: 260, h_: "center", v: "bottom" },
    { id: "br", name: "Abajo a la derecha",    x: 1288, y: 772, w: 560, h: 260, h_: "right", v: "bottom" }
];
var SAVER_WIDGETS = [
    ["", "Nada"], ["clock", "Hora"], ["date", "Fecha"],
    ["clockDate", "Hora y fecha"], ["weather", "Clima"], ["full", "Hora, fecha y clima"],
    ["calNow", "Evento de ahora"], ["calNext", "Próximo evento"], ["photoDate", "Fecha de la foto"]
];
var SAVER_SIZES = [["s", "Chica", 0.7], ["m", "Mediana", 1.0], ["l", "Grande", 1.35]];

function sizeFactor(code) {
    for (var i = 0; i < SAVER_SIZES.length; i++) if (SAVER_SIZES[i][0] === code) return SAVER_SIZES[i][2];
    return 1.0;
}
function widgetName(code) {
    for (var i = 0; i < SAVER_WIDGETS.length; i++) if (SAVER_WIDGETS[i][0] === code) return SAVER_WIDGETS[i][1];
    return "Nada";
}
// Qué va en cada parte. Si no hay "layout" guardado, se arma el de siempre respetando los interruptores viejos.
function saverLayout(sv) {
    sv = sv || {};
    var out = {}, i, id;
    if (sv.layout) {
        for (i = 0; i < SAVER_SLOTS.length; i++) {
            id = SAVER_SLOTS[i].id;
            var c = sv.layout[id] || {};
            out[id] = { w: c.w || "", size: c.size || "m" };
        }
        return out;
    }
    var clk = sv.showClock !== false, wx = sv.showWeather !== false;
    out.tl = { w: sv.showCalNow !== false ? "calNow" : "", size: "m" };
    out.tc = { w: "", size: "m" };
    out.tr = { w: sv.showCalNext !== false ? "calNext" : "", size: "m" };
    out.bl = { w: "photoDate", size: "m" };
    out.bc = { w: "", size: "m" };
    out.br = { w: clk && wx ? "full" : clk ? "clockDate" : wx ? "weather" : "", size: "m" };
    return out;
}
function copyLayout(l) { return JSON.parse(JSON.stringify(l)); }

// ---------- Pantalla de inicio: widgets en una cuadrícula de 4×4 ----------
// Para sumar un widget nuevo: agregarlo acá (id, nombre y tamaños que acepta, en casillas [ancho, alto]) y dibujarlo
// en CleanTop.qml dentro de un rectángulo que le da gridRect().
var GRID_COLS = 4, GRID_ROWS = 4;
var HOME_WIDGETS = [
    { id: "wx",  name: "Clima",      sizes: [[1, 1], [2, 1], [2, 2], [4, 2]] },
    { id: "fx",  name: "Mercados",   sizes: [[1, 1], [1, 2], [2, 1], [2, 2]] },
    { id: "cal", name: "Calendario", sizes: [[2, 2], [2, 3], [2, 4], [3, 4], [4, 2], [4, 3], [4, 4]] }
];
function homeWidget(id) {
    for (var i = 0; i < HOME_WIDGETS.length; i++) if (HOME_WIDGETS[i].id === id) return HOME_WIDGETS[i];
    return null;
}
// ¿Entra este rectángulo de casillas sin salirse ni pisar a otro widget? (skip = índice que no cuenta, el que se mueve)
function gridFits(grid, c, r, cw, rh, skip) {
    if (c < 0 || r < 0 || c + cw > GRID_COLS || r + rh > GRID_ROWS) return false;
    for (var i = 0; i < grid.length; i++) {
        if (i === skip) continue;
        var g = grid[i];
        if (c < g.c + g.cw && g.c < c + cw && r < g.r + g.rh && g.r < r + rh) return false;
    }
    return true;
}
// Índice del widget que ocupa la casilla (c, r), o -1
function gridAt(grid, c, r) {
    for (var i = 0; i < grid.length; i++) {
        var g = grid[i];
        if (c >= g.c && c < g.c + g.cw && r >= g.r && r < g.r + g.rh) return i;
    }
    return -1;
}
// Acomoda solos a los demás widgets alrededor de uno que se movió, agrandó o agregó (índice "fixed", que queda donde
// está). Cada uno prueba primero su tamaño actual en el lugar libre más cercano a donde estaba; si no entra, los otros
// tamaños que acepta, del más grande al más chico. Antes de dejar a alguno afuera prueba combinaciones de tamaños
// (búsqueda con límite, para que la tele no se trabe); si igual no entra, queda afuera y se avisa en "dropped".
// Devuelve { grid, fixed: índice nuevo del que se movió, dropped: [nombres] }.
function gridRelayout(grid, fixed) {
    var me = grid[fixed];
    var order = [];
    for (var i = 0; i < grid.length; i++) if (i !== fixed) order.push(i);
    order.sort(function (a, b) { return (grid[a].r - grid[b].r) || (grid[a].c - grid[b].c); });
    function sizesOf(g) {
        var d = homeWidget(g.w);
        return [[g.cw, g.rh]].concat((d ? d.sizes : []).filter(function (z) { return z[0] !== g.cw || z[1] !== g.rh; })
                                    .sort(function (a, b) { return b[0] * b[1] - a[0] * a[1]; }));
    }
    function nearest(placed, g, w, h) {
        var best = null, bestD = 1e9;
        for (var r = 0; r + h <= GRID_ROWS; r++)
            for (var c = 0; c + w <= GRID_COLS; c++) {
                if (!gridFits(placed, c, r, w, h, -1)) continue;
                var dist = Math.abs(c - g.c) + Math.abs(r - g.r);
                if (dist < bestD) { bestD = dist; best = { w: g.w, c: c, r: r, cw: w, rh: h }; }
            }
        return best;
    }
    // 1) buscar una forma en la que entren todos (con límite de intentos)
    var budget = 3000, found = null;
    function place(k, placed, keep) {
        if (found || budget <= 0) return;
        if (k === order.length) { found = keep.slice(0); return; }
        var g = grid[order[k]], sz = sizesOf(g);
        for (var t = 0; t < sz.length && !found && budget > 0; t++) {
            budget--;
            var b = nearest(placed, g, sz[t][0], sz[t][1]);
            if (!b) continue;
            placed.push(b); keep.push(b);
            place(k + 1, placed, keep);
            placed.pop(); keep.pop();
        }
    }
    place(0, [me], []);
    // 2) si no hay, uno por uno con el primer tamaño que entre (los que no entran quedan afuera)
    var byIdx = {}, dropped = [];
    if (found) for (var f = 0; f < order.length; f++) byIdx[order[f]] = found[f];
    else {
        var placed = [me];
        order.forEach(function (ix) {
            var g = grid[ix], sz = sizesOf(g);
            for (var t = 0; t < sz.length; t++) {
                var b = nearest(placed, g, sz[t][0], sz[t][1]);
                if (b) { placed.push(b); byIdx[ix] = b; return; }
            }
            var d = homeWidget(g.w);
            dropped.push(d ? d.name : g.w);
        });
    }
    var out = [], nf = -1;
    for (var j = 0; j < grid.length; j++) {
        if (j === fixed) { nf = out.length; out.push({ w: me.w, c: me.c, r: me.r, cw: me.cw, rh: me.rh }); }
        else if (byIdx[j]) out.push(byIdx[j]);
    }
    return { grid: out, fixed: nf, dropped: dropped };
}

// Solo lo que se puede dibujar: widgets conocidos, sin repetir y sin pisarse
function cleanGrid(grid) {
    var out = [], seen = {};
    for (var i = 0; grid && i < grid.length; i++) {
        var g = grid[i];
        if (!g || !homeWidget(g.w) || seen[g.w]) continue;
        var it = { w: g.w, c: g.c | 0, r: g.r | 0, cw: g.cw | 0, rh: g.rh | 0 };
        if (it.cw < 1 || it.rh < 1 || !gridFits(out, it.c, it.r, it.cw, it.rh, -1)) continue;
        seen[g.w] = true;
        out.push(it);
    }
    return out;
}

// ---------- Tema ----------
var THEME_COLORS = ["#ffffff", "#6fa8ff", "#3ddc97", "#f5b83d", "#ff8fa3", "#b18cff", "#5ad1e6", "#ff9f5a"];
var THEME_BG_COLORS = ["#1d2740", "#14301f", "#3a1d2e", "#2b2140", "#3a2a14", "#123238", "#262626", "#000000"];
function panelColor(kind) {
    if (kind === "gray") return Qt.rgba(60 / 255, 66 / 255, 80 / 255, 0.72);
    if (kind === "clear") return Qt.rgba(10 / 255, 12 / 255, 18 / 255, 0.35);
    return Qt.rgba(22 / 255, 26 / 255, 36 / 255, 0.78);
}
function fontFactor(code) { return code === "s" ? 0.88 : code === "l" ? 1.12 : 1.0; }

// Lo guardado pisa a los valores por defecto, sección por sección
function merge(saved) {
    var d = defaults();
    if (!saved) return d;
    for (var sec in d) {
        if (!saved[sec]) continue;
        for (var k in saved[sec]) d[sec][k] = saved[sec][k];
    }
    return d;
}

// Pedidos en curso: se guardan acá para que no se pierdan a mitad de camino (si nadie los referencia, el motor de
// JavaScript los puede descartar antes de terminar; pasaba al guardar dentro de la respuesta de una lectura).
var _live = [];
function _keep(x) { _live.push(x); }
function _drop(x) { var i = _live.indexOf(x); if (i >= 0) _live.splice(i, 1); }

function readText(url, cb) {
    var x = new XMLHttpRequest();
    _keep(x);
    x.onreadystatechange = function () {
        if (x.readyState !== XMLHttpRequest.DONE) return;
        _drop(x);
        cb(x.responseText || "");
    };
    x.open("GET", url);
    x.send();
}

function load(cb) {
    readText(FILE, function (txt) {
        var s = null;
        try { s = JSON.parse(txt); } catch (e) { s = null; }
        cb(merge(s));
    });
}

// Escribe un archivo local (la pantalla de inicio corre como root). cb(ok)
function writeText(url, text, cb) {
    var x = new XMLHttpRequest();
    _keep(x);
    x.onreadystatechange = function () {
        if (x.readyState !== XMLHttpRequest.DONE) return;
        _drop(x);
        var ok = x.status === 0 || x.status === 200 || x.status === 201 || x.status === 204;
        if (!ok) console.warn("[cytv ajustes] no pude escribir " + url + " (estado " + x.status + ")");
        if (cb) cb(ok);
    };
    x.open("PUT", url);
    x.send(text);
}

function save(settings, cb) {
    writeText(FILE, JSON.stringify(settings, null, 1), function (ok) {
        if (!ok) { if (cb) cb(false); return; }
        // verificación: releer y comparar (por si PUT "anduvo" pero no escribió)
        readText(FILE, function (txt) {
            var ok = txt.indexOf('"saver"') >= 0;
            if (!ok) console.warn("[cytv ajustes] guardé pero al releer no está");
            if (cb) cb(ok);
        });
    });
}
