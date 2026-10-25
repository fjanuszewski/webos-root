// CleanDrawer.qml — cajón de apps a pantalla completa (como en los celulares).
// Lo carga MainView.qml con un Loader y lo abre con ▼ desde la fila de apps.
// Usa el mismo modelo de apps del Home de LG (interfaces.launchPoints.launchPointsModel) y su
// misma función para abrirlas (doLaunch), así no duplica datos ni memoria.
// ▲ en la primera fila o ATRÁS lo cierra.
// "Modo elegir" (openPick): lo usa Configuración → Control remoto para elegir qué app abre un botón. Arriba dice
// para qué se elige; tocar una app la devuelve (pickCb(entrada)) en vez de abrirla; ATRÁS devuelve null. Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import "settings.js" as Settings

FocusScope {
    id: drawer

    // Color del borde de la app elegida (tema → "Selección"); se relee cuando Configuración guarda
    property color accent: "#ffffff"
    function loadAccent() { Settings.load(function (st) { drawer.accent = st.theme && st.theme.accent ? st.theme.accent : "#ffffff"; }); }
    Component.onCompleted: loadAccent()
    Connections {
        target: uiController.mainView
        ignoreUnknownSignals: true
        onCleanRevChanged: drawer.loadAccent()
    }

    property bool opened: false
    signal closeRequested()
    property var currentEntry: (grid.currentItem && opened) ? grid.currentItem.e : null

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real s: width / 1920
    function r(v) { return v * s; }
    readonly property int cols: 5

    enabled: opened
    visible: opacity > 0.01
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    property real slide: opened ? 0 : r(140)
    Behavior on slide { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    FontLoader { id: fDispB; source: drawer.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fUi; source: drawer.base + "fonts/InstrumentSans-Regular.ttf" }
    property string fDisplay: fDispB.status === FontLoader.Ready ? fDispB.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    // "modo elegir"
    property bool picking: false
    property string pickTitle: ""
    property var pickCb: null
    function openPick(title, cb) {
        pickTitle = title;
        pickCb = cb;
        picking = true;
        open();
    }
    function open() {
        opened = true;
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
        grid.forceActiveFocus();
    }
    function close() { finish(null); }
    function finish(picked) {
        if (!opened) return;
        var cb = picking ? pickCb : null;
        picking = false;
        pickCb = null;
        opened = false;
        closeRequested();
        if (cb) cb(picked);         // después de closeRequested, para que el foco quede en quien eligió
    }
    // Al salir del Home (abrir una app) o volver, el cajón arranca cerrado: HOME muestra el Home, no el cajón
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: drawer.close()
    }
    function iconUrl(e) {
        if (!e) return "";
        var p = e.mediumLargeIcon || e.largeIcon || e.icon || "";
        if (!p) return "";
        return p.indexOf("/") === 0 ? "file://" + p : p;
    }
    // Opciones de la app (Abrir · Eliminar). Al cerrar, el foco vuelve a la grilla (el cajón queda abierto).
    function showMenu(i) {
        if (picking) return;
        var it = interfaces.launchPoints.launchPointsModel.get(i);
        var m = uiController.mainView ? uiController.mainView.cleanAppMenu : null;
        if (m && m.item && it && it.entry) m.item.open(it.entry, false, grid);
    }
    function launchAt(i) {
        var it = interfaces.launchPoints.launchPointsModel.get(i);
        if (picking) { finish(it ? it.entry : null); return; }
        if (it && it.entry) interfaces.launchPoints.doLaunch(it.entry);
        close();
    }

    // Fondo: tapa los widgets mientras el cajón está abierto
    Rectangle { anchors.fill: parent; color: Qt.rgba(11 / 255, 13 / 255, 18 / 255, 0.97) }
    // Tapa el puntero del control: que no seleccione lo que queda debajo (fila de recientes)
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    Text {
        id: title
        x: r(64); y: r(46) + drawer.slide
        text: drawer.picking ? drawer.pickTitle : "Apps"
        color: "#eef1f6"
        font.family: drawer.fDisplay; font.pixelSize: r(60); font.weight: Font.Bold
    }
    Text {
        anchors.left: title.right; anchors.leftMargin: r(20); anchors.baseline: title.baseline
        visible: !drawer.picking
        text: grid.count + " apps"
        color: "#5d6576"; font.family: drawer.fBody; font.pixelSize: r(24)
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: r(64); anchors.baseline: title.baseline
        text: drawer.picking ? "OK elegir  ·  ATRÁS para cancelar" : "OK abrir  ·  ▲ en la primera fila o ATRÁS para volver"
        color: "#5d6576"; font.family: drawer.fBody; font.pixelSize: r(22)
    }

    GridView {
        id: grid
        x: r(46); y: r(150) + drawer.slide
        width: parent.width - r(92); height: parent.height - r(160)
        cellWidth: width / drawer.cols
        cellHeight: r(276)
        clip: true
        focus: true
        keyNavigationWraps: false
        highlightRangeMode: GridView.ApplyRange
        preferredHighlightBegin: r(30)
        preferredHighlightEnd: height - r(60)
        highlightMoveDuration: 180
        model: interfaces.launchPoints.launchPointsModel

        delegate: Item {
            width: grid.cellWidth; height: grid.cellHeight
            property var e: entry
            property bool sel: GridView.isCurrentItem && drawer.opened

            // Puntero del control (Magic Remote): pasar por encima selecciona, click abre
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { grid.currentIndex = index; grid.forceActiveFocus(); }
                onClicked: { grid.currentIndex = index; drawer.launchAt(index); }
                onPressAndHold: { grid.currentIndex = index; drawer.showMenu(index); }   // click largo: opciones
            }

            Rectangle {
                id: tile
                anchors.horizontalCenter: parent.horizontalCenter
                y: r(16)
                width: parent.width - r(30); height: width * 0.62
                radius: r(18)
                color: (e && e.iconColor) ? e.iconColor : Qt.rgba(1, 1, 1, 0.08)
                scale: sel ? 1.1 : 1
                Behavior on scale { NumberAnimation { duration: 140 } }
                border.width: sel ? r(4) : 0
                border.color: drawer.accent
                Image {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.86; height: width
                    fillMode: Image.PreserveAspectFit
                    smooth: true; asynchronous: true
                    source: drawer.iconUrl(e)
                }
            }
            Text {
                anchors.top: tile.bottom; anchors.topMargin: r(14)
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - r(20)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: e ? e.title : ""
                color: sel ? "#eef1f6" : "#9aa3b5"
                font.family: drawer.fBody; font.pixelSize: r(26)
            }
        }

        // Antes de que el GridView mueva el foco: en la primera fila, ▲ cierra el cajón
        Keys.onUpPressed: {
            if (currentIndex < drawer.cols) drawer.close();
            else event.accepted = false;
        }
        // Ruedita del control: como las flechas (una fila por "clic" de la rueda); arriba desde la primera fila cierra.
        // Va encima de la grilla pero no toma clicks ni el pasar por encima (eso sigue en cada app).
        MouseArea {
            anchors.fill: parent; z: 10
            acceptedButtons: Qt.NoButton
            onWheel: {
                var d = wheel.angleDelta.y;
                if (d < 0) grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + drawer.cols);
                else if (d > 0) {
                    if (grid.currentIndex < drawer.cols) drawer.close();
                    else grid.currentIndex = grid.currentIndex - drawer.cols;
                }
                wheel.accepted = true;
            }
        }

        // OK y ATRÁS actúan al SOLTAR (como el Home de LG) y se aceptan las dos mitades del evento:
        //  - OK al apretar dejaba que, al soltar, la fila nativa de LG (oculta) abriera otra app.
        //  - ATRÁS al soltar lo toma el Home de LG y se cerraría entero.
        //  - OK sostenido 0,7 s: en vez de abrir, muestra las opciones de la app (CleanAppMenu).
        property bool okDown: false
        Timer { id: hold; interval: 700; onTriggered: { grid.okDown = false; drawer.showMenu(grid.currentIndex); } }
        Keys.onPressed: {
            if (event.key === WebOS.Key_webOS_Back || event.key === Qt.Key_Escape || event.key === Qt.Key_Back) event.accepted = true;
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                if (!event.isAutoRepeat) { okDown = true; hold.restart(); }
                event.accepted = true;
            }
        }
        Keys.onReleased: {
            if (event.key === WebOS.Key_webOS_Back || event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                drawer.close();
                event.accepted = true;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                event.accepted = true;
                if (event.isAutoRepeat) return;
                hold.stop();
                if (okDown) drawer.launchAt(currentIndex);
                okDown = false;
            }
        }
        onActiveFocusChanged: if (!activeFocus) { okDown = false; hold.stop(); }
    }
}
