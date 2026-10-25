// SaverEditBar.qml — "✎ Editar protector" sobre el protector de las entradas (HDMI sin señal, etc.).
// La crea el PhotoSlide.qml modificado de la app de entradas de LG (com.webos.app.inputcommon) como hija de la
// pantalla de LG (mainViewRoot) con z 50, por encima de su zona del puntero. Hace lo mismo que el botón "Editar" del protector en el inicio (CleanDetail.qml), pero ahí mismo:
//   - mover el puntero (o la ruedita, o una tecla: eso lo avisa el Screensaver.qml modificado con poke()) muestra
//     arriba "OK: editar · ✎ Editar protector"; se esconde a los 5 s.
//   - OK (lo avisa Screensaver.qml con okPressed()) o click en el botón abre SaverEditor.qml encima del protector.
//   - al guardar, pide recrear el protector (reloadSaver) para que tome los ajustes nuevos.
// Por qué una capa aparte: las partes de LG (Screensaver.qml z -1, PhotoSlide.qml z -9) quedan por debajo de la zona
// del puntero de LG (MouseAreaProxy, z 0) y no se enteran ni del movimiento ni de los clicks; esta queda por encima. La zona de "mover el puntero" no acepta clicks
// (acceptedButtons: NoButton), así que los clicks fuera del botón siguen llegando a LG. Qt 5.6.
import QtQuick 2.6

FocusScope {
    id: bar
    width: parent ? parent.width : 1920
    height: parent ? parent.height : 1080
    visible: active || editing

    property string base: "file:///var/lib/webosbrew/cleanhome/"
    property real s: width / 1920
    function r(v) { return v * s; }

    property bool active: false          // el protector con fotos está a la vista
    property Item saver: null            // el CleanSaver que se está viendo
    property Item focusBack: null        // a quién devolverle el foco al terminar (la pantalla de LG)
    property bool barShown: false
    property bool editing: false
    signal reloadSaver()

    FontLoader { id: fDispB; source: bar.base + "fonts/Bricolage-Bold.ttf" }
    FontLoader { id: fUi; source: bar.base + "fonts/InstrumentSans-Regular.ttf" }
    property string fTitle: fDispB.status === FontLoader.Ready ? fDispB.name : "Droid Sans"
    property string fBody: fUi.status === FontLoader.Ready ? fUi.name : "Droid Sans"

    function poke() {
        if (!active || editing) return;
        barShown = true;
        hideBar.restart();
    }
    // OK desde el control: si el botón está a la vista, abre el editor. Devuelve true si lo usó.
    function okPressed() {
        if (!active || editing || !barShown) return false;
        startEdit();
        return true;
    }
    function startEdit() {
        if (!saver || editing) return;
        console.log("[cytv] editar el protector desde las entradas");
        barShown = false;
        editing = true;
        ed.open(saver);
    }
    function endEdit(saved) {
        editing = false;
        if (focusBack) focusBack.forceActiveFocus();
        if (saved) reloadSaver();
    }
    onActiveChanged: if (!active) { barShown = false; if (editing) ed.finish(false); }

    Timer { id: hideBar; interval: 5000; onTriggered: bar.barShown = false }

    // mover el puntero muestra el botón (los clicks pasan de largo hacia LG)
    MouseArea {
        anchors.fill: parent
        enabled: bar.active && !bar.editing
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: bar.poke()
    }

    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: bar.r(200)
        visible: opacity > 0.01
        opacity: bar.barShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Rectangle {        // sombra arriba para que se lea sobre cualquier foto
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: bar.r(56)
            spacing: bar.r(18)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "OK: editar"
                color: "#eef1f6"; opacity: 0.8; font.family: bar.fBody; font.pixelSize: bar.r(26)
            }
            Rectangle {
                id: btn
                property bool hovered: false
                anchors.verticalCenter: parent.verticalCenter
                width: label.implicitWidth + bar.r(56); height: bar.r(72)
                radius: bar.r(14)
                color: hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                border.width: hovered ? bar.r(4) : 1
                border.color: hovered ? "#ffffff" : Qt.rgba(1, 1, 1, 0.14)
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: "✎  Editar protector"
                    color: "#eef1f6"; font.family: bar.fBody; font.pixelSize: bar.r(30); font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: bar.barShown
                    hoverEnabled: true
                    onEntered: { btn.hovered = true; bar.poke(); }
                    onExited: btn.hovered = false
                    onPositionChanged: bar.poke()
                    onClicked: bar.startEdit()
                }
            }
        }
    }

    SaverEditor {
        id: ed
        anchors.fill: parent
        visible: bar.editing
        enabled: bar.editing
        s: bar.s; fBody: bar.fBody; fTitle: bar.fTitle
        onDone: bar.endEdit(saved)
    }
}
