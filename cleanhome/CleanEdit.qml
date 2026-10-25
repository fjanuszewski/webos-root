// CleanEdit.qml — pantalla de edición que se abre con el botón "Editar" de CleanDetail.
// Formularios: "wx" (clima: ciudad y °C/°F), "fx" (mercados: hasta 3 para el panel), "day" (calendario: enlace o ID)
// Todos tienen arriba un interruptor (mostrar/encender) y un número en segundos (cada cuánto se actualiza).
// El protector se edita aparte, sobre la pantalla misma: SaverEditor.qml.
// Guarda en settings.json (settings.js) y, si hace falta, en cal/config.json + un archivo
// "pedido" para que la tarea de fondo sincronice enseguida. Flechas para moverse, OK para elegir. Qt 5.6.
import QtQuick 2.6
import "settings.js" as Settings

FocusScope {
    id: ed

    property real s: 1
    property string fBody: "Droid Sans"
    property string fTitle: "Droid Sans"
    property string mode: ""
    property var cfg: null              // copia de trabajo de settings.json
    property string status: ""
    property color statusColor: "#3ddc97"
    signal done(bool saved)

    function r(v) { return v * s; }

    // ---------- Datos de cada formulario ----------
    readonly property var fxDefs: [
        ["blue", "Dólar blue"], ["oficial", "Dólar oficial"], ["bolsa", "Dólar MEP"],
        ["cripto", "Dólar cripto"], ["contadoconliqui", "Dólar CCL"], ["tarjeta", "Dólar tarjeta"],
        ["mayorista", "Dólar mayorista"], ["btc", "Bitcoin"], ["eth", "Ethereum"]
    ]
    property var fxSel: []              // claves elegidas, en orden
    property var places: []             // resultados de la búsqueda de ciudad
    property var place: null            // ciudad elegida
    property string unit: "celsius"

    function sec() { return mode === "day" ? "cal" : mode; }

    function open(kind) {
        mode = kind;
        status = "";
        places = [];
        Settings.load(function (st) {
            ed.cfg = st;
            var c = st[ed.sec()];
            enabledSw.checked = c.enabled !== false;
            numField.text = String(c.refresh);
            if (kind === "wx") { ed.place = { name: c.name, lat: c.lat, lon: c.lon, tz: c.tz }; ed.unit = c.unit || "celsius"; cityField.text = c.name; }
            if (kind === "fx") ed.fxSel = (c.widget || []).slice(0, 3);
            if (kind === "day") {
                srcField.text = c.source || "";
                if (!c.source) Settings.readText(Settings.BASE + "cal/config.json", function (txt) {
                    try { var j = JSON.parse(txt); srcField.text = j.source || j.ics || ""; } catch (e) {}
                });
            }
            enabledSw.forceActiveFocus();
        });
    }

    // ---------- Clima: buscar ciudad ----------
    function searchCity() {
        var q = cityField.text.replace(/^\s+|\s+$/g, "");
        if (!q) return;
        status = "Buscando…"; statusColor = "#9aa3b5";
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var res = [];
            try { res = JSON.parse(x.responseText).results || []; } catch (e) { res = []; }
            ed.places = res.slice(0, 5);
            ed.status = res.length ? "" : "No encontré esa ciudad";
            ed.statusColor = "#ff6b6b";
            if (res.length) placeRep.itemAt(0).forceActiveFocus();
        };
        x.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&language=es&format=json&name=" + encodeURIComponent(q));
        x.send();
    }
    function placeLabel(p) { return p.name + (p.admin1 ? ", " + p.admin1 : "") + (p.country ? ", " + p.country : ""); }

    // ---------- Mercados: elegir hasta 3 ----------
    function toggleFx(key) {
        var sel = fxSel.slice(0), i = sel.indexOf(key);
        if (i >= 0) sel.splice(i, 1);
        else if (sel.length < 3) sel.push(key);
        fxSel = sel;
    }

    // ---------- Guardar ----------
    function save() {
        var c = cfg[sec()];
        var n = parseInt(numField.text, 10);
        var min = mode === "wx" ? 300 : 60;
        if (isNaN(n) || n < min) { n = min; numField.text = String(n); }
        c.enabled = enabledSw.checked;
        c.refresh = n;
        if (mode === "wx") {
            if (place) { c.name = place.name; c.lat = place.lat; c.lon = place.lon; c.tz = place.tz || "auto"; }
            c.unit = unit;
        }
        if (mode === "fx") {
            if (!fxSel.length) { status = "Elegí al menos uno"; statusColor = "#ff6b6b"; return; }
            c.widget = fxSel.slice(0);
        }
        if (mode === "day") {
            var src = srcField.text.replace(/^\s+|\s+$/g, "");
            if (!src) { status = "Falta el enlace o el ID"; statusColor = "#ff6b6b"; return; }
            c.source = src;
            Settings.writeText(Settings.BASE + "cal/config.json", JSON.stringify({ source: src }), null);
            Settings.writeText(Settings.BASE + "cal/pedido", "1", null);
            Settings.writeText(Settings.BASE + "cal/refresh", String(n), null);
        }
        status = "Guardando…"; statusColor = "#9aa3b5";
        Settings.save(cfg, function (ok) {
            if (!ok) { ed.status = "No pude guardar los cambios"; ed.statusColor = "#ff6b6b"; return; }
            ed.status = mode === "day" ? "Guardado. El calendario se actualiza en menos de un minuto."
                      : "Guardado.";
            ed.statusColor = "#3ddc97";
            closeTimer.restart();
        });
    }
    Timer { id: closeTimer; interval: 1600; onTriggered: ed.done(true) }

    // ---------- Navegación con flechas: filas de elementos en el orden en que se ven ----------
    function rows() {
        var rs = [[enabledSw], [numField]];
        if (mode === "wx") {
            rs.push([cityField, searchBtn]);
            for (var i = 0; i < placeRep.count; i++) rs.push([placeRep.itemAt(i)]);
            rs.push([celsiusBtn, fahrBtn]);
        }
        if (mode === "fx") {
            for (var r0 = 0; r0 < 3; r0++) rs.push([fxRep.itemAt(r0 * 3), fxRep.itemAt(r0 * 3 + 1), fxRep.itemAt(r0 * 3 + 2)]);
        }
        if (mode === "day") rs.push([srcField]);
        rs.push([saveBtn, cancelBtn]);
        return rs;
    }
    function move(dr, dc) {
        var rs = rows(), R = -1, C = 0;
        for (var r = 0; r < rs.length && R < 0; r++)
            for (var c = 0; c < rs[r].length; c++)
                if (rs[r][c] && (rs[r][c].activeFocus || rs[r][c].editing)) { R = r; C = c; break; }
        if (R < 0) { enabledSw.forceActiveFocus(); return; }
        if (dc !== 0) { C = Math.max(0, Math.min(rs[R].length - 1, C + dc)); }
        else { R = Math.max(0, Math.min(rs.length - 1, R + dr)); C = Math.min(C, rs[R].length - 1); }
        if (rs[R][C]) rs[R][C].forceActiveFocus();
    }
    Keys.onPressed: {
        if (event.key === Qt.Key_Up) { move(-1, 0); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { move(1, 0); event.accepted = true; }
        else if (event.key === Qt.Key_Left) { move(0, -1); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { move(0, 1); event.accepted = true; }
    }

    // ---------- Pantalla ----------
    Column {
        width: parent.width
        spacing: r(22)

        CSwitch {
            id: enabledSw
            s: ed.s; family: ed.fBody
            text: "Mostrar este panel"
        }
        Row {
            spacing: r(24)
            CField {
                id: numField
                s: ed.s; family: ed.fBody
                width: r(260); numeric: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "segundos entre actualizaciones (mínimo " + (ed.mode === "wx" ? 300 : 60) + ")"
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28)
            }
        }

        // ----- Clima -----
        Column {
            visible: ed.mode === "wx"
            spacing: r(16)
            Text {
                text: "Ubicación actual: " + (ed.place ? ed.place.name : "") + "  ·  escribí otra ciudad y buscá"
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28)
            }
            Row {
                spacing: r(20)
                CField { id: cityField; s: ed.s; family: ed.fBody; width: r(900); placeholder: "Ciudad"; onAccepted: ed.searchCity() }
                CButton { id: searchBtn; s: ed.s; family: ed.fBody; text: "Buscar"; onClicked: ed.searchCity() }
            }
            Repeater {
                id: placeRep
                model: ed.places
                delegate: CButton {
                    s: ed.s; family: ed.fBody
                    width: r(1100)
                    text: ed.placeLabel(modelData)
                    checked: !!ed.place && ed.place.lat === modelData.latitude && ed.place.lon === modelData.longitude
                    onClicked: ed.place = { name: modelData.name, lat: modelData.latitude, lon: modelData.longitude, tz: modelData.timezone }
                }
            }
            Row {
                spacing: r(20)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Unidad:"; color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(30) }
                CButton { id: celsiusBtn; s: ed.s; family: ed.fBody; text: "°C Celsius"; checked: ed.unit === "celsius"; onClicked: ed.unit = "celsius" }
                CButton { id: fahrBtn; s: ed.s; family: ed.fBody; text: "°F Fahrenheit"; checked: ed.unit === "fahrenheit"; onClicked: ed.unit = "fahrenheit" }
            }
        }

        // ----- Mercados -----
        Column {
            visible: ed.mode === "fx"
            spacing: r(16)
            Text {
                text: "Elegí hasta 3 para el panel, en el orden en que los marcás"
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28)
            }
            Grid {
                columns: 3; rowSpacing: r(16); columnSpacing: r(20)
                Repeater {
                    id: fxRep
                    model: ed.fxDefs
                    delegate: CButton {
                        property int order: ed.fxSel.indexOf(modelData[0])
                        s: ed.s; family: ed.fBody
                        width: r(420)
                        text: (order >= 0 ? (order + 1) + ".  " : "") + modelData[1]
                        checked: order >= 0
                        enabled: order >= 0 || ed.fxSel.length < 3
                        onClicked: ed.toggleFx(modelData[0])
                    }
                }
            }
        }

        // ----- Calendario -----
        Column {
            visible: ed.mode === "day"
            spacing: r(14)
            Text {
                width: r(1500); wrapMode: Text.Wrap
                text: "Pegá el enlace del calendario público de Google o su ID (termina en @group.calendar.google.com). El calendario tiene que estar compartido como público."
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28)
            }
            CField { id: srcField; s: ed.s; family: ed.fBody; width: r(1500); placeholder: "Enlace o ID del calendario" }
        }

        Row {
            spacing: r(20)
            CButton { id: saveBtn; s: ed.s; family: ed.fBody; text: "Guardar"; primary: true; onClicked: ed.save() }
            CButton { id: cancelBtn; s: ed.s; family: ed.fBody; text: "Cancelar"; onClicked: ed.done(false) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ed.status
                color: ed.statusColor; font.family: ed.fBody; font.pixelSize: r(28)
            }
        }
    }
}
