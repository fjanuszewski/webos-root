// CleanAppMenu.qml — opciones de una app al mantenerla apretada (OK sostenido o click largo con el puntero),
// en la fila de recientes (CleanRecents) y en la lista completa (CleanDrawer).
// Opciones: Abrir · Asignar a un botón (Configuración → Control remoto en "modo elegir": el próximo botón del control
// que se toque pasa a abrir esta app) · Quitar de recientes (solo desde la fila de recientes) · Eliminar (solo si la app se puede
// desinstalar; pide confirmación) · Cancelar. Eliminar usa lo mismo que el modo de edición de LG:
// uiController.removeLaunchPoint({ launchPointId }) → com.webos.applicationManager/removeLaunchPoint.
// Lo carga MainView.qml (z 1004) y se abre con open(entrada, desdeRecientes, ítemQueRecuperaElFoco).
// ▲ ▼ eligen, OK al SOLTAR (como el Home de LG), ATRÁS cancela. Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0

FocusScope {
    id: menu

    property bool opened: false
    signal closeRequested()

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real s: width / 1920
    function r(v) { return v * s; }

    property var entry: null
    property bool fromRecents: false
    property Item returnTo: null
    property bool confirming: false

    enabled: opened
    visible: opacity > 0.01
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    FontLoader { id: fDispB; source: menu.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fUi; source: menu.base + "fonts/InstrumentSans-Regular.ttf" }
    property string fTitle: fDispB.status === FontLoader.Ready ? fDispB.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    function iconUrl(e) {
        if (!e) return "";
        var p = e.mediumLargeIcon || e.largeIcon || e.icon || "";
        if (!p) return "";
        return p.indexOf("/") === 0 ? "file://" + p : p;
    }
    function isBack(k) { return k === WebOS.Key_webOS_Back || k === Qt.Key_Escape || k === Qt.Key_Back; }

    function open(e, recents, focusItem) {
        if (!e) return;
        entry = e;
        fromRecents = !!recents;
        returnTo = focusItem || null;
        confirming = false;
        opened = true;
        openBtn.forceActiveFocus();
    }
    function close() {
        if (!opened) return;
        opened = false;
        confirming = false;
        if (returnTo) returnTo.forceActiveFocus();
        closeRequested();
    }
    function doAssign() {
        var e = entry, rt = returnTo;
        close();
        var mv = uiController.mainView;
        var cs = mv && mv.cleanSettings ? mv.cleanSettings.item : null;
        if (cs && e) cs.openCapture(e, rt);
    }
    function doOpen() {
        var e = entry;
        close();
        if (e) interfaces.launchPoints.doLaunch(e);
    }
    function doRemoveRecent() {
        if (entry) interfaces.launchPoints.removeRecent(entry.id);
        close();
    }
    function askRemove() {
        confirming = true;
        noBtn.forceActiveFocus();          // por las dudas, el foco arranca en "No"
    }
    function doRemove() {
        if (entry) {
            console.warn("[CleanAppMenu] eliminar " + entry.id);
            uiController.removeLaunchPoint({ "launchPointId": entry.launchPointId || entry.id });
        }
        close();
    }

    // Botones visibles, en orden, para moverse con ▲ ▼
    function buttons() {
        if (confirming) return [yesBtn, noBtn];
        var b = [openBtn, assignBtn];
        if (fromRecents) b.push(recentBtn);
        if (entry && entry.removable) b.push(removeBtn);
        b.push(cancelBtn);
        return b;
    }
    function move(d) {
        var b = buttons(), i = 0;
        for (var k = 0; k < b.length; k++) if (b[k].activeFocus) { i = k; break; }
        i = Math.max(0, Math.min(b.length - 1, i + d));
        b[i].forceActiveFocus();
    }
    Keys.onPressed: {
        event.accepted = true;               // nada se escapa a la pantalla de abajo
        if (event.key === Qt.Key_Up || (confirming && event.key === Qt.Key_Left)) move(-1);
        else if (event.key === Qt.Key_Down || (confirming && event.key === Qt.Key_Right)) move(1);
    }
    Keys.onReleased: {
        event.accepted = true;
        if (isBack(event.key)) { if (confirming) { confirming = false; removeBtn.forceActiveFocus(); } else close(); }
    }
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: menu.close()
    }

    // ---------- Pantalla ----------
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.6) }
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onClicked: menu.close() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: r(760); height: col.height + r(72)
        radius: r(28)
        color: "#161a22"
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)
        MouseArea { anchors.fill: parent; hoverEnabled: true }     // tocar la tarjeta no cierra

        Column {
            id: col
            x: r(40); y: r(36); width: parent.width - r(80)
            spacing: r(18)

            Row {
                spacing: r(24)
                Rectangle {
                    width: r(132); height: r(82); radius: r(14)
                    color: menu.entry && menu.entry.iconColor ? menu.entry.iconColor : Qt.rgba(1, 1, 1, 0.08)
                    Image {
                        anchors.centerIn: parent
                        width: r(74); height: r(74); fillMode: Image.PreserveAspectFit; smooth: true
                        source: menu.iconUrl(menu.entry)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: col.width - r(156); elide: Text.ElideRight
                    text: menu.entry ? menu.entry.title : ""
                    color: "#eef1f6"; font.family: menu.fTitle; font.pixelSize: r(46); font.weight: Font.Bold
                }
            }
            Item { width: 1; height: r(4) }

            // ----- Opciones -----
            CButton { id: openBtn; visible: !menu.confirming; width: col.width; s: menu.s; family: menu.fBody; text: "Abrir"; primary: true; onClicked: menu.doOpen() }
            CButton { id: assignBtn; visible: !menu.confirming; width: col.width; s: menu.s; family: menu.fBody; text: "Asignar a un botón"; onClicked: menu.doAssign() }
            CButton { id: recentBtn; visible: !menu.confirming && menu.fromRecents; width: col.width; s: menu.s; family: menu.fBody; text: "Quitar de recientes"; onClicked: menu.doRemoveRecent() }
            CButton { id: removeBtn; visible: !menu.confirming && !!menu.entry && !!menu.entry.removable; width: col.width; s: menu.s; family: menu.fBody; text: "Eliminar de la tele"; onClicked: menu.askRemove() }
            Text {
                visible: !menu.confirming && !!menu.entry && !menu.entry.removable
                width: col.width; wrapMode: Text.Wrap
                text: "Esta app viene con la tele y no se puede eliminar."
                color: "#7a8396"; font.family: menu.fBody; font.pixelSize: r(26)
            }
            CButton { id: cancelBtn; visible: !menu.confirming; width: col.width; s: menu.s; family: menu.fBody; text: "Cancelar"; onClicked: menu.close() }

            // ----- Confirmar eliminar -----
            Text {
                visible: menu.confirming
                width: col.width; wrapMode: Text.Wrap
                text: "¿Eliminar " + (menu.entry ? menu.entry.title : "") + " de la tele?\nSe puede volver a bajar desde la tienda de apps de LG."
                color: "#eef1f6"; font.family: menu.fBody; font.pixelSize: r(32)
            }
            Row {
                visible: menu.confirming
                spacing: r(20)
                CButton { id: yesBtn; s: menu.s; family: menu.fBody; text: "Sí, eliminar"; onClicked: menu.doRemove() }
                CButton { id: noBtn; s: menu.s; family: menu.fBody; text: "No"; primary: true; onClicked: { menu.confirming = false; removeBtn.forceActiveFocus(); } }
            }
        }
    }
}
