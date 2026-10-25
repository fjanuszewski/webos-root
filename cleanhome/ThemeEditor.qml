// ThemeEditor.qml — Configuración → Tema: el fondo de la pantalla de inicio, el color de los paneles, el color de lo
// seleccionado y el tamaño de la letra de los widgets.
//   Fondo: "Colores de la app" (se tiñe con la app elegida, como siempre) · "Color fijo" · "Foto".
//   Las fotos salen de /var/lib/webosbrew/fondos/ en la tele (la lista, la más nueva primero, la arma fondos.sh en
//   fondos/index.json). "Agregar foto" (FondoAgregar.qml) suma una desde el pendrive, la tele, un enlace o Bluetooth y
//   la deja elegida; también se pueden subir desde la compu con tools/subir-fondo.sh.
// Cada cambio se guarda enseguida en settings.json → theme y avisa al inicio (mainView.cleanRev). Qt 5.6.
import QtQuick 2.6
import "settings.js" as Settings

FocusScope {
    id: ed

    property real s: 1
    property string fBody: "Droid Sans"
    property string fDisplay: "Droid Sans"
    function r(v) { return v * s; }

    property var th: Settings.defaults().theme
    property var cfg: null              // settings.json leído al entrar (se guarda desde acá, sin volver a leer)
    property var photos: []
    property string status: ""
    property color statusColor: "#9aa3b5"
    readonly property string fondos: "file:///var/lib/webosbrew/fondos/"
    property bool adding: false         // se ve "Agregar foto" en vez de Tema

    function open() {
        status = "";
        adding = false;
        Settings.load(function (st) {
            ed.cfg = st;
            ed.th = st.theme;
            ed.readPhotos(function () { bgRep.itemAt(0).forceActiveFocus(); });
        });
    }
    function readPhotos(cb) {
        Settings.readText(ed.fondos + "index.json", function (txt) {
            var l = [];
            try { l = JSON.parse(txt) || []; } catch (e) { l = []; }
            ed.photos = l;
            if (cb) cb();
        });
    }

    // ---------- Agregar foto ----------
    function startAdding() { adding = true; adder.open(); }
    // ATRÁS (lo llama CleanSettings): true si lo usó para volver desde "Agregar foto"
    function back() {
        if (!adding) return false;
        if (adder.back()) return true;
        adding = false;
        addBtn.forceActiveFocus();
        return true;
    }
    // Llegó una foto nueva: queda elegida como fondo
    function photoAdded(name) {
        adding = false;
        readPhotos(function () {
            var t = JSON.parse(JSON.stringify(ed.th));
            t.bg = "photo";
            t.photo = name;
            ed.th = t;
            ed.saveNow("Listo: la foto nueva ya es tu fondo. Cerrá la configuración para verla.");
            if (photoRep.count) photoRep.itemAt(0).forceActiveFocus(); else addBtn.forceActiveFocus();
        });
    }

    // ---------- Guardar (cada cambio) ----------
    function setTheme(key, val) {
        var t = JSON.parse(JSON.stringify(th));
        t[key] = val;
        if (key === "bg" && val === "photo" && !t.photo && photos.length) t.photo = photos[0];
        th = t;
        status = "Guardando…"; statusColor = "#9aa3b5";
        saveNow();
    }
    // Guarda el tema actual (cada cambio, y otra vez al salir de Tema por las dudas)
    function saveNow(okText) {
        if (!cfg) return;
        cfg.theme = JSON.parse(JSON.stringify(th));
        Settings.save(cfg, function (ok) {
            ed.status = ok ? (okText || "Guardado. Cerrá la configuración para verlo.") : "No pude guardar los cambios";
            ed.statusColor = ok ? "#3ddc97" : "#ff6b6b";
            var mv = uiController.mainView;
            if (ok && mv) mv.cleanRev = mv.cleanRev + 1;
        });
    }
    function leave() { adding = false; if (cfg) saveNow(); }

    // ---------- Flechas: filas en el orden en que se ven ----------
    function rowItems(rep) { var a = []; for (var i = 0; i < rep.count; i++) a.push(rep.itemAt(i)); return a; }
    function rows() {
        var rs = [rowItems(bgRep)];
        if (th.bg === "color") rs.push(rowItems(bgColRep));
        if (th.bg === "photo") rs.push(rowItems(photoRep).concat([addBtn]));
        if (th.bg === "photo" && photos.length) rs.push(rowItems(dimRep));
        rs.push(rowItems(panelRep));
        rs.push(rowItems(accentRep));
        rs.push(rowItems(fontRep));
        return rs;
    }
    function move(dr, dc) {
        var rs = rows(), R = -1, C = 0;
        for (var a = 0; a < rs.length && R < 0; a++)
            for (var b = 0; b < rs[a].length; b++) if (rs[a][b] && rs[a][b].activeFocus) { R = a; C = b; break; }
        if (R < 0) { if (rs[0][0]) rs[0][0].forceActiveFocus(); return; }
        if (dc) C = Math.max(0, Math.min(rs[R].length - 1, C + dc));
        else { R = Math.max(0, Math.min(rs.length - 1, R + dr)); C = Math.min(C, rs[R].length - 1); }
        if (rs[R][C]) rs[R][C].forceActiveFocus();
    }
    Keys.onPressed: {
        if (adding) { if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) event.accepted = true; return; }
        if (event.key === Qt.Key_Up) { move(-1, 0); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { move(1, 0); event.accepted = true; }
        else if (event.key === Qt.Key_Left) { move(0, -1); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { move(0, 1); event.accepted = true; }
    }

    // ---------- Pantalla ----------
    Column {
        visible: !ed.adding
        width: parent.width
        spacing: r(14)

        Text { text: "Fondo"; color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28) }
        Row {
            spacing: r(16)
            Repeater {
                id: bgRep
                model: [["dynamic", "Colores de la app"], ["color", "Color fijo"], ["photo", "Foto"]]
                delegate: CButton { s: ed.s; family: ed.fBody; text: modelData[1]; checked: ed.th.bg === modelData[0]; onClicked: ed.setTheme("bg", modelData[0]) }
            }
        }
        Row {
            visible: ed.th.bg === "color"
            spacing: r(14)
            Repeater {
                id: bgColRep
                model: Settings.THEME_BG_COLORS
                delegate: Swatch { s: ed.s; fill: modelData; checked: ed.th.bgColor === modelData; onClicked: ed.setTheme("bgColor", modelData) }
            }
        }
        Text {
            visible: ed.th.bg === "photo" && ed.photos.length === 0
            width: parent.width; wrapMode: Text.Wrap
            text: "Todavía no hay fotos. Agregá una desde un pendrive, la tele, un enlace o Bluetooth."
            color: "#f5b83d"; font.family: ed.fBody; font.pixelSize: r(26)
        }
        Flow {
            visible: ed.th.bg === "photo"
            width: parent.width
            spacing: r(14)
            Repeater {
                id: photoRep
                model: ed.th.bg === "photo" ? ed.photos.slice(0, 6) : []
                delegate: Swatch { s: ed.s; image: ed.fondos + modelData; checked: ed.th.photo === modelData; onClicked: ed.setTheme("photo", modelData) }
            }
            CButton {
                id: addBtn
                s: ed.s; family: ed.fBody; text: "+  Agregar foto"
                height: 90 * ed.s
                onClicked: ed.startAdding()
            }
        }
        Row {
            visible: ed.th.bg === "photo" && ed.photos.length > 0
            spacing: r(16)
            Text { anchors.verticalCenter: parent.verticalCenter; width: r(190); text: "Oscurecer:"; color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28) }
            Repeater {
                id: dimRep
                model: [[0, "Nada"], [0.2, "Poco"], [0.4, "Medio"], [0.6, "Mucho"]]
                delegate: CButton { s: ed.s; family: ed.fBody; text: modelData[1]; checked: Math.abs((ed.th.photoDim || 0) - modelData[0]) < 0.06; onClicked: ed.setTheme("photoDim", modelData[0]) }
            }
        }

        Item { width: 1; height: r(6) }
        Row {
            spacing: r(16)
            Text { anchors.verticalCenter: parent.verticalCenter; width: r(250); text: "Paneles"; color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28) }
            Repeater {
                id: panelRep
                model: [["dark", "Oscuros"], ["gray", "Grises"], ["clear", "Transparentes"]]
                delegate: CButton { s: ed.s; family: ed.fBody; text: modelData[1]; checked: ed.th.panel === modelData[0]; onClicked: ed.setTheme("panel", modelData[0]) }
            }
        }
        Row {
            spacing: r(14)
            Text { anchors.verticalCenter: parent.verticalCenter; width: r(252); text: "Selección"; color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28) }
            Repeater {
                id: accentRep
                model: Settings.THEME_COLORS
                delegate: Swatch { s: ed.s; fill: modelData; checked: ed.th.accent === modelData; onClicked: ed.setTheme("accent", modelData) }
            }
        }
        Row {
            spacing: r(16)
            Text { anchors.verticalCenter: parent.verticalCenter; width: r(250); text: "Letra"; color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28) }
            Repeater {
                id: fontRep
                model: [["s", "Chica"], ["m", "Normal"], ["l", "Grande"]]
                delegate: CButton { s: ed.s; family: ed.fBody; text: modelData[1]; checked: ed.th.font === modelData[0]; onClicked: ed.setTheme("font", modelData[0]) }
            }
        }
        Text {
            text: ed.status
            color: ed.statusColor; font.family: ed.fBody; font.pixelSize: r(26)
        }
    }

    FondoAgregar {
        id: adder
        visible: ed.adding
        anchors.fill: parent
        s: ed.s; fBody: ed.fBody; fDisplay: ed.fDisplay
        onAdded: ed.photoAdded(photo)
    }
}
