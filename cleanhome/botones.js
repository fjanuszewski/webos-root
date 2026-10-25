// botones.js — datos de Configuración → Control remoto (RemoteEditor.qml, RemoteDrawing.qml, CleanAppMenu.qml).
// Qué hace cada botón se guarda en botones.json; lo lee botones/botones.py en la tele (ver BOTONES.md).
// Qt 5.6 (JavaScript viejo: nada de flechas ni let).
.pragma library

var BASE = "file:///var/lib/webosbrew/cleanhome/";
var FILE = BASE + "botones.json";
// "modo elegir": la pantalla avisa que espera un botón y botones.py anota cuál se tocó
var CAPTURE = "file:///tmp/cytv-botones-captura";
var TOUCHED = "file:///tmp/cytv-botones-tocado";
// Lo escribe botones.py al arrancar: {"bt": true/false} (si la tele tiene audio Bluetooth; si se apagó en la
// instalación no se ofrece "Cambiar la salida de sonido")
var STATE = "file:///tmp/cytv-botones-estado.json";

// Dibujo del control (img/control-mr20.png, sacado de la vista previa): medidas en las unidades del dibujo original
var VIEW_W = 256, VIEW_H = 944;
// Los 9 botones que se pueden cambiar, de arriba a abajo. zone = [x, y, ancho, alto] en el dibujo.
var KEYS = [
    { id: "netflix", name: "NETFLIX", chip: "#e50914", zone: [33, 645, 50, 28] },
    { id: "prime", name: "Prime Video", chip: "#00a8e1", zone: [173, 645, 50, 28] },
    { id: "red", name: "Rojo", chip: "#e04646", zone: [37, 698, 36, 22] },
    { id: "green", name: "Verde", chip: "#3bb45c", zone: [85, 698, 36, 22] },
    { id: "yellow", name: "Amarillo", chip: "#e8c73a", zone: [135, 698, 36, 22] },
    { id: "blue", name: "Azul", chip: "#3d63d1", zone: [183, 698, 36, 22] },
    { id: "movies", name: "MOVIES", chip: "#e50914", zone: [47, 742, 48, 28] },
    { id: "play", name: "Reproducir", chip: "#9aa3b5", zone: [104, 742, 46, 28] },
    { id: "pause", name: "Pausa", chip: "#9aa3b5", zone: [160, 742, 46, 28] }     // (sin ⏸: la letra de la tele no lo tiene)
];
function keyById(id) {
    for (var i = 0; i < KEYS.length; i++) if (KEYS[i].id === id) return KEYS[i];
    return null;
}

// Qué puede hacer un botón (en este orden en la ventanita). bt: solo si la tele tiene audio Bluetooth.
var ACTIONS = [
    { type: "default", title: "De fábrica", sub: "Lo que hace el botón normalmente" },
    { type: "app", title: "Abrir una app", sub: "La elegís del listado de apps" },
    { type: "input", title: "Ir a una entrada", sub: "HDMI, AV o TV" },
    { type: "url", title: "Abrir una página web", sub: "Se abre en el navegador" },
    { type: "screensaver", title: "Activar el protector de pantalla", sub: "" },
    { type: "screenoff", title: "Apagar solo la pantalla", sub: "El sonido sigue. Cualquier botón la prende." },
    { type: "sleep", title: "Temporizador para apagar", sub: "Cada toque suma: 30 → 60 → 90 min → apagado" },
    { type: "panel", title: "Abrir un panel", sub: "Wi-Fi, Entradas, calendario o clima" },
    { type: "volume", title: "Volumen fijo", sub: "Lleva el volumen a un número" },
    { type: "soundout", title: "Cambiar la salida de sonido", sub: "Parlantes de la tele ↔ Bluetooth", bt: true },
    { type: "none", title: "No hacer nada", sub: "Para que no pase nada si lo tocás sin querer" }
];
var PANELS = [
    { id: "wifi", title: "Wi-Fi" },
    { id: "inputs", title: "Entradas" },
    { id: "day", title: "Calendario de hoy" },
    { id: "wx", title: "Clima por hora" }
];
function panelTitle(id) {
    for (var i = 0; i < PANELS.length; i++) if (PANELS[i].id === id) return PANELS[i].title;
    return id;
}

// Texto corto de lo que hace un botón (para la lista y el cartelito del dibujo)
function short(a) {
    if (!a || !a.type || a.type === "default") return "De fábrica";
    switch (a.type) {
    case "app": return a.label || "Abrir una app";
    case "input": return a.label || "Entrada";
    case "url": return "Página: " + (a.url || "").replace(/^https?:[\/]{2}/, "").replace(/[\/]$/, "");
    case "screensaver": return "Protector";
    case "screenoff": return "Pantalla apagada";
    case "sleep": return "Temporizador";
    case "panel": return "Panel " + panelTitle(a.panel);
    case "volume": return "Volumen " + a.volume;
    case "soundout": return "Salida de sonido";
    case "none": return "Nada";
    }
    return a.type;
}

// ---------- leer / guardar ----------
function load(cb) {
    var x = new XMLHttpRequest();
    x.onreadystatechange = function () {
        if (x.readyState !== XMLHttpRequest.DONE) return;
        var j = {};
        try { j = JSON.parse(x.responseText) || {}; } catch (e) { j = {}; }
        cb(j);
    };
    x.open("GET", FILE);
    x.send();
}
function save(map) {
    var clean = {};
    for (var k in map) if (map[k] && map[k].type && map[k].type !== "default") clean[k] = map[k];
    var x = new XMLHttpRequest();
    x.open("PUT", FILE);
    x.send(JSON.stringify(clean, null, 1));
}
function hasBt(cb) {
    var x = new XMLHttpRequest();
    x.onreadystatechange = function () {
        if (x.readyState !== XMLHttpRequest.DONE) return;
        var j = null;
        try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
        cb(!!(j && j.bt));
    };
    x.open("GET", STATE);
    x.send();
}
// "Abrir un panel": botones.py deja {"panel": "wifi", "t": <ms>} en /tmp/cytv-abrir-panel y abre el inicio; cada
// panel (CleanSettings: wifi, CleanInputs: inputs, CleanTop: day y wx) se fija al aparecer el inicio si es para él.
var PANEL_NOTE = "file:///tmp/cytv-abrir-panel";
function readPanel(cb) {
    var x = new XMLHttpRequest();
    x.onreadystatechange = function () {
        if (x.readyState !== XMLHttpRequest.DONE) return;
        var j = null;
        try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
        cb(j && j.panel && Date.now() - j.t < 30000 ? j.panel : "");
    };
    x.open("GET", PANEL_NOTE);
    x.send();
}
function clearPanel() { var x = new XMLHttpRequest(); x.open("PUT", PANEL_NOTE); x.send(""); }

// "modo elegir"
function startCapture() { var x = new XMLHttpRequest(); x.open("PUT", CAPTURE); x.send(String(Date.now())); }
function stopCapture() { var x = new XMLHttpRequest(); x.open("PUT", CAPTURE); x.send("0"); }
function readTouched(since, cb) {
    var x = new XMLHttpRequest();
    x.onreadystatechange = function () {
        if (x.readyState !== XMLHttpRequest.DONE) return;
        var j = null;
        try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
        cb(j && j.key && j.t >= since ? j.key : "");
    };
    x.open("GET", TOUCHED);
    x.send();
}
