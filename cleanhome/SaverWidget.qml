// SaverWidget.qml — una "pieza" del protector (la hora, la fecha, el clima, un evento, la fecha de la foto…).
// La usa CleanSaver.qml en cada parte de la pantalla, según settings.json → saver.layout (ver settings.js).
//   kind:  "" (nada) · clock · date · clockDate · weather · full · calNow · calNext · photoDate
//   k:     tamaño (0,7 chica · 1 mediana · 1,35 grande)
//   align: left · center · right (hacia qué borde se pega, según la parte de la pantalla)
// Los datos los toma del protector (sv). Qt 5.6.
import QtQuick 2.6

Item {
    id: w
    property Item sv: null
    property string kind: ""
    property real k: 1
    property string align: "left"
    function z(v) { return v * k * (sv ? sv.s : 1); }

    width: ld.item ? ld.item.width : 0
    height: ld.item ? ld.item.height : 0
    // "vacía" también si el dato no está (ej. no hay evento ahora): así la sombra no aparece de gusto
    readonly property bool hasContent: kind !== "" && ld.item !== null && ld.item.width > 0 && ld.item.height > 0

    readonly property color shadow: Qt.rgba(0, 0, 0, 0.35)

    Loader {
        id: ld
        sourceComponent: w.kind === "clock" ? cClock : w.kind === "date" ? cDate : w.kind === "clockDate" ? cClockDate
                       : w.kind === "weather" ? cWeather : w.kind === "full" ? cFull : w.kind === "calNow" ? cCalNow
                       : w.kind === "calNext" ? cCalNext : w.kind === "photoDate" ? cPhotoDate : null
    }

    Component {
        id: cClock
        Text {
            text: w.sv ? w.sv.clock : ""
            color: "#ffffff"; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(170)
            font.letterSpacing: -w.z(3)
            style: Text.Raised; styleColor: w.shadow
        }
    }
    Component {
        id: cDate
        Text {
            text: w.sv ? w.sv.todayText : ""
            color: "#ffffff"; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(44); font.weight: Font.DemiBold
            style: Text.Raised; styleColor: w.shadow
        }
    }
    Component {
        id: cWeatherRow
        Row {
            spacing: w.z(12)
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: w.z(58); height: w.z(58); smooth: true
                source: w.sv && w.sv.wxIconName ? w.sv.base + "img/" + w.sv.wxIconName + ".png" : ""
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: w.sv ? w.sv.wxTemp : ""
                color: "#ffffff"; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(44); font.weight: Font.DemiBold
                style: Text.Raised; styleColor: w.shadow
            }
        }
    }
    Component {
        id: cWeather
        Column {
            spacing: w.z(2)
            visible: !!w.sv && w.sv.wxTemp !== ""
            width: visible ? implicitWidth : 0; height: visible ? implicitHeight : 0
            Loader {
                sourceComponent: cWeatherRow
                anchors.right: w.align === "right" ? parent.right : undefined
                anchors.horizontalCenter: w.align === "center" ? parent.horizontalCenter : undefined
            }
            Text {
                anchors.right: w.align === "right" ? parent.right : undefined
                anchors.horizontalCenter: w.align === "center" ? parent.horizontalCenter : undefined
                text: w.sv ? w.sv.weather : ""
                color: "#ffffff"; opacity: 0.85; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(28)
                style: Text.Raised; styleColor: w.shadow
            }
        }
    }
    // Hora grande y fina; al lado la fecha de hoy (y el clima, en "full")
    Component {
        id: cClockDate
        Row {
            spacing: w.z(30)
            Loader { anchors.verticalCenter: parent.verticalCenter; sourceComponent: cClock }
            Loader { anchors.verticalCenter: parent.verticalCenter; sourceComponent: cDate }
        }
    }
    Component {
        id: cFull
        Row {
            spacing: w.z(30)
            Loader { anchors.verticalCenter: parent.verticalCenter; sourceComponent: cClock }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: w.z(6)
                Loader { sourceComponent: cDate }
                Loader { sourceComponent: cWeatherRow; visible: !!w.sv && w.sv.wxTemp !== "" }
            }
        }
    }
    // Evento del calendario: arriba cuándo, abajo el título
    Component {
        id: cEvent
        Column {
            property var ev: null
            property string prefix: ""
            visible: !!ev
            width: visible ? w.z(580) : 0; height: visible ? implicitHeight : 0
            spacing: w.z(2)
            Text {
                width: parent.width
                horizontalAlignment: w.align === "right" ? Text.AlignRight : w.align === "center" ? Text.AlignHCenter : Text.AlignLeft
                text: parent.ev ? parent.prefix + parent.ev.when : ""
                color: "#ffffff"; opacity: 0.85; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(21); font.weight: Font.DemiBold
                style: Text.Raised; styleColor: w.shadow
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                horizontalAlignment: w.align === "right" ? Text.AlignRight : w.align === "center" ? Text.AlignHCenter : Text.AlignLeft
                text: parent.ev ? parent.ev.title : ""
                color: "#ffffff"; font.family: w.sv ? w.sv.fDisplay : "Droid Sans"; font.pixelSize: w.z(34)
                style: Text.Raised; styleColor: w.shadow
            }
        }
    }
    Component {
        id: cCalNow
        Loader { sourceComponent: cEvent; onLoaded: item.ev = Qt.binding(function () { return w.sv ? w.sv.calNow : null; }) }
    }
    Component {
        id: cCalNext
        Loader {
            sourceComponent: cEvent
            onLoaded: { item.prefix = "Después · "; item.ev = Qt.binding(function () { return w.sv ? w.sv.calNext : null; }); }
        }
    }
    // Fecha en que se sacó la foto (y "Hace N años" si es de un día como hoy)
    Component {
        id: cPhotoDate
        Column {
            property var ph: w.sv ? w.sv.curPhoto : null
            property int ago: w.sv ? w.sv.yearsAgo(ph) : 0
            visible: !!ph && !!ph.ts
            width: visible ? implicitWidth : 0; height: visible ? implicitHeight : 0
            spacing: w.z(10)
            Rectangle {
                visible: parent.ago > 0
                anchors.right: w.align === "right" ? parent.right : undefined
                anchors.horizontalCenter: w.align === "center" ? parent.horizontalCenter : undefined
                width: agoText.implicitWidth + w.z(28); height: w.z(44); radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                Text {
                    id: agoText
                    anchors.centerIn: parent
                    text: "Hace " + parent.parent.ago + (parent.parent.ago === 1 ? " año" : " años")
                    color: "#ffffff"; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(24); font.weight: Font.DemiBold
                }
            }
            Text {
                anchors.right: w.align === "right" ? parent.right : undefined
                anchors.horizontalCenter: w.align === "center" ? parent.horizontalCenter : undefined
                text: {
                    var p = parent.ph;
                    if (!p || !p.ts || !w.sv) return "";
                    var d = new Date(p.ts);
                    return d.getDate() + " de " + w.sv.meses[d.getMonth()] + " de " + d.getFullYear();
                }
                color: "#ffffff"; font.family: w.sv ? w.sv.fBody : "Droid Sans"; font.pixelSize: w.z(32)
                style: Text.Raised; styleColor: w.shadow
            }
        }
    }
}
