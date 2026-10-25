// CleanCalendar.qml — panel del calendario familiar (columna derecha de CleanTop). Diseño del ejemplo del usuario:
//   - arriba: tabla de 7 días desde AYER (ayer, hoy y los 5 siguientes) con los títulos de los eventos
//     (lo más largo que entre: hasta 4 renglones si hay 1 o 2 eventos, 2 si hay hasta 4, 1 si hay más) y una barrita de avance;
//   - abajo a la izquierda: lo que QUEDA de hoy (los eventos que ya terminaron no se muestran);
//   - abajo a la derecha: lo de MAÑANA (si mañana no hay nada, los próximos).
// Si el panel es bajo (menos de 4 filas de la cuadrícula de widgets) se ve solo la tabla, más alta.
// Sin título ni hora de actualización (pedido del usuario). Cada evento de la tabla muestra su hora de inicio.
// Se elige un día con ◀ ▶ (lo maneja CleanTop) o con el puntero; OK/click abre el detalle del día (CleanDetail "day").
// Datos: cal/events.json, que arma cal/sync.js (root, al prender y cada 10 min) desde el iCal público de Google.
// Qt 5.6 / QtQuick 2.6. Medidas en base 1920 escaladas con r(), como el resto de CleanTop.
import QtQuick 2.6

Panel {
    id: cal

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real fs: 1.35
    property real fs2: 1.5
    property string fBody: "Droid Sans"
    property string fDisplay: "Droid Sans"
    function r(v) { return v * s; }
    function f(v) { return v * s * fs; }
    function f2(v) { return v * s * fs * fs2; }

    readonly property color cFg: "#eef1f6"
    readonly property color cMuted: "#9aa3b5"
    readonly property color cFaint: "#5d6576"
    readonly property color cAccent: "#6fa8ff"
    property color accent: "#ffffff"           // borde del día elegido (color de selección del tema)
    property bool showLists: height >= r(600)  // "Hoy" y "Mañana" abajo solo si hay lugar
    readonly property color cLine: Qt.rgba(1, 1, 1, 0.10)
    readonly property var palette: ["#6fa8ff", "#3ddc97", "#f5b83d", "#ff8fa3", "#b18cff", "#5ad1e6", "#ff9f5a"]

    readonly property var diasC: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
    readonly property var dias: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    // Selección de día (0 = ayer, 1 = hoy … 6)
    property bool focused: false
    property int selDay: 1
    signal dayHovered(int i)
    signal dayClicked(int i)
    function dayPayload(i) {
        var d = week[i];
        if (!d) return { title: "", events: [] };
        var p = d.ymd.split("-"), dt = new Date(+p[0], +p[1] - 1, +p[2]);
        var t = dias[dt.getDay()] + " " + dt.getDate() + " de " + meses[dt.getMonth()];
        return { title: t.charAt(0).toUpperCase() + t.slice(1), isToday: d.isToday, events: d.events };
    }

    property var calData: null      // (no "data": es la propiedad de Item donde van los hijos)
    property real nowMs: Date.now()
    property var week: []           // [{ ymd, date, wd, isToday, isPast, events: [] }] de ayer a 5 días después de hoy
    property real weekStart: 0
    property var todayList: []      // lo que queda de hoy
    property int todayMore: 0
    property var nextList: []       // mañana (o los próximos si mañana no hay nada)
    property int nextMore: 0
    property string nextTitle: "Mañana"
    property bool nextIsLater: false
    property string todayYmd: ""

    // ---------- Utilidades ----------
    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function ymd(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
    function hhmm(t) { var d = new Date(t); return pad2(d.getHours()) + ":" + pad2(d.getMinutes()); }
    function colorOf(title) {
        var h = 0;
        for (var i = 0; i < title.length; i++) h = (h * 31 + title.charCodeAt(i)) & 0xffff;
        return palette[h % palette.length];
    }
    function timeRange(e) {
        if (e.allDay) return "Todo el día";
        if (!e.first) return "Sigue · hasta " + hhmm(e.end);
        return hhmm(e.start) + " – " + hhmm(e.end);
    }
    function dayLabel(dayYmd) {
        var p = dayYmd.split("-"), d = new Date(+p[0], +p[1] - 1, +p[2]);
        return diasC[d.getDay()] + " " + d.getDate();
    }

    function load() {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            var j = null;
            try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
            if (j && j.events) cal.calData = j;
            cal.rebuild();
        };
        x.open("GET", base + "cal/events.json");
        x.send();
    }

    function rebuild() {
        var now = new Date();
        nowMs = now.getTime();
        todayYmd = ymd(now);
        var first = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);   // ayer
        weekStart = first.getTime();
        var evs = calData ? calData.events : [];
        var byDay = {};
        for (var i = 0; i < evs.length; i++) (byDay[evs[i].day] = byDay[evs[i].day] || []).push(evs[i]);

        var w = [];
        for (var k = 0; k < 7; k++) {
            var d = new Date(first.getFullYear(), first.getMonth(), first.getDate() + k);
            var key = ymd(d);
            w.push({ ymd: key, date: d.getDate(), wd: d.getDay(), isToday: key === todayYmd, isPast: key < todayYmd, events: byDay[key] || [] });
        }
        week = w;

        // Hoy: solo lo que no terminó (los de todo el día quedan hasta medianoche)
        var pending = (byDay[todayYmd] || []).filter(function (e) { return e.allDay || e.end > nowMs; });
        todayList = pending.slice(0, 3);
        todayMore = pending.length - todayList.length;

        // Mañana; si no hay nada, los próximos días (con el día adelante)
        var tm = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        var tmYmd = ymd(tm), nxt = byDay[tmYmd] || [];
        nextIsLater = nxt.length === 0;
        if (nextIsLater) nxt = evs.filter(function (e) { return e.day > tmYmd && e.first; });
        nextTitle = nextIsLater ? "Próximos" : "Mañana · " + dias[tm.getDay()] + " " + tm.getDate();
        nextList = nxt.slice(0, 3);
        nextMore = nxt.length - nextList.length;
    }

    Component.onCompleted: load()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: cal.load() }

    Text {
        visible: !cal.calData
        x: r(24); y: r(70)
        text: "Cargando calendario…"
        color: cal.cFaint; font.family: cal.fBody; font.pixelSize: f(16)
    }

    // ---------- Semana: tabla de 7 días ----------
    Item {
        id: weekBox
        visible: !!cal.calData
        x: r(24); y: r(18); width: parent.width - r(48); height: cal.showLists ? r(432) : parent.height - r(54)
        property real colW: width / 7

        // Nombres de los días
        Row {
            id: heads
            width: parent.width; height: r(36)
            Repeater {
                model: cal.week
                delegate: Item {
                    width: weekBox.colW; height: heads.height
                    Text {
                        anchors.centerIn: parent
                        text: cal.diasC[modelData.wd].toUpperCase()
                        color: modelData.isToday ? cal.cAccent : (modelData.isPast ? cal.cFaint : cal.cMuted)
                        font.family: cal.fBody; font.pixelSize: f2(8.5); font.weight: Font.DemiBold
                        font.letterSpacing: 1 * s
                    }
                    Rectangle {
                        visible: modelData.isToday
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - r(16); height: r(3); radius: r(2); color: cal.cAccent
                    }
                }
            }
        }
        // Tabla
        Rectangle {
            id: grid
            y: heads.height + r(6); width: parent.width; height: parent.height - y
            radius: r(12); color: "transparent"; border.color: cal.cLine; border.width: 1
            clip: true
            Row {
                anchors.fill: parent
                Repeater {
                    model: cal.week
                    delegate: Item {
                        id: cell
                        property var d: modelData
                        property int n: d.events.length
                        // Cuantos menos eventos, más renglones para el título (que entre lo más posible)
                        property int lines: n <= 2 ? 4 : (n <= 4 ? 2 : 1)
                        property int shown: Math.min(n, lines >= 2 ? 4 : 8)
                        width: weekBox.colW; height: grid.height

                        Rectangle { anchors.fill: parent; anchors.margins: 1; color: Qt.rgba(1, 1, 1, 0.07); visible: cell.d.isToday }
                        // Día elegido (con flechas o puntero): borde blanco como las apps
                        Rectangle {
                            visible: cal.focused && cal.selDay === index
                            anchors.fill: parent; anchors.margins: r(2); z: 2
                            radius: r(10); color: "transparent"; border.width: r(4); border.color: cal.accent
                        }
                        MouseArea {
                            anchors.fill: parent; z: 3
                            hoverEnabled: true
                            onEntered: cal.dayHovered(index)
                            onClicked: cal.dayClicked(index)
                        }
                        Rectangle { visible: index > 0; width: 1; height: parent.height; color: cal.cLine }
                        Column {
                            x: r(8); y: r(6); width: parent.width - r(14)
                            spacing: r(6)
                            opacity: cell.d.isPast ? 0.45 : 1
                            Text {
                                text: cell.d.date
                                color: cell.d.isToday ? cal.cAccent : cal.cFg
                                font.family: cal.fDisplay; font.pixelSize: f(15); font.weight: Font.Bold
                            }
                            Repeater {
                                model: cell.d.events.slice(0, cell.shown)
                                delegate: Item {
                                    id: ev
                                    property var e: modelData
                                    property color c: cal.colorOf(e.title)
                                    width: parent.width; height: evCol.implicitHeight + (e.allDay ? r(6) : 0)
                                    opacity: (!e.allDay && e.end <= cal.nowMs) ? 0.5 : 1
                                    Rectangle {   // los de todo el día van como franja de color
                                        visible: ev.e.allDay
                                        anchors.fill: parent; radius: r(5)
                                        color: Qt.rgba(ev.c.r, ev.c.g, ev.c.b, 0.30)
                                    }
                                    Rectangle {
                                        visible: !ev.e.allDay
                                        width: r(3); height: parent.height - r(4); y: r(2); radius: r(2); color: ev.c
                                    }
                                    Column {
                                        id: evCol
                                        x: r(8); width: parent.width - r(10)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {   // hora de inicio (para ubicar el evento en el día)
                                            visible: !ev.e.allDay
                                            text: ev.e.first ? cal.hhmm(ev.e.start) : "sigue"
                                            color: cal.cMuted; font.family: cal.fBody; font.pixelSize: f2(7.5); font.weight: Font.DemiBold
                                        }
                                        Text {
                                            width: parent.width
                                            wrapMode: Text.Wrap; maximumLineCount: cell.lines; elide: Text.ElideRight
                                            lineHeight: 0.9
                                            text: ev.e.title
                                            color: cal.cFg; font.family: cal.fBody; font.pixelSize: f2(8.5)
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: cell.n > cell.shown
                                text: "+" + (cell.n - cell.shown) + " más"
                                color: cal.cMuted; font.family: cal.fBody; font.pixelSize: f2(8)
                            }
                        }
                    }
                }
            }
        }
    }

    // Barrita de avance: cuánto pasó de los 7 días de la tabla (como en el ejemplo)
    Rectangle {
        visible: !!cal.calData
        x: r(24); y: weekBox.y + weekBox.height + r(12); width: parent.width - r(48); height: r(6); radius: r(3)
        color: Qt.rgba(1, 1, 1, 0.08)
        Rectangle {
            height: parent.height; radius: parent.radius; color: cal.cAccent
            width: parent.width * Math.max(0, Math.min(1, (cal.nowMs - cal.weekStart) / (7 * 86400000)))
        }
    }

    // ---------- Abajo: lo que queda de hoy | mañana ----------
    Item {
        id: lists
        visible: !!cal.calData && cal.showLists
        x: r(24); y: r(488); width: parent.width - r(48); height: parent.height - y - r(16)
        property real colW: (width - r(33)) / 2

        Rectangle { x: lists.colW + r(16); width: 1; height: parent.height; color: cal.cLine }

        Repeater {
            model: 2
            delegate: Item {
                id: side
                property bool isToday: index === 0
                property var items: isToday ? cal.todayList : cal.nextList
                property int more: isToday ? cal.todayMore : cal.nextMore
                x: index === 0 ? 0 : lists.colW + r(33); width: lists.colW; height: lists.height

                Text {
                    id: sideTitle
                    width: parent.width; elide: Text.ElideRight
                    text: (side.isToday ? "Hoy" : cal.nextTitle).toUpperCase() + (side.more > 0 ? "  ·  +" + side.more : "")
                    color: side.isToday ? cal.cAccent : cal.cMuted
                    font.family: cal.fBody; font.pixelSize: 13 * s * fs; font.weight: Font.DemiBold
                    font.letterSpacing: 1 * s
                }
                Column {
                    y: sideTitle.height + r(12); width: parent.width
                    spacing: r(12)
                    Repeater {
                        model: side.items
                        delegate: Item {
                            id: evRow
                            property var e: modelData
                            property bool live: !e.allDay && e.start <= cal.nowMs && e.end > cal.nowMs
                            width: parent.width; height: col.implicitHeight
                            Rectangle { width: r(5); height: parent.height; radius: r(3); color: cal.colorOf(evRow.e.title) }
                            Column {
                                id: col
                                x: r(16); width: parent.width - r(16)
                                spacing: r(1)
                                Row {
                                    spacing: r(8)
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (!side.isToday && cal.nextIsLater ? cal.dayLabel(evRow.e.day) + " · " : "") + cal.timeRange(evRow.e)
                                        color: cal.cMuted; font.family: cal.fBody; font.pixelSize: f2(9)
                                    }
                                    Rectangle {
                                        visible: evRow.live
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: ahora.implicitWidth + r(14); height: r(26); radius: height / 2
                                        color: Qt.rgba(61 / 255, 220 / 255, 151 / 255, 0.18)
                                        Text {
                                            id: ahora
                                            anchors.centerIn: parent
                                            text: "AHORA"
                                            color: "#3ddc97"; font.family: cal.fBody; font.pixelSize: f(11); font.weight: Font.Bold
                                        }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                                    lineHeight: 0.95
                                    text: evRow.e.title
                                    color: cal.cFg; font.family: cal.fDisplay; font.pixelSize: f(17); font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: side.items.length === 0
                    y: sideTitle.height + r(14); width: parent.width
                    wrapMode: Text.Wrap
                    text: side.isToday ? "No queda nada por hoy" : "Sin eventos próximos"
                    color: cal.cFaint; font.family: cal.fBody; font.pixelSize: f2(10)
                }
            }
        }
    }
}
