// RemoteEditor.qml — Configuración → Control remoto: qué hace cada botón del control (lo aplica botones/botones.py).
// A la izquierda el dibujo del control (RemoteDrawing.qml) con los 9 botones que se pueden cambiar; a la derecha la
// lista de esos botones con lo que hace cada uno. OK en un botón → ventanita con las opciones (botones.js → ACTIONS);
// algunas piden un dato: app (el listado de apps, en "modo elegir": lo abre CleanSettings con requestAppPick),
// entrada, página web, panel o volumen. "Volver todo a fábrica" pide confirmación. Cada cambio se guarda enseguida.
// "Modo elegir" (openCapture, desde "Asignar a un botón" en el menú de una app): el dibujo titila y se espera que se
// toque un botón del control (lo anota botones.py en /tmp/cytv-botones-tocado); ese botón pasa a abrir la app.
// Flechas, OK (al soltar) y ATRÁS (lo maneja CleanSettings con back()). Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import "botones.js" as Botones

FocusScope {
    id: ed

    property real s: 1
    property string fBody: "Droid Sans"
    property string fDisplay: "Droid Sans"
    function r(v) { return v * s; }

    property var map: ({})              // botón → acción (botones.json)
    property int sel: 0                 // botón elegido (índice en Botones.KEYS)
    property string step: ""            // "" | actions | input | url | panel | volume | reset
    property bool bt: false             // la tele tiene audio Bluetooth (para "Cambiar la salida de sonido")
    property var inputs: []
    property int volume: 15
    property bool okDown: false
    signal requestAppPick(string key)
    signal exitUp()

    // "modo elegir"
    property bool capturing: false
    property var capEntry: null
    property real capSince: 0
    property string capDone: ""
    signal captureFinished()

    readonly property var curKey: Botones.KEYS[sel]
    property var actions: {
        var l = [];
        for (var i = 0; i < Botones.ACTIONS.length; i++) if (bt || !Botones.ACTIONS[i].bt) l.push(Botones.ACTIONS[i]);
        return l;
    }
    property var listModel: step === "actions" ? actions : step === "input" ? inputs : step === "panel" ? Botones.PANELS : []

    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function shortOf(id) { return Botones.short(map[id]); }

    function open() {
        step = "";
        capturing = false;
        Botones.load(function (j) { ed.map = j; });
        Botones.hasBt(function (b) { ed.bt = b; });
        keyList.currentIndex = sel;
        keyList.forceActiveFocus();
    }
    function leave() {                  // al salir de la sección: cancela en silencio
        if (capturing) { capturing = false; Botones.stopCapture(); }
        step = "";
    }
    // ATRÁS: cierra el paso abierto (devuelve true) o deja que Configuración vuelva al menú (false)
    function back() {
        if (capturing) { cancelCapture(); return true; }
        if (step === "input" || step === "url" || step === "panel" || step === "volume") { openStep("actions"); return true; }
        if (step) { closeStep(); return true; }
        return false;
    }
    function setAction(key, a) {
        var m = {};
        for (var k in map) m[k] = map[k];
        if (!a || a.type === "default") delete m[key]; else m[key] = a;
        map = m;
        Botones.save(m);
    }

    // ---------- pasos de la ventanita ----------
    function openStep(st) {
        step = st;
        if (st === "url") {
            var a = map[curKey.id];
            urlField.text = a && a.type === "url" ? a.url : "";
            urlField.forceActiveFocus();
        } else if (st === "volume") {
            var v = map[curKey.id];
            volume = v && v.type === "volume" ? v.volume : 15;
            volMinus.forceActiveFocus();
        } else if (st === "reset") {
            resetNo.forceActiveFocus();
        } else {
            var cur = map[curKey.id] ? map[curKey.id].type : "default";
            var idx = 0;
            if (st === "actions") for (var i = 0; i < actions.length; i++) if (actions[i].type === cur) idx = i;
            pickList.currentIndex = idx;
            pickList.forceActiveFocus();
        }
    }
    function closeStep() {
        step = "";
        Qt.inputMethod.hide();
        keyList.forceActiveFocus();
    }
    function rebuildInputs() {
        var ci = uiController.mainView && uiController.mainView.cleanInputs ? uiController.mainView.cleanInputs.item : null;
        if (ci) { ci.rebuild(); inputs = ci.items; }
        else inputs = [];
    }
    function choosePick(i) {
        var key = curKey.id;
        if (step === "actions") {
            var t = actions[i].type;
            if (t === "app") { closeStep(); requestAppPick(key); return; }
            if (t === "input") { rebuildInputs(); openStep("input"); return; }
            if (t === "url") { openStep("url"); return; }
            if (t === "panel") { openStep("panel"); return; }
            if (t === "volume") { openStep("volume"); return; }
            setAction(key, { type: t });
            closeStep();
        } else if (step === "input") {
            var it = inputs[i];
            if (it) setAction(key, { type: "input", id: it.appId, label: "Entrada " + it.title });
            closeStep();
        } else if (step === "panel") {
            setAction(key, { type: "panel", panel: Botones.PANELS[i].id });
            closeStep();
        }
    }
    function saveUrl() {
        var u = urlField.text.replace(/^\s+|\s+$/g, "");
        if (!u) return;
        if (!/^[a-z]+:[\/]{2}/i.test(u)) u = "https://" + u;
        setAction(curKey.id, { type: "url", url: u });
        closeStep();
    }
    function appPicked(key, entry) {
        if (entry) setAction(key, { type: "app", id: entry.id, title: entry.title, label: "Abrir " + entry.title });
        keyList.forceActiveFocus();
    }
    function resetAll() {
        map = {};
        Botones.save({});
        closeStep();
    }

    // ---------- "modo elegir" ----------
    function openCapture(entry) {
        capEntry = entry;
        capDone = "";
        capSince = Date.now();
        capturing = true;
        step = "";
        Botones.load(function (j) { ed.map = j; });
        Botones.startCapture();
        ed.forceActiveFocus();
    }
    function cancelCapture() {
        capturing = false;
        Botones.stopCapture();
        captureFinished();
    }
    function captured(key) {
        if (!capturing || capDone) return;
        var e = capEntry;
        if (e) setAction(key, { type: "app", id: e.id, title: e.title, label: "Abrir " + e.title });
        capDone = key;
        sel = Math.max(0, indexOf(key));
        Botones.stopCapture();
        capClose.restart();
    }
    function indexOf(key) {
        for (var i = 0; i < Botones.KEYS.length; i++) if (Botones.KEYS[i].id === key) return i;
        return -1;
    }
    Timer { id: capRefresh; interval: 20000; repeat: true; running: ed.capturing && !ed.capDone; onTriggered: Botones.startCapture() }
    Timer {
        id: capPoll; interval: 300; repeat: true; running: ed.capturing && !ed.capDone
        onTriggered: Botones.readTouched(ed.capSince, function (k) { if (k) ed.captured(k); })
    }
    Timer { id: capClose; interval: 1600; onTriggered: { ed.capturing = false; ed.captureFinished(); } }

    // ATRÁS lo maneja CleanSettings; acá solo OK al soltar en el "modo elegir" (no hace nada) y que no se escape
    Keys.onPressed: { if (ed.capturing) event.accepted = true; }

    // ---------- pantalla ----------
    Text {
        id: capTitle
        visible: ed.capturing
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
        text: ed.capDone
              ? "Listo: " + Botones.keyById(ed.capDone).name + " → abre " + (ed.capEntry ? ed.capEntry.title : "")
              : "Tocá el botón del control que querés usar para abrir " + (ed.capEntry ? ed.capEntry.title : "")
        color: ed.capDone ? "#3ddc97" : "#eef1f6"; font.family: ed.fDisplay; font.pixelSize: ed.r(40); font.weight: Font.Bold
    }
    Text {
        visible: ed.capturing && !ed.capDone
        anchors.top: capTitle.bottom; anchors.topMargin: ed.r(8)
        anchors.horizontalCenter: parent.horizontalCenter
        text: "ATRÁS para cancelar"
        color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(26)
    }

    RemoteDrawing {
        id: drawing
        x: ed.capturing ? ed.r(260) : ed.r(40)
        y: ed.capturing ? ed.r(110) : 0
        height: ed.capturing ? parent.height - ed.r(110) : parent.height - ed.r(10)
        selected: ed.capturing && !ed.capDone ? "" : ed.curKey.id
        blink: ed.capturing && !ed.capDone
        onHovered: if (!ed.capturing && ed.step === "") { ed.sel = ed.indexOf(key); keyList.currentIndex = ed.sel; keyList.forceActiveFocus(); }
        onClicked: {
            if (ed.capturing) { ed.captured(key); return; }
            if (ed.step !== "") return;
            ed.sel = ed.indexOf(key); keyList.currentIndex = ed.sel; ed.openStep("actions");
        }
    }
    // cartelito al lado del botón elegido
    Rectangle {
        visible: !ed.capturing || ed.capDone !== ""
        property var zn: ed.curKey.zone
        x: drawing.x + drawing.width + ed.r(14)
        y: drawing.y + (zn[1] + zn[3] / 2) * drawing.k - height / 2
        width: bubble.implicitWidth + ed.r(28); height: ed.r(46); radius: ed.r(10)
        color: Qt.rgba(1, 1, 1, 0.10); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
        Text {
            id: bubble
            anchors.centerIn: parent
            text: ed.curKey.name + " → " + ed.shortOf(ed.curKey.id)
            color: "#eef1f6"; font.family: ed.fBody; font.pixelSize: ed.r(24); font.weight: Font.DemiBold
        }
    }

    // lista de botones (en "modo elegir" se ve, para saber qué hace cada uno, pero no se maneja)
    Text {
        id: listTitle
        visible: !ed.capturing
        x: ed.r(620); y: 0
        text: "Elegí un botón y qué querés que haga"
        color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(26)
    }
    ListView {
        id: keyList
        x: ed.capturing ? ed.r(720) : ed.r(620)
        y: ed.capturing ? ed.r(150) : ed.r(50)
        width: ed.capturing ? parent.width - x - ed.r(60) : parent.width - x
        height: Botones.KEYS.length * ed.r(64)
        spacing: ed.r(6); interactive: false; focus: true
        model: Botones.KEYS
        currentIndex: ed.sel
        onCurrentIndexChanged: if (!ed.capturing) ed.sel = currentIndex
        delegate: Rectangle {
            property bool isSel: ListView.isCurrentItem && keyList.activeFocus && !ed.capturing   // en "modo elegir" no hay fila elegida
            property bool changed: !!ed.map[modelData.id]
            width: keyList.width; height: ed.r(58); radius: ed.r(14)
            color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 0.98)
            border.width: isSel ? ed.r(4) : 1
            border.color: isSel ? "#ffffff" : (ed.capDone === modelData.id ? "#3ddc97" : Qt.rgba(1, 1, 1, 0.08))
            Rectangle {
                x: ed.r(22); anchors.verticalCenter: parent.verticalCenter
                width: ed.r(26); height: ed.r(16); radius: height / 2
                color: modelData.chip
            }
            Text {
                x: ed.r(66); anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: "#eef1f6"; font.family: ed.fDisplay; font.pixelSize: ed.r(28); font.weight: Font.Bold
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: ed.r(24); anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.55; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                text: ed.shortOf(modelData.id)
                color: parent.changed ? "#6fa8ff" : "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(26)
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; enabled: !ed.capturing && ed.step === ""
                onEntered: { keyList.currentIndex = index; keyList.forceActiveFocus(); }
                onClicked: { keyList.currentIndex = index; ed.openStep("actions"); }
            }
        }
        Keys.onUpPressed: { if (currentIndex <= 0) ed.exitUp(); else event.accepted = false; }
        Keys.onDownPressed: { if (currentIndex >= count - 1) resetBtn.forceActiveFocus(); else event.accepted = false; }
        Keys.onPressed: { if (ed.isOk(event.key)) { if (!event.isAutoRepeat) ed.okDown = true; event.accepted = true; } }
        Keys.onReleased: {
            if (ed.isOk(event.key)) { event.accepted = true; if (ed.okDown && !event.isAutoRepeat) ed.openStep("actions"); ed.okDown = false; }
        }
    }
    CButton {
        id: resetBtn
        visible: !ed.capturing
        x: keyList.x; y: keyList.y + keyList.height + ed.r(14)
        s: ed.s; family: ed.fBody; text: "Volver todo a fábrica"
        onClicked: ed.openStep("reset")
        Keys.onUpPressed: keyList.forceActiveFocus()
    }

    // ---------- ventanita ----------
    Rectangle {
        visible: ed.step !== ""
        anchors.fill: parent; anchors.margins: -ed.r(400)
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: ed.closeStep() }
    }
    Rectangle {
        id: dlg
        visible: ed.step !== ""
        width: ed.r(920); height: dlgCol.height + ed.r(70)
        anchors.centerIn: parent
        radius: ed.r(28)
        color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 1)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
        MouseArea { anchors.fill: parent }
        Column {
            id: dlgCol
            x: ed.r(44); y: ed.r(34); width: parent.width - ed.r(88)
            spacing: ed.r(18)
            Text {
                width: parent.width; elide: Text.ElideRight
                text: ed.step === "reset" ? "Volver todo a fábrica"
                      : ed.curKey.name + (ed.step === "actions" ? ": ¿qué querés que haga?"
                                         : ed.step === "input" ? ": elegí la entrada"
                                         : ed.step === "panel" ? ": elegí el panel"
                                         : ed.step === "url" ? ": página web" : ": volumen fijo")
                color: "#eef1f6"; font.family: ed.fDisplay; font.pixelSize: ed.r(38); font.weight: Font.Bold
            }
            // listas: acciones, entradas, paneles
            ListView {
                id: pickList
                visible: ed.step === "actions" || ed.step === "input" || ed.step === "panel"
                width: parent.width
                height: visible ? Math.min(count * ed.r(78), ed.r(560)) : 0
                clip: true; spacing: ed.r(6); interactive: true; keyNavigationWraps: false
                highlightMoveDuration: 120
                model: ed.listModel
                property bool okDown: false
                delegate: Rectangle {
                    property bool isSel: ListView.isCurrentItem && pickList.activeFocus
                    property bool isCur: ed.step === "actions" && (ed.map[ed.curKey.id] ? ed.map[ed.curKey.id].type : "default") === modelData.type
                    width: pickList.width; height: ed.r(72); radius: ed.r(14)
                    color: Qt.rgba(1, 1, 1, isSel ? 0.10 : 0.04)
                    border.width: isSel ? ed.r(4) : 1
                    border.color: isSel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        id: pt
                        x: ed.r(24); y: modelData.sub ? ed.r(10) : (parent.height - height) / 2
                        text: (parent.isCur ? "✓  " : "") + modelData.title
                        color: "#eef1f6"; font.family: ed.fBody; font.pixelSize: ed.r(28); font.weight: Font.DemiBold
                    }
                    Text {
                        visible: !!modelData.sub
                        x: ed.r(24); anchors.top: pt.bottom
                        width: parent.width - ed.r(48); elide: Text.ElideRight
                        text: modelData.sub || ""
                        color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(21)
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: { pickList.currentIndex = index; pickList.forceActiveFocus(); }
                        onClicked: { pickList.currentIndex = index; ed.choosePick(index); }
                    }
                }
                Keys.onPressed: { if (ed.isOk(event.key)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
                Keys.onReleased: {
                    if (ed.isOk(event.key)) { event.accepted = true; if (okDown && !event.isAutoRepeat) ed.choosePick(currentIndex); okDown = false; }
                }
            }
            Text {
                visible: ed.step === "input" && ed.inputs.length === 0
                text: "No encontré entradas."
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(26)
            }
            // página web
            CField {
                id: urlField
                visible: ed.step === "url"
                s: ed.s; family: ed.fBody; width: parent.width
                placeholder: "Dirección, por ejemplo lanacion.com.ar"
                onAccepted: urlSave.forceActiveFocus()
                Keys.onDownPressed: urlSave.forceActiveFocus()
            }
            Text {
                visible: ed.step === "url"
                width: parent.width; wrapMode: Text.WordWrap
                text: "También podés pedírsela a Claude desde la compu."
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(22)
            }
            Row {
                visible: ed.step === "url"
                spacing: ed.r(18)
                CButton { id: urlSave; s: ed.s; family: ed.fBody; text: "Guardar"; primary: true; onClicked: ed.saveUrl()
                          Keys.onUpPressed: urlField.forceActiveFocus(); Keys.onRightPressed: urlCancel.forceActiveFocus() }
                CButton { id: urlCancel; s: ed.s; family: ed.fBody; text: "Cancelar"; onClicked: ed.openStep("actions")
                          Keys.onUpPressed: urlField.forceActiveFocus(); Keys.onLeftPressed: urlSave.forceActiveFocus() }
            }
            // volumen fijo
            Row {
                visible: ed.step === "volume"
                spacing: ed.r(24)
                CButton { id: volMinus; s: ed.s; family: ed.fBody; text: "−"; onClicked: ed.volume = Math.max(0, ed.volume - 1)
                          Keys.onRightPressed: volPlus.forceActiveFocus(); Keys.onDownPressed: volSave.forceActiveFocus() }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: ed.r(120); horizontalAlignment: Text.AlignHCenter
                    text: String(ed.volume)
                    color: "#eef1f6"; font.family: ed.fDisplay; font.pixelSize: ed.r(56); font.weight: Font.Bold
                }
                CButton { id: volPlus; s: ed.s; family: ed.fBody; text: "+"; onClicked: ed.volume = Math.min(100, ed.volume + 1)
                          Keys.onLeftPressed: volMinus.forceActiveFocus(); Keys.onDownPressed: volSave.forceActiveFocus() }
            }
            Row {
                visible: ed.step === "volume"
                spacing: ed.r(18)
                CButton { id: volSave; s: ed.s; family: ed.fBody; text: "Guardar"; primary: true
                          onClicked: { ed.setAction(ed.curKey.id, { type: "volume", volume: ed.volume }); ed.closeStep(); }
                          Keys.onUpPressed: volMinus.forceActiveFocus(); Keys.onRightPressed: volCancel.forceActiveFocus() }
                CButton { id: volCancel; s: ed.s; family: ed.fBody; text: "Cancelar"; onClicked: ed.openStep("actions")
                          Keys.onUpPressed: volMinus.forceActiveFocus(); Keys.onLeftPressed: volSave.forceActiveFocus() }
            }
            // volver todo a fábrica
            Text {
                visible: ed.step === "reset"
                width: parent.width; wrapMode: Text.WordWrap
                text: "Todos los botones vuelven a hacer lo de fábrica."
                color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: ed.r(26)
            }
            Row {
                visible: ed.step === "reset"
                spacing: ed.r(18)
                CButton { id: resetYes; s: ed.s; family: ed.fBody; text: "Sí, volver a fábrica"; onClicked: ed.resetAll()
                          Keys.onRightPressed: resetNo.forceActiveFocus() }
                CButton { id: resetNo; s: ed.s; family: ed.fBody; text: "No"; primary: true; onClicked: ed.closeStep()
                          Keys.onLeftPressed: resetYes.forceActiveFocus() }
            }
        }
    }
}
