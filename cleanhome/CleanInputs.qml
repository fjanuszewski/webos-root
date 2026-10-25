// CleanInputs.qml — panel de Entradas: TV/antena y los dispositivos conectados (HDMI, AV...).
// Lo carga MainView.qml y lo abre el botón "Entradas" de la barra de arriba (TopGlobalAction.qml).
// Datos del propio Home: systemProperties.externalDeviceList (suscripción a com.webos.service.eim/getAllInputStatus).
// OK cambia de entrada (abre la app de esa entrada, ej. com.webos.app.hdmi1); ATRÁS cierra. Qt 5.6.
import QtQuick 2.6
import WebOS.Global 1.0
import "botones.js" as Botones

FocusScope {
    id: inputs

    property bool opened: false
    signal closeRequested()

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real s: width / 1920
    function r(v) { return v * s; }
    readonly property int cols: 3

    enabled: opened
    visible: opacity > 0.01
    opacity: opened ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    FontLoader { id: fDispB; source: inputs.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fUi; source: inputs.base + "fonts/InstrumentSans-Regular.ttf" }
    property string fDisplay: fDispB.status === FontLoader.Ready ? fDispB.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    property var items: []

    function portName(id) {
        if (!id) return "";
        var m = /^HDMI_(\d+)/.exec(id);
        if (m) return "HDMI " + m[1];
        if (id.indexOf("COMP") === 0) return "Componente";
        if (id.indexOf("AV") === 0) return "AV";
        return id.replace("_", " ");
    }
    function rebuild() {
        var list = systemProperties.externalDeviceList || [];
        var on = [], off = [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (!d || !d.appId) continue;
            var dev = (d.subList && d.subList.length && (d.subList[0].labelName || d.subList[0].brandName)) || "";
            var small = (d.iconPrefix || "") + (d.icon || "");
            var it = {
                title: dev || d.label || portName(d.id),
                sub: portName(d.id) + " · " + (d.connected ? "Conectado" : "Sin señal"),
                appId: d.appId,
                connected: !!d.connected,
                active: !!d.activate,
                icon: small ? "file://" + small.replace("/small/", "/large/") : "",
                iconSmall: small ? "file://" + small : ""
            };
            (d.connected ? on : off).push(it);
        }
        var tv = { title: "TV", sub: "Antena / cable", appId: "com.webos.app.livetv", connected: true, active: false,
                   icon: inputs.base + "img/tv.png", iconSmall: inputs.base + "img/tv.png" };
        items = [tv].concat(on, off);
    }

    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function isBack(k) { return k === WebOS.Key_webOS_Back || k === Qt.Key_Escape || k === Qt.Key_Back; }

    function open() {
        rebuild();
        opened = true;
        grid.currentIndex = 0;
        grid.forceActiveFocus();
    }
    function close() {
        if (!opened) return;
        opened = false;
        closeRequested();
    }
    function choose(i) {
        var it = items[i];
        if (it && it.appId) interfaces.application.launchApp(it.appId, "", {});
        close();
    }

    Connections {
        target: systemProperties
        ignoreUnknownSignals: true
        onExternalDeviceListChanged: if (inputs.opened) inputs.rebuild()
    }
    Connections {
        target: uiController
        ignoreUnknownSignals: true
        onHomeShownChanged: { inputs.close(); if (uiController.homeShown) askPanel.restart(); }
    }
    // un botón del control con "Abrir un panel → Entradas" (ver botones.js → readPanel)
    Timer {
        id: askPanel; interval: 900
        onTriggered: Botones.readPanel(function (p) { if (p === "inputs") { Botones.clearPanel(); inputs.open(); } })
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(11 / 255, 13 / 255, 18 / 255, 0.97) } // casi opaco: no se trasluce el Home
    // Tapa el puntero del control: que no seleccione lo que queda debajo (fila de recientes)
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    Item {
        id: panel
        width: r(1350); height: r(640)
        anchors.centerIn: parent

        Text {
            id: title
            text: "Entradas"
            color: "#eef1f6"
            font.family: inputs.fDisplay; font.pixelSize: r(60); font.weight: Font.Bold
        }
        Text {
            anchors.right: closeBtn.left; anchors.rightMargin: r(28); anchors.verticalCenter: closeBtn.verticalCenter
            text: "OK cambiar  ·  ATRÁS cerrar"
            color: "#7a8396"; font.family: inputs.fBody; font.pixelSize: r(24)
        }

        // Botón ✕ para cerrar (como el cierre de una ventana). Se llega con ▲ desde la primera fila.
        Rectangle {
            id: closeBtn
            property bool lit: activeFocus || closeMouse.containsMouse
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            width: r(64); height: r(64); radius: width / 2
            color: lit ? "#eef1f6" : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, lit ? 0 : 0.14)
            scale: lit ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
            Repeater {
                model: [45, -45]
                Rectangle {
                    anchors.centerIn: parent
                    width: r(26); height: r(3.5); radius: height / 2
                    rotation: modelData
                    color: closeBtn.lit ? "#0b0d12" : "#eef1f6"
                }
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: inputs.close()
            }
            Keys.onDownPressed: grid.forceActiveFocus()
            Keys.onLeftPressed: grid.forceActiveFocus()
            // OK y ATRÁS actúan al SOLTAR: si se cierra al apretar, el "soltar" le llega al botón Entradas
            // de LG (que actúa al soltar) y el panel se vuelve a abrir.
            Keys.onPressed: {
                if (inputs.isOk(event.key) || inputs.isBack(event.key)) event.accepted = true;
            }
            Keys.onReleased: {
                if (inputs.isOk(event.key) || inputs.isBack(event.key)) {
                    inputs.close();
                    event.accepted = true;
                }
            }
        }

        GridView {
            id: grid
            y: r(100)
            width: parent.width; height: parent.height - r(100)
            cellWidth: width / inputs.cols
            cellHeight: r(250)
            interactive: true
            focus: true
            keyNavigationWraps: false
            model: inputs.items

            delegate: Item {
                width: grid.cellWidth; height: grid.cellHeight
                property var it: modelData
                property bool sel: GridView.isCurrentItem && inputs.opened

                // Puntero del control (Magic Remote): pasar por encima selecciona, click elige
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: { grid.currentIndex = index; grid.forceActiveFocus(); }
                    onClicked: { grid.currentIndex = index; inputs.choose(index); }
                }

                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.margins: r(14)
                    radius: r(24)
                    color: Qt.rgba(22 / 255, 26 / 255, 36 / 255, 0.98)
                    border.width: sel ? r(4) : 1
                    border.color: sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.08)
                    opacity: (it && it.connected) || sel ? 1 : 0.45
                    scale: sel ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: 140 } }

                    Image {
                        id: icon
                        x: r(28); y: r(26)
                        width: r(64); height: r(64)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: it ? it.icon : ""
                        onStatusChanged: if (status === Image.Error && it && source != it.iconSmall) source = it.iconSmall
                    }
                    Rectangle {
                        visible: !!(it && it.active)
                        anchors.right: parent.right; anchors.rightMargin: r(24); y: r(30)
                        width: badge.implicitWidth + r(20); height: r(32); radius: height / 2
                        color: Qt.rgba(61 / 255, 220 / 255, 151 / 255, 0.16)
                        Text { id: badge; anchors.centerIn: parent; text: "En uso"; color: "#3ddc97"; font.family: inputs.fBody; font.pixelSize: r(18); font.weight: Font.DemiBold }
                    }
                    Text {
                        x: r(28); anchors.bottom: sub.top; anchors.bottomMargin: r(6)
                        width: parent.width - r(56); elide: Text.ElideRight
                        text: it ? it.title : ""
                        color: "#eef1f6"; font.family: inputs.fDisplay; font.pixelSize: r(40); font.weight: Font.Bold
                    }
                    Text {
                        id: sub
                        x: r(28); anchors.bottom: parent.bottom; anchors.bottomMargin: r(26)
                        width: parent.width - r(56); elide: Text.ElideRight
                        text: it ? it.sub : ""
                        color: "#9aa3b5"; font.family: inputs.fBody; font.pixelSize: r(24)
                    }
                }
            }

            // ▲ en la primera fila: al botón ✕
            Keys.onUpPressed: {
                if (currentIndex < inputs.cols) closeBtn.forceActiveFocus();
                else event.accepted = false;
            }
            // ATRÁS: el Home de LG cierra todo al SOLTAR la tecla (UIController Keys.onReleased -> goBack),
            // así que se atrapa al apretar y se cierra el panel al soltar, aceptando el evento para que no siga.
            Keys.onPressed: {
                if (inputs.isOk(event.key) || inputs.isBack(event.key)) event.accepted = true;
            }
            Keys.onReleased: {
                if (inputs.isOk(event.key)) { inputs.choose(currentIndex); event.accepted = true; }
                else if (inputs.isBack(event.key)) { inputs.close(); event.accepted = true; }
            }
        }
    }
}
