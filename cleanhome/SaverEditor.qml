// SaverEditor.qml — editor visual del protector (botón "Editar" sobre el protector, en CleanDetail.qml).
// Se ve el protector de verdad con sus 6 partes marcadas (arriba y abajo: izquierda, centro, derecha):
//   - elegís una parte (flechas o puntero) y con OK / click se abre la lista: qué va ahí (o "Nada") y de qué tamaño;
//     el cambio se ve en vivo.
//   - al medio: encendido/apagado, segundos por foto y álbum, con Guardar y Cancelar.
// Guarda en settings.json → saver { enabled, interval, source, layout } (settings.js) y, si cambió el álbum,
// en saver/config.json + saver/pedido para que la tarea de fondo baje la lista nueva. ATRÁS: cancelar. Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import "settings.js" as Settings

FocusScope {
    id: ed

    property real s: 1
    property string fBody: "Droid Sans"
    property string fTitle: "Droid Sans"
    property Item saver: null           // el CleanSaver que se está viendo
    property var cfg: null              // copia de trabajo de settings.json
    property var lay: ({})              // copia de trabajo de saver.layout
    property string origSrc: ""
    property string focusSlot: ""       // parte elegida con las flechas ("" = el foco está en un botón)
    property bool picking: false        // lista de "qué va acá" abierta
    property string pickSlot: ""
    property string status: ""
    property color statusColor: "#3ddc97"
    property bool okDown: false
    signal done(bool saved)

    function r(v) { return v * s; }
    function isBack(k) { return k === WebOS.Key_webOS_Back || k === Qt.Key_Escape || k === Qt.Key_Back; }
    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function slotDef(id) {
        for (var i = 0; i < Settings.SAVER_SLOTS.length; i++) if (Settings.SAVER_SLOTS[i].id === id) return Settings.SAVER_SLOTS[i];
        return null;
    }

    // ---------- Abrir ----------
    function open(sv) {
        saver = sv;
        status = "";
        picking = false;
        Settings.load(function (st) {
            ed.cfg = st;
            ed.lay = Settings.copyLayout(Settings.saverLayout(st.saver));
            if (ed.saver) { ed.saver.layoutOverride = ed.lay; ed.saver.editing = true; }
            enabledSw.checked = st.saver.enabled !== false;
            numField.text = String(st.saver.interval || 10);
            ed.origSrc = st.saver.source || "";
            srcField.text = ed.origSrc;
            if (!ed.origSrc) Settings.readText(Settings.BASE + "saver/config.json", function (txt) {   // el álbum real (no se publica)
                try { var j = JSON.parse(txt); ed.origSrc = j.source || j.album || ""; srcField.text = ed.origSrc; } catch (e) {}
            });
            ed.focusAt("br");
        });
    }
    function finish(saved) {
        Qt.inputMethod.hide();
        picking = false;
        focusSlot = "";
        if (saver) { saver.selSlot = ""; saver.editing = false; saver.layoutOverride = null; }
        done(saved);
    }

    // ---------- Cambiar lo que va en una parte (se ve en vivo) ----------
    function setSlot(id, w, size) {
        var l = Settings.copyLayout(lay);
        if (!l[id]) l[id] = { w: "", size: "m" };
        if (w !== null) l[id].w = w;
        if (size !== null) l[id].size = size;
        lay = l;
        if (saver) saver.layoutOverride = l;
    }
    function openPicker(id) {
        pickSlot = id;
        picking = true;
        if (saver) saver.selSlot = id;
        var cur = lay[id] ? lay[id].w : "";
        for (var i = 0; i < Settings.SAVER_WIDGETS.length; i++)
            if (Settings.SAVER_WIDGETS[i][0] === cur) { focusAt(wRep.itemAt(i)); return; }
        focusAt(wRep.itemAt(0));
    }
    function closePicker() {
        picking = false;
        focusAt(pickSlot);
    }

    // ---------- Guardar ----------
    function save() {
        var c = cfg.saver;
        var n = parseInt(numField.text, 10);
        if (isNaN(n) || n < 5) { n = Math.max(5, isNaN(n) ? 10 : n); numField.text = String(n); }
        var src = srcField.text.replace(/^\s+|\s+$/g, "");
        if (!src) { status = "Falta el enlace del álbum"; statusColor = "#ff6b6b"; return; }
        c.enabled = enabledSw.checked;
        c.interval = n;
        c.layout = Settings.copyLayout(lay);
        c.source = src;
        // los interruptores viejos ya no se usan (ahora manda layout)
        delete c.showClock; delete c.showWeather; delete c.showCalNow; delete c.showCalNext; delete c.showCal;
        if (src !== origSrc) {
            Settings.writeText(Settings.BASE + "saver/config.json", JSON.stringify({ source: src, max: 2000 }), null);
            Settings.writeText(Settings.BASE + "saver/pedido", "1", null);
        }
        status = "Guardando…"; statusColor = "#9aa3b5";
        Settings.save(cfg, function (ok) {
            if (!ok) { ed.status = "No pude guardar los cambios"; ed.statusColor = "#ff6b6b"; return; }
            ed.status = src !== ed.origSrc ? "Guardado. Las fotos del álbum nuevo llegan en menos de un minuto." : "Guardado.";
            ed.statusColor = "#3ddc97";
            closeTimer.restart();
        });
    }
    Timer { id: closeTimer; interval: 1200; onTriggered: ed.finish(true) }

    // ---------- Flechas: filas en el orden en que se ven (las partes van como texto: "tl", "tc"…) ----------
    function rows() {
        if (picking) {
            var rs = [];
            for (var i = 0; i < wRep.count; i += 3) rs.push([wRep.itemAt(i), wRep.itemAt(i + 1), wRep.itemAt(i + 2)]);
            rs.push([sizeRep.itemAt(0), sizeRep.itemAt(1), sizeRep.itemAt(2)]);
            rs.push([pickDoneBtn]);
            return rs;
        }
        return [["tl", "tc", "tr"], [enabledSw], [numField], [srcField], [saveBtn, cancelBtn], ["bl", "bc", "br"]];
    }
    function focusAt(x) {
        if (!x) return;
        if (typeof x === "string") {
            focusSlot = x;
            if (saver) saver.selSlot = x;
            ed.forceActiveFocus();
        } else {
            focusSlot = "";
            if (saver) saver.selSlot = picking ? pickSlot : "";
            x.forceActiveFocus();
        }
    }
    function move(dr, dc) {
        var rs = rows(), R = -1, C = 0;
        for (var a = 0; a < rs.length && R < 0; a++)
            for (var b = 0; b < rs[a].length; b++) {
                var it = rs[a][b];
                if ((typeof it === "string" && it === focusSlot) || (it && typeof it !== "string" && (it.activeFocus || it.editing))) { R = a; C = b; break; }
            }
        if (R < 0) { focusAt(picking ? wRep.itemAt(0) : "br"); return; }
        if (dc !== 0) C = Math.max(0, Math.min(rs[R].length - 1, C + dc));
        else {
            var nr = Math.max(0, Math.min(rs.length - 1, R + dr));
            // de una fila de 3 a una de 1 (y al revés) se va al del medio / al primero
            if (rs[nr].length !== rs[R].length) C = rs[nr].length === 3 ? 1 : 0;
            R = nr;
            C = Math.min(C, rs[R].length - 1);
        }
        while (C > 0 && rs[R][C] && typeof rs[R][C] !== "string" && rs[R][C].enabled === false) C--;
        focusAt(rs[R][C]);
    }
    Keys.onPressed: {
        event.accepted = true;               // nada se escapa a la pantalla de abajo
        if (event.key === Qt.Key_Up) move(-1, 0);
        else if (event.key === Qt.Key_Down) move(1, 0);
        else if (event.key === Qt.Key_Left) move(0, -1);
        else if (event.key === Qt.Key_Right) move(0, 1);
        else if (isOk(event.key) && !event.isAutoRepeat) okDown = true;
    }
    Keys.onReleased: {
        event.accepted = true;
        if (isBack(event.key)) { if (picking) closePicker(); else finish(false); return; }
        if (isOk(event.key) && !event.isAutoRepeat) {
            if (okDown && focusSlot !== "") openPicker(focusSlot);
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false

    Connections {
        target: ed.saver
        ignoreUnknownSignals: true
        onSlotClicked: ed.openPicker(id)
        onSlotHovered: if (!ed.picking) ed.focusAt(id)
    }

    // ---------- Panel del medio: encendido, segundos, álbum ----------
    Rectangle {
        id: panel
        visible: !ed.picking
        anchors.horizontalCenter: parent.horizontalCenter
        y: r(268); width: r(1000); height: pcol.height + r(56)
        radius: r(28)
        color: Qt.rgba(14 / 255, 17 / 255, 23 / 255, 0.92)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)
        MouseArea { anchors.fill: parent; hoverEnabled: true }      // que el puntero no toque las partes de atrás

        Column {
            id: pcol
            x: r(40); y: r(28); width: parent.width - r(80)
            spacing: r(16)
            Text {
                text: "Elegí una parte de la pantalla para cambiar qué va ahí"
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(26)
            }
            CSwitch { id: enabledSw; s: ed.s; family: ed.fBody; text: "Protector con fotos del álbum" }
            Row {
                spacing: r(20)
                CField { id: numField; s: ed.s; family: ed.fBody; width: r(200); numeric: true }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "segundos por foto (mínimo 5)"
                    color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28)
                }
            }
            CField { id: srcField; s: ed.s; family: ed.fBody; width: pcol.width; placeholder: "Enlace o código del álbum de Google Fotos" }
            Row {
                spacing: r(20)
                CButton { id: saveBtn; s: ed.s; family: ed.fBody; text: "Guardar"; primary: true; onClicked: ed.save() }
                CButton { id: cancelBtn; s: ed.s; family: ed.fBody; text: "Cancelar"; onClicked: ed.finish(false) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: pcol.width - saveBtn.width - cancelBtn.width - r(40); wrapMode: Text.Wrap
                    text: ed.status
                    color: ed.statusColor; font.family: ed.fBody; font.pixelSize: r(26)
                }
            }
        }
    }

    // ---------- Lista: qué va en esta parte y de qué tamaño ----------
    Rectangle {
        id: picker
        visible: ed.picking
        anchors.horizontalCenter: parent.horizontalCenter
        y: r(540) - height / 2; width: r(1060); height: kcol.height + r(56)
        radius: r(28)
        color: Qt.rgba(14 / 255, 17 / 255, 23 / 255, 0.95)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Column {
            id: kcol
            x: r(40); y: r(28); width: parent.width - r(80)
            spacing: r(14)
            Text {
                text: ed.slotDef(ed.pickSlot) ? ed.slotDef(ed.pickSlot).name : ""
                color: "#eef1f6"; font.family: ed.fTitle; font.pixelSize: r(40); font.weight: Font.Bold
            }
            Grid {
                columns: 3; rowSpacing: r(12); columnSpacing: r(16)
                Repeater {
                    id: wRep
                    model: Settings.SAVER_WIDGETS
                    delegate: CButton {
                        s: ed.s; family: ed.fBody
                        width: (kcol.width - r(32)) / 3
                        text: modelData[1]
                        checked: !!ed.lay[ed.pickSlot] && ed.lay[ed.pickSlot].w === modelData[0]
                        onClicked: ed.setSlot(ed.pickSlot, modelData[0], null)
                    }
                }
            }
            Row {
                spacing: r(16)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: r(150)
                    text: "Tamaño"
                    color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(28)
                }
                Repeater {
                    id: sizeRep
                    model: Settings.SAVER_SIZES
                    delegate: CButton {
                        s: ed.s; family: ed.fBody
                        width: r(230)
                        text: modelData[1]
                        enabled: !!ed.lay[ed.pickSlot] && ed.lay[ed.pickSlot].w !== ""
                        opacity: enabled ? 1 : 0.4
                        checked: !!ed.lay[ed.pickSlot] && ed.lay[ed.pickSlot].size === modelData[0]
                        onClicked: ed.setSlot(ed.pickSlot, null, modelData[0])
                    }
                }
            }
            CButton { id: pickDoneBtn; s: ed.s; family: ed.fBody; text: "Listo"; primary: true; onClicked: ed.closePicker() }
        }
    }
}
