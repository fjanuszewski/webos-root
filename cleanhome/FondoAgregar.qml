// FondoAgregar.qml — Configuración → Tema → "Agregar foto": sumar una foto de fondo desde el pendrive, desde la
// memoria de la tele (lo bajado con el navegador), desde un enlace de internet o por Bluetooth (si la tele lo permite).
//   1) Cuatro tarjetas para elegir de dónde. 2) Pendrive / tele: grilla con las fotos encontradas (las 40 más nuevas).
//   Enlace: campo para escribir la dirección. Bluetooth: se pregunta a la tele si puede recibir archivos (opp/getStatus);
//   la LG 50UM7360 tiene esa parte apagada de fábrica, así que solo se avisa.
// El trabajo lo hace cleanhome/fondos.sh como administrador, por luna://org.webosbrew.hbchannel.service/exec: "listar"
// contesta enseguida; "copiar" y "bajar" siguen en segundo plano y dejan el resultado en /tmp/cytv-fondo.json, que se
// lee cada medio segundo. Al terminar bien avisa con added(foto) y Tema la deja elegida.
// Flechas, OK al SOLTAR (como el Home de LG); ATRÁS lo maneja CleanSettings → ThemeEditor.back() → back(). Qt 5.6.
import QtQuick 2.6
import WebOSServices 1.0
import "settings.js" as Settings

FocusScope {
    id: ag

    property real s: 1
    property string fBody: "Droid Sans"
    property string fDisplay: "Droid Sans"
    function r(v) { return v * s; }
    signal added(string photo)

    readonly property string script: "sh /var/lib/webosbrew/cleanhome/fondos.sh "
    readonly property string stateFile: "file:///tmp/cytv-fondo.json"
    readonly property string img: Settings.BASE + "img/"

    property string step: "menu"        // menu | usb | tele | enlace | bt | trabajando
    property string from: ""            // a dónde volver si falla la copia o la descarga
    property var photos: []             // [{ p: ruta, n: nombre, k: KB }]
    property int disks: 0
    property bool searching: false
    property bool btOk: false
    property string jobId: ""
    property real jobStart: 0
    property string status: ""
    property bool statusBad: false

    property var sources: [
        { id: "usb", title: "Pendrive", sub: "Conectalo a la tele", icon: img + "usb.png", dim: false },
        { id: "tele", title: "Archivos de la tele", sub: "Lo que bajaste con el navegador", icon: img + "folder.png", dim: false },
        { id: "enlace", title: "Enlace", sub: "Una foto de internet", icon: img + "link.png", dim: false },
        { id: "bt", title: "Bluetooth", sub: btOk ? "Desde el celular" : "Esta tele no lo permite", icon: img + "bluetooth.png", dim: !btOk }
    ]

    function isOk(k) { return k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Select; }
    function say(t, bad) { status = t; statusBad = !!bad; }
    // entre comillas simples para el intérprete de comandos (el enlace lo escribe la persona)
    function q(t) { return "'" + String(t).split("'").join("'\\''") + "'"; }

    function open() {
        step = "menu";
        say("¿De dónde sacamos la foto?", false);
        photos = [];
        srcGrid.currentIndex = 0;
        srcGrid.forceActiveFocus();
        btSvc.callService({});
    }
    // ATRÁS: true si lo usó acá (vuelve a las tarjetas); false = ya estaba en las tarjetas (Tema cierra esto)
    function back() {
        if (step === "menu") return false;
        if (step === "trabajando") return true;          // no se deja a mitad de camino: termina solo
        Qt.inputMethod.hide();
        open();
        return true;
    }
    function choose(id) {
        if (id === "usb" || id === "tele") { step = id; search(); return; }
        if (id === "enlace") {
            step = "enlace";
            say("Escribí la dirección de la foto (tiene que terminar en .jpg o .png, o ser una foto que se abre sola)", false);
            urlField.text = "";
            urlField.forceActiveFocus();
            return;
        }
        step = "bt";
        say(btOk ? "Esta opción todavía no está lista en la pantalla de inicio."
                 : "Esta tele no puede recibir fotos por Bluetooth: LG dejó apagada esa parte. Usá el pendrive o un enlace.", !btOk);
        btBack.forceActiveFocus();
    }

    // ---------- Buscar fotos (pendrive / tele) ----------
    function search() {
        searching = true;
        photos = [];
        disks = 0;
        say(step === "usb" ? "Buscando fotos en el pendrive…" : "Buscando fotos en la tele…", false);
        againBtn.forceActiveFocus();
        listSvc.callService({ command: script + "listar " + (step === "usb" ? "usb" : "tele") });
    }
    function gotList(resp) {
        searching = false;
        if (step !== "usb" && step !== "tele") return;
        var d = {};
        try { d = JSON.parse((resp && resp.stdoutString) || "{}"); } catch (e) { d = {}; }
        disks = d.discos || 0;
        photos = d.fotos || [];
        if (step === "usb" && !disks) say("No encuentro ningún pendrive. Conectalo a la tele, esperá unos segundos y tocá Buscar de nuevo.", true);
        else if (!photos.length) say(step === "usb" ? "El pendrive no tiene fotos JPG o PNG." : "No hay fotos en la tele. Bajá una con el navegador y tocá Buscar de nuevo.", true);
        else say("Elegí la foto que querés de fondo", false);
        if (photos.length) { photoGrid.currentIndex = 0; photoGrid.forceActiveFocus(); }
        else againBtn.forceActiveFocus();
    }
    function listFailed(t) {
        searching = false;
        console.warn("[cytv fondos] listar: " + t);
        say("No pude buscar fotos. Probá de nuevo.", true);
        againBtn.forceActiveFocus();
    }

    // ---------- Copiar / bajar (en segundo plano) ----------
    function start(kind, arg) {
        from = step;
        jobId = String(Date.now());
        jobStart = Date.now();
        step = "trabajando";
        waitFocus.forceActiveFocus();       // lo que tenía el foco se esconde; ATRÁS tiene que seguir llegando
        say(kind === "bajar" ? "Bajando la foto…" : "Copiando la foto…", false);
        workSvc.callService({ command: script + kind + " " + q(arg) + " " + jobId });
        poll.start();
    }
    function fail(t) {
        poll.stop();
        step = from;
        say(t, true);
        if (step === "enlace") urlField.forceActiveFocus();
        else if (photos.length) photoGrid.forceActiveFocus();
        else againBtn.forceActiveFocus();
    }
    function check() {
        if (Date.now() - jobStart > 150000) { fail("Tardó demasiado. Probá de nuevo."); return; }
        Settings.readText(stateFile, function (txt) {
            if (ag.step !== "trabajando") return;
            var d = null;
            try { d = JSON.parse(txt); } catch (e) { d = null; }
            if (!d || d.id !== ag.jobId || d.estado === "trabajando") return;
            if (d.estado === "listo" && d.foto) { poll.stop(); ag.step = "menu"; ag.added(d.foto); }
            else ag.fail(d.texto || "No pude agregar la foto");
        });
    }
    Timer { id: poll; interval: 600; repeat: true; onTriggered: ag.check() }
    function download() {
        var u = urlField.text.replace(/^\s+|\s+$/g, "");
        if (!/^https?:\/\/\S+$/i.test(u)) {
            if (/^[\w.-]+\.[a-z]{2,}\/\S*$/i.test(u)) u = "https://" + u;     // escribieron sin https://
            else { say("Eso no parece un enlace. Tiene que empezar con https://", true); urlField.forceActiveFocus(); return; }
        }
        start("bajar", u);
    }

    // ---------- Servicios ----------
    Service {
        id: listSvc
        appId: "com.webos.app.fullhome"; service: "org.webosbrew.hbchannel.service"; method: "exec"
        onCallSuccess: ag.gotList(response)
        onCallFailure: ag.listFailed(JSON.stringify(response))
        onError: ag.listFailed(errorText)
    }
    Service {
        id: workSvc
        appId: "com.webos.app.fullhome"; service: "org.webosbrew.hbchannel.service"; method: "exec"
        onCallFailure: ag.fail("No pude empezar. Probá de nuevo.")
        onError: { console.warn("[cytv fondos] " + errorText); ag.fail("No pude empezar. Probá de nuevo."); }
    }
    Service {      // ¿la tele puede recibir archivos por Bluetooth? (perfil OPP)
        id: btSvc
        appId: "com.webos.app.fullhome"; service: "com.webos.service.bluetooth2"; method: "opp/getStatus"
        onCallSuccess: ag.btOk = !!(response && response.returnValue)
        onCallFailure: ag.btOk = false
        onError: ag.btOk = false
    }

    // ---------- Pantalla ----------
    Text {
        id: statusText
        width: parent.width; wrapMode: Text.Wrap
        text: ag.status
        color: ag.statusBad ? "#f5b83d" : "#9aa3b5"; font.family: ag.fBody; font.pixelSize: r(28)
    }

    // 1) De dónde
    GridView {
        id: srcGrid
        visible: ag.step === "menu"
        y: statusText.height + r(24); width: parent.width; height: r(260)
        cellWidth: width / 4; cellHeight: r(250)
        interactive: false; focus: true
        model: ag.sources
        property bool okDown: false
        delegate: Card {
            width: srcGrid.cellWidth; height: srcGrid.cellHeight
            s: ag.s; fDisplay: ag.fDisplay; fBody: ag.fBody
            sel: GridView.isCurrentItem && srcGrid.activeFocus
            dim: modelData.dim
            icon: modelData.icon; title: modelData.title; sub: modelData.sub
            onHovered: { srcGrid.currentIndex = index; srcGrid.forceActiveFocus(); }
            onClicked: ag.choose(modelData.id)
        }
        Keys.onLeftPressed: currentIndex = Math.max(0, currentIndex - 1)
        Keys.onRightPressed: currentIndex = Math.min(count - 1, currentIndex + 1)
        Keys.onPressed: { if (ag.isOk(event.key)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
        Keys.onReleased: {
            if (ag.isOk(event.key)) { event.accepted = true; if (okDown && !event.isAutoRepeat) ag.choose(ag.sources[currentIndex].id); okDown = false; }
        }
        onActiveFocusChanged: if (!activeFocus) okDown = false
    }

    // 2a) Fotos del pendrive o de la tele
    GridView {
        id: photoGrid
        visible: ag.step === "usb" || ag.step === "tele"
        y: statusText.height + r(24); width: parent.width; height: parent.height - y - r(100)
        cellWidth: width / 5; cellHeight: r(230)
        clip: true; keyNavigationWraps: false
        highlightMoveDuration: 120
        model: ag.photos
        property bool okDown: false
        delegate: Item {
            id: tile
            property bool sel: GridView.isCurrentItem && photoGrid.activeFocus
            width: photoGrid.cellWidth; height: photoGrid.cellHeight
            Rectangle {
                id: frame
                x: ag.r(8); y: ag.r(8); width: parent.width - ag.r(16); height: width * 9 / 16
                radius: ag.r(14)
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: tile.sel ? ag.r(5) : 1
                border.color: tile.sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.14)
                Image {
                    anchors.fill: parent; anchors.margins: ag.r(4)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; smooth: true; cache: false
                    sourceSize.width: 256; sourceSize.height: 144
                    source: "file://" + modelData.p
                }
            }
            Text {
                anchors.top: frame.bottom; anchors.topMargin: ag.r(8)
                x: frame.x; width: frame.width; elide: Text.ElideMiddle
                text: modelData.n + "  ·  " + (modelData.k >= 1024 ? (modelData.k / 1024).toFixed(1) + " MB" : modelData.k + " KB")
                color: tile.sel ? "#eef1f6" : "#9aa3b5"; font.family: ag.fBody; font.pixelSize: ag.r(20)
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { photoGrid.currentIndex = index; photoGrid.forceActiveFocus(); }
                onClicked: ag.start("copiar", modelData.p)
            }
        }
        Keys.onDownPressed: {
            if (currentIndex + 5 < count) moveCurrentIndexDown();
            else againBtn.forceActiveFocus();
        }
        Keys.onPressed: { if (ag.isOk(event.key)) { if (!event.isAutoRepeat) okDown = true; event.accepted = true; } }
        Keys.onReleased: {
            if (ag.isOk(event.key)) { event.accepted = true; if (okDown && !event.isAutoRepeat && ag.photos[currentIndex]) ag.start("copiar", ag.photos[currentIndex].p); okDown = false; }
        }
        onActiveFocusChanged: if (!activeFocus) okDown = false
    }
    CButton {
        id: againBtn
        visible: ag.step === "usb" || ag.step === "tele"
        anchors.bottom: parent.bottom
        s: ag.s; family: ag.fBody
        text: ag.searching ? "Buscando…" : "Buscar de nuevo"
        onClicked: if (!ag.searching) ag.search()
        Keys.onUpPressed: if (ag.photos.length) photoGrid.forceActiveFocus()
    }

    // 2b) Enlace
    Column {
        visible: ag.step === "enlace"
        y: statusText.height + r(24); width: parent.width
        spacing: r(24)
        CField {
            id: urlField
            s: ag.s; family: ag.fBody; width: parent.width
            placeholder: "https://…/foto.jpg"
            onAccepted: downloadBtn.forceActiveFocus()
            Keys.onDownPressed: downloadBtn.forceActiveFocus()
        }
        Row {
            spacing: r(20)
            CButton {
                id: downloadBtn
                s: ag.s; family: ag.fBody; text: "Bajar foto"; primary: true
                onClicked: ag.download()
                Keys.onUpPressed: urlField.forceActiveFocus()
                Keys.onRightPressed: cancelBtn.forceActiveFocus()
            }
            CButton {
                id: cancelBtn
                s: ag.s; family: ag.fBody; text: "Cancelar"
                onClicked: ag.back()
                Keys.onUpPressed: urlField.forceActiveFocus()
                Keys.onLeftPressed: downloadBtn.forceActiveFocus()
            }
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap
            text: "Tiene que ser una foto pública (que se abra sin iniciar sesión). Los álbumes de Google Fotos o Drive no sirven: abrí la foto, elegí \"Copiar dirección de la imagen\" y escribí esa."
            color: "#5d6576"; font.family: ag.fBody; font.pixelSize: r(24)
        }
    }

    // 2c) Bluetooth
    CButton {
        id: btBack
        visible: ag.step === "bt"
        y: statusText.height + r(24)
        s: ag.s; family: ag.fBody; text: "Volver"
        onClicked: ag.back()
    }

    // 3) Copiando / bajando
    Item { id: waitFocus }
    Row {
        visible: ag.step === "trabajando"
        y: statusText.height + r(40)
        spacing: r(18)
        Repeater {
            model: 3
            Rectangle {
                width: ag.r(18); height: width; radius: width / 2
                color: "#6fa8ff"
                SequentialAnimation on opacity {
                    running: ag.step === "trabajando"; loops: Animation.Infinite
                    PauseAnimation { duration: index * 200 }
                    NumberAnimation { from: 0.2; to: 1; duration: 400 }
                    NumberAnimation { from: 1; to: 0.2; duration: 400 }
                    PauseAnimation { duration: (2 - index) * 200 }
                }
            }
        }
    }
}
