// WidgetsEditor.qml — Configuración → Widgets: qué widgets van en la pantalla de inicio, dónde y de qué tamaño.
// Muestra la cuadrícula de 4×4 casillas (la misma zona que ocupan los widgets en el inicio):
//   - flechas o puntero recorren las casillas;
//   - OK en un widget → abajo: sus tamaños, Mover y Quitar;
//   - OK en una casilla vacía o el botón "Agregar widget" → los widgets que todavía no están;
//   - Mover: las flechas lo corren casilla por casilla; OK lo deja ahí, ATRÁS lo devuelve a donde estaba.
// Al mover, agrandar o agregar, los demás se acomodan solos (Settings.gridRelayout): se corren al lugar libre más
// cercano y, si no entran, se achican; solo si no entran de ninguna forma quedan afuera (se avisa).
// Cada cambio se guarda enseguida en settings.json → home.grid y avisa al inicio (mainView.cleanRev). Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import "settings.js" as Settings

FocusScope {
    id: ed

    property real s: 1
    property string fBody: "Droid Sans"
    property string fDisplay: "Droid Sans"
    function r(v) { return v * s; }

    property var grid: []
    property var cfg: null              // settings.json leído al entrar (se guarda desde acá, sin volver a leer)
    property bool dirty: false
    property int cc: 0                  // casilla elegida (columna, fila)
    property int cr: 0
    property bool moving: false
    property var moveBase: null         // cómo estaba todo al empezar a mover (cada paso se acomoda desde acá)
    property int moveIdx: -1
    property bool adding: false         // lista de "Agregar" abierta
    property string status: ""
    property color statusColor: "#9aa3b5"
    property bool okDown: false

    readonly property var tint: ({ wx: "#6fa8ff", fx: "#3ddc97", cal: "#f5b83d" })
    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function isBack(k) { return k === WebOS.Key_webOS_Back || k === Qt.Key_Escape || k === Qt.Key_Back; }

    property int selIdx: Settings.gridAt(grid, cc, cr)          // widget bajo la casilla elegida (-1 = vacía)
    property var selItem: selIdx >= 0 ? grid[selIdx] : null
    property var selDef: selItem ? Settings.homeWidget(selItem.w) : null
    // widgets que todavía no están en la cuadrícula
    property var missing: {
        var out = [];
        for (var i = 0; i < Settings.HOME_WIDGETS.length; i++) {
            var d = Settings.HOME_WIDGETS[i], here = false;
            for (var j = 0; j < grid.length; j++) if (grid[j].w === d.id) here = true;
            if (!here) out.push(d);
        }
        return out;
    }

    function open() {
        status = ""; moving = false; adding = false;
        Settings.load(function (st) {
            ed.cfg = st;
            ed.dirty = false;
            ed.grid = Settings.cleanGrid(st.home ? st.home.grid : []);
            ed.cc = 0; ed.cr = 0;
            ed.forceActiveFocus();
        });
    }

    // ---------- Guardar (cada cambio) ----------
    function commit(g, msg) {
        grid = g;
        dirty = true;
        status = "Guardando…"; statusColor = "#9aa3b5";
        saveNow(msg);
    }
    // Guarda la cuadrícula actual (cada cambio, y otra vez al salir de Widgets por las dudas)
    function saveNow(msg) {
        if (!cfg) return;
        cfg.home = { grid: JSON.parse(JSON.stringify(grid)) };
        Settings.save(cfg, function (ok) {
            if (ok) ed.dirty = false;
            ed.status = ok ? (msg || "Guardado. Ya se ve en el inicio.") : "No pude guardar los cambios";
            ed.statusColor = ok ? "#3ddc97" : "#ff6b6b";
            var mv = uiController.mainView;
            if (ok && mv) mv.cleanRev = mv.cleanRev + 1;
        });
    }
    function leave() {
        if (moving) endMove(true);
        adding = false;
        if (cfg) saveNow();
    }
    function copyGrid() { return JSON.parse(JSON.stringify(grid)); }
    function fitsFirst(d, c, r0) {      // primer tamaño del widget que entra arrancando en (c, r0)
        for (var i = 0; i < d.sizes.length; i++)
            if (Settings.gridFits(grid, c, r0, d.sizes[i][0], d.sizes[i][1], -1)) return d.sizes[i];
        return null;
    }
    function droppedMsg(list) { return list.length ? " No entró " + list.join(" ni ") + ": lo podés volver a agregar." : ""; }
    // Agregar: en la casilla elegida si entra; si no, en cualquier lugar libre (del tamaño más chico al más grande);
    // si no hay lugar, en la casilla elegida con su tamaño más chico y los demás se acomodan alrededor.
    function addWidget(d) {
        adding = false;
        var g = copyGrid(), at = null, sz, i, rr, c;
        sz = fitsFirst(d, cc, cr);
        if (sz && Settings.gridAt(grid, cc, cr) < 0) at = { c: cc, r: cr, s: sz };
        var bySmall = d.sizes.slice(0).sort(function (a, b) { return a[0] * a[1] - b[0] * b[1]; });
        for (i = 0; !at && i < bySmall.length; i++)
            for (rr = 0; !at && rr + bySmall[i][1] <= Settings.GRID_ROWS; rr++)
                for (c = 0; !at && c + bySmall[i][0] <= Settings.GRID_COLS; c++)
                    if (Settings.gridFits(grid, c, rr, bySmall[i][0], bySmall[i][1], -1)) at = { c: c, r: rr, s: bySmall[i] };
        if (at) {
            g.push({ w: d.id, c: at.c, r: at.r, cw: at.s[0], rh: at.s[1] });
            cc = at.c; cr = at.r;
            commit(g, d.name + " agregado.");
        } else {
            var s0 = bySmall[0];
            g.push({ w: d.id, c: Math.min(cc, Settings.GRID_COLS - s0[0]), r: Math.min(cr, Settings.GRID_ROWS - s0[1]), cw: s0[0], rh: s0[1] });
            var res = Settings.gridRelayout(g, g.length - 1);
            cc = res.grid[res.fixed].c; cr = res.grid[res.fixed].r;
            commit(res.grid, d.name + " agregado; los demás se acomodaron." + droppedMsg(res.dropped));
        }
        ed.forceActiveFocus();
    }
    // Cambiar el tamaño: si se sale de la cuadrícula se corre hacia adentro, y los demás se acomodan alrededor
    function resize(sz) {
        if (selIdx < 0) return;
        var g = copyGrid(), it = g[selIdx];
        it.cw = sz[0]; it.rh = sz[1];
        it.c = Math.min(it.c, Settings.GRID_COLS - it.cw); it.r = Math.min(it.r, Settings.GRID_ROWS - it.rh);
        var res = Settings.gridRelayout(g, selIdx);
        var me = res.grid[res.fixed];
        cc = me.c; cr = me.r;
        commit(res.grid, "Guardado." + droppedMsg(res.dropped));
    }
    function removeSel() {
        if (selIdx < 0) return;
        var g = copyGrid(), name = selDef ? selDef.name : "";
        g.splice(selIdx, 1);
        commit(g, name + " quitado.");
        ed.forceActiveFocus();
    }
    function startMove() {
        if (selIdx < 0) return;
        cc = selItem.c; cr = selItem.r;
        moveBase = copyGrid();
        moveIdx = selIdx;
        moving = true;
        status = "Flechas: mover  ·  OK: dejarlo ahí  ·  ATRÁS: cancelar"; statusColor = "#9aa3b5";
        ed.forceActiveFocus();
    }
    // Cada paso parte de cómo estaba todo al empezar: los demás vuelven a su lugar si dejás de pisarlos
    property var moveDropped: []
    function moveBy(dx, dy) {
        var me = moveBase[moveIdx];
        var nc = Math.max(0, Math.min(Settings.GRID_COLS - me.cw, cc + dx));
        var nr = Math.max(0, Math.min(Settings.GRID_ROWS - me.rh, cr + dy));
        if (nc === cc && nr === cr) return;
        var g = JSON.parse(JSON.stringify(moveBase));
        g[moveIdx].c = nc; g[moveIdx].r = nr;
        var res = Settings.gridRelayout(g, moveIdx);
        grid = res.grid;
        moveDropped = res.dropped;
        cc = nc; cr = nr;
        status = "Flechas: mover  ·  OK: dejarlo ahí  ·  ATRÁS: cancelar" + droppedMsg(res.dropped);
    }
    function endMove(keep) {
        moving = false;
        if (keep) commit(grid, "Guardado." + droppedMsg(moveDropped));
        else if (moveBase) {
            grid = moveBase;
            cc = moveBase[moveIdx].c; cr = moveBase[moveIdx].r;
            status = "";
        }
        moveDropped = [];
    }

    // ---------- Teclas ----------
    // Botones de abajo visibles, en orden (para ◀ ▶)
    function actions() {
        var out = [], i;
        if (selIdx >= 0 && !adding) {
            for (i = 0; i < sizeRep.count; i++) out.push(sizeRep.itemAt(i));
            out.push(moveBtn); out.push(removeBtn);
        } else {
            for (i = 0; i < addRep.count; i++) out.push(addRep.itemAt(i));
            if (adding) out.push(addCancelBtn);
        }
        return out.filter(function (b) { return b && b.enabled; });
    }
    function focusActions() { var a = actions(); if (a.length) a[0].forceActiveFocus(); }
    function inActions() { var a = actions(); for (var i = 0; i < a.length; i++) if (a[i].activeFocus) return i; return -1; }

    Keys.onPressed: {
        var k = event.key;
        if (isOk(k)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; return; }
        if (isBack(k)) { event.accepted = moving || inActions() >= 0 || addBtn.activeFocus; return; }
        var dx = k === Qt.Key_Left ? -1 : k === Qt.Key_Right ? 1 : 0, dy = k === Qt.Key_Up ? -1 : k === Qt.Key_Down ? 1 : 0;
        if (!dx && !dy) return;
        event.accepted = true;
        if (moving) { moveBy(dx, dy); return; }
        if (addBtn.activeFocus) { if (dy > 0) ed.forceActiveFocus(); return; }   // botón "Agregar widget" (arriba)
        if (dy < 0 && cr === 0 && inActions() < 0) { addBtn.forceActiveFocus(); return; }
        var ai = inActions();
        if (ai >= 0) {                                    // en los botones de abajo
            var a = actions();
            if (dy < 0) { adding = false; ed.forceActiveFocus(); }
            else if (dx) a[Math.max(0, Math.min(a.length - 1, ai + dx))].forceActiveFocus();
            return;
        }
        if (dy > 0 && cr === Settings.GRID_ROWS - 1) { focusActions(); return; }
        // dentro de un widget grande, saltar hasta su borde para no quedar "dando vueltas" adentro
        var nc = cc + dx, nr = cr + dy;
        if (selItem && Settings.gridAt(grid, nc, nr) === selIdx) {
            if (dx > 0) nc = selItem.c + selItem.cw; if (dx < 0) nc = selItem.c - 1;
            if (dy > 0) nr = selItem.r + selItem.rh; if (dy < 0) nr = selItem.r - 1;
        }
        if (nr >= Settings.GRID_ROWS) { focusActions(); return; }
        cc = Math.max(0, Math.min(Settings.GRID_COLS - 1, nc));
        cr = Math.max(0, Math.min(Settings.GRID_ROWS - 1, nr));
    }
    Keys.onReleased: {
        var k = event.key;
        if (isBack(k)) {
            if (moving) { endMove(false); event.accepted = true; }
            else if (inActions() >= 0 || addBtn.activeFocus) { adding = false; ed.forceActiveFocus(); event.accepted = true; }
            return;                                         // si no, lo toma Configuración (vuelve al menú)
        }
        if (isOk(k)) {
            event.accepted = true;
            if (okDown && !event.isAutoRepeat) { if (moving) endMove(true); else focusActions(); }
            okDown = false;
        }
    }
    onActiveFocusChanged: if (!activeFocus) okDown = false

    // ---------- Pantalla ----------
    Item {
        id: hint
        width: parent.width; height: addBtn.height
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - addBtn.width - r(24); wrapMode: Text.Wrap
            text: "Elegí una casilla. OK en un widget: tamaño, mover o quitar. Los demás se acomodan solos."
            color: "#9aa3b5"; font.family: ed.fBody; font.pixelSize: r(26)
        }
        CButton {
            id: addBtn
            anchors.right: parent.right
            s: ed.s; family: ed.fBody; text: "+  Agregar widget"; primary: true
            onClicked: { ed.adding = true; ed.focusActions(); if (ed.inActions() < 0) ed.forceActiveFocus(); }
        }
    }

    // La cuadrícula, con la misma forma que la zona de widgets del inicio (1792 × 694)
    Item {
        id: board
        y: hint.height + r(18)
        // a lo sumo 430 de alto, para que abajo entren las opciones (en dos renglones si hace falta)
        width: Math.min(parent.width, r(430) * 1792 / 694); height: width * 694 / 1792
        anchors.horizontalCenter: parent.horizontalCenter
        property real k: width / 1792
        property real gap: 20 * k
        property real cw: (width - 3 * gap) / 4
        property real ch: (height - 3 * gap) / 4

        // casillas
        Repeater {
            model: Settings.GRID_COLS * Settings.GRID_ROWS
            delegate: Rectangle {
                property int c: index % Settings.GRID_COLS
                property int rr: Math.floor(index / Settings.GRID_COLS)
                property bool cur: ed.selIdx < 0 && ed.cc === c && ed.cr === rr
                x: c * (board.cw + board.gap); y: rr * (board.ch + board.gap)
                width: board.cw; height: board.ch; radius: r(12)
                color: Qt.rgba(1, 1, 1, cur ? 0.10 : 0.03)
                border.width: cur && ed.activeFocus ? r(4) : 1
                border.color: cur && ed.activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.14)
                Text { anchors.centerIn: parent; text: "+"; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: r(40) }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: { if (!ed.moving) { ed.cc = parent.c; ed.cr = parent.rr; ed.forceActiveFocus(); } }
                    onClicked: { if (!ed.moving) { ed.cc = parent.c; ed.cr = parent.rr; ed.focusActions(); } }
                }
            }
        }
        // widgets
        Repeater {
            model: ed.grid
            delegate: Rectangle {
                property var g: modelData
                property bool cur: ed.selIdx === index
                property color tc: ed.tint[g.w] || "#9aa3b5"
                x: g.c * (board.cw + board.gap); y: g.r * (board.ch + board.gap)
                width: g.cw * board.cw + (g.cw - 1) * board.gap; height: g.rh * board.ch + (g.rh - 1) * board.gap
                radius: r(14)
                color: Qt.rgba(tc.r, tc.g, tc.b, cur ? 0.40 : 0.24)
                border.width: cur ? r(5) : r(2)
                border.color: cur ? "#ffffff" : Qt.rgba(tc.r, tc.g, tc.b, 0.8)
                Column {
                    anchors.centerIn: parent
                    spacing: r(4)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Settings.homeWidget(g.w) ? Settings.homeWidget(g.w).name : g.w
                        color: "#eef1f6"; font.family: ed.fDisplay; font.pixelSize: r(34); font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (ed.moving && parent.parent.cur ? "moviendo  ·  " : "") + g.cw + " × " + g.rh
                        color: "#eef1f6"; opacity: 0.8; font.family: ed.fBody; font.pixelSize: r(24)
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: { if (!ed.moving) { ed.cc = parent.g.c; ed.cr = parent.g.r; ed.forceActiveFocus(); } }
                    onClicked: { if (!ed.moving) { ed.cc = parent.g.c; ed.cr = parent.g.r; ed.focusActions(); } }
                }
            }
        }
    }

    // ---------- Abajo: lo que se puede hacer con la casilla elegida ----------
    Flow {
        id: bar
        visible: !ed.moving
        y: board.y + board.height + r(22)
        width: parent.width
        spacing: r(14)
        Text {
            height: r(72); verticalAlignment: Text.AlignVCenter
            text: ed.selDef && !ed.adding ? ed.selDef.name + ":"
                : (ed.missing.length ? "Agregar:" : "Ya están todos los widgets que hay por ahora. Elegí uno para cambiarlo.")
            color: "#eef1f6"; font.family: ed.fBody; font.pixelSize: r(30); font.weight: Font.DemiBold
        }
        Repeater {
            id: sizeRep
            model: ed.selDef && !ed.adding ? ed.selDef.sizes : []
            delegate: CButton {
                s: ed.s; family: ed.fBody
                text: modelData[0] + "×" + modelData[1]
                checked: !!ed.selItem && ed.selItem.cw === modelData[0] && ed.selItem.rh === modelData[1]
                onClicked: ed.resize(modelData)
            }
        }
        CButton { id: moveBtn; visible: ed.selIdx >= 0 && !ed.adding; s: ed.s; family: ed.fBody; text: "Mover"; onClicked: ed.startMove() }
        CButton { id: removeBtn; visible: ed.selIdx >= 0 && !ed.adding; s: ed.s; family: ed.fBody; text: "Quitar"; onClicked: ed.removeSel() }
        Repeater {
            id: addRep
            model: ed.selIdx < 0 || ed.adding ? ed.missing : []
            delegate: CButton {
                s: ed.s; family: ed.fBody
                text: "+ " + modelData.name
                onClicked: ed.addWidget(modelData)
            }
        }
        CButton { id: addCancelBtn; visible: ed.adding; s: ed.s; family: ed.fBody; text: "Cancelar"; onClicked: { ed.adding = false; ed.forceActiveFocus(); } }
    }
    Text {
        y: bar.y + (ed.moving ? 0 : bar.height + r(14))
        width: parent.width; wrapMode: Text.Wrap
        text: ed.status
        color: ed.statusColor; font.family: ed.fBody; font.pixelSize: r(28)
    }
}
