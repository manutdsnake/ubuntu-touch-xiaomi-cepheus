// Cepheus Remote - IR TV remote for the Mi 9 (Flipper-IRDB codes).
import QtQuick 2.12
import Lomiri.Components 1.3
import Qt.labs.settings 1.0
import io.thp.pyotherside 1.5

MainView {
    id: root
    applicationName: "cepheus-remote"
    width: units.gu(45); height: units.gu(80)

    property string status: ""
    property var rp: null   // the open remote page, for Key

    component Key: Button {
        property string k
        property string label: k
        width: units.gu(9); height: units.gu(6)
        text: label; enabled: root.rp !== null && root.rp.keys.indexOf(k) >= 0
        onClicked: root.rp.press(k)
    }
    Settings { id: saved; property string brand: ""; property string remote: "" }

    Python {
        id: py
        property bool ready: false
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("."))
            importModule("backend", function() { ready = true })
        }
        onError: root.status = "python: " + traceback
    }

    PageStack {
        id: stack
        Component.onCompleted: push(home)
    }

    // ------------------------------------------------------------ home
    Page {
        id: home
        visible: false
        header: PageHeader { title: "Daljinski za TV" }
        Column {
            anchors { fill: parent; topMargin: home.header.height + units.gu(2); margins: units.gu(2) }
            spacing: units.gu(2)
            Label { width: parent.width; wrapMode: Text.Wrap; text: "IR dioda je na vrhu telefona - usmjeri vrh prema TV-u." }
            Button {
                width: parent.width; text: "Univerzalni (svi kodovi redom)"; color: theme.palette.normal.positive
                onClicked: stack.push(universalPage)
            }
            Button {
                width: parent.width; text: "Odaberi marku TV-a"
                onClicked: stack.push(brandPage)
            }
            Button {
                width: parent.width; visible: saved.remote !== ""
                text: "Zadnji: " + saved.brand + " / " + saved.remote
                onClicked: stack.push(remotePage, { brand: saved.brand, remote: saved.remote })
            }
            Label { width: parent.width; wrapMode: Text.Wrap; text: root.status; color: theme.palette.normal.backgroundTertiaryText }
        }
    }

    // ------------------------------------------------------------ universal
    Component {
        id: universalPage
        Page {
            id: up
            header: PageHeader { title: "Univerzalni" }
            property var counts: ({})
            property var st: ({})
            property string key: ""
            Component.onCompleted: py.call("backend.universal_keys", [], function(r) { counts = r })
            Timer { interval: 250; running: true; repeat: true; onTriggered: py.call("backend.universal_state", [], function(r) { up.st = r }) }
            Column {
                anchors { fill: parent; topMargin: up.header.height + units.gu(2); margins: units.gu(2) }
                spacing: units.gu(1.5)
                Label { width: parent.width; wrapMode: Text.Wrap
                    text: "Šalje redom kodove svih poznatih TV-a. Kad TV reagira, odmah pritisni STOP, pa tipkama ‹ › nađi točan kod." }
                Grid {
                    columns: 3; spacing: units.gu(1)
                    Repeater {
                        model: [["power", "Power"], ["mute", "Mute"], ["vol_up", "Vol +"], ["vol_dn", "Vol −"], ["ch_next", "Ch +"], ["ch_prev", "Ch −"]]
                        Button {
                            width: units.gu(12); text: modelData[1] + " (" + (up.counts[modelData[0]] || 0) + ")"
                            enabled: !up.st.running
                            onClicked: { up.key = modelData[0]; py.call("backend.universal_start", [modelData[0], 0]) }
                        }
                    }
                }
                ProgressBar { width: parent.width; minimumValue: 0; maximumValue: Math.max(1, up.st.total || 1); value: up.st.done || 0 }
                Label { text: up.st.last || "" }
                Button { width: parent.width; text: "STOP"; color: theme.palette.normal.negative; enabled: up.st.running === true
                    onClicked: py.call("backend.universal_stop", []) }
                Row {
                    spacing: units.gu(1); visible: up.key !== "" && !up.st.running
                    property int idx: Math.max(0, (up.st.done || 1) - 1)
                    Button { text: "‹"; width: units.gu(6); onClicked: { parent.idx = Math.max(0, parent.idx - 1); py.call("backend.universal_one", [up.key, parent.idx], function(r) { root.status = r; res.text = r }) } }
                    Button { text: "Pošalji ponovno"; onClicked: py.call("backend.universal_one", [up.key, parent.idx], function(r) { res.text = r }) }
                    Button { text: "›"; width: units.gu(6); onClicked: { parent.idx = Math.min((up.st.total || 1) - 1, parent.idx + 1); py.call("backend.universal_one", [up.key, parent.idx], function(r) { res.text = r }) } }
                }
                Label { id: res; width: parent.width; wrapMode: Text.Wrap }
            }
        }
    }

    // ------------------------------------------------------------ brands
    Component {
        id: brandPage
        Page {
            id: bp
            header: PageHeader {
                title: "Marka"
                contents: TextField { id: search; anchors.centerIn: parent; width: parent.width; placeholderText: "Traži marku…" }
            }
            property var all: []
            Component.onCompleted: py.call("backend.brands", [], function(r) { all = r })
            ListView {
                anchors { fill: parent; topMargin: bp.header.height }
                clip: true
                model: bp.all.filter(function(b) { return b.toLowerCase().indexOf(search.text.toLowerCase()) >= 0 })
                delegate: ListItem {
                    Label {
                        anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                        text: modelData
                    }
                    onClicked: stack.push(remoteListPage, { brand: modelData })
                }
            }
        }
    }
    Component {
        id: remoteListPage
        Page {
            id: rl
            property string brand
            header: PageHeader { title: rl.brand }
            property var list: []
            Component.onCompleted: py.call("backend.remotes", [brand], function(r) { list = r })
            ListView {
                anchors { fill: parent; topMargin: rl.header.height }
                clip: true
                model: rl.list
                delegate: ListItem {
                    Label {
                        anchors { left: parent.left; leftMargin: units.gu(2); right: parent.right; verticalCenter: parent.verticalCenter }
                        text: modelData; elide: Text.ElideRight
                    }
                    onClicked: { saved.brand = rl.brand; saved.remote = modelData; stack.push(remotePage, { brand: rl.brand, remote: modelData }) }
                }
            }
        }
    }

    // ------------------------------------------------------------ remote
    Component {
        id: remotePage
        Page {
            id: rp
            property string brand
            property string remote
            property var keys: []
            header: PageHeader { title: rp.brand; subtitle: rp.remote }
            Component.onCompleted: { root.rp = rp; py.call("backend.buttons", [brand, remote], function(r) { keys = r }) }
            function has(k) { return keys.indexOf(k) >= 0 }
            function press(k) { py.call("backend.send", [brand, remote, k], function(r) { msg.text = r }) }

            Flickable {
                anchors { fill: parent; topMargin: rp.header.height }
                contentHeight: col.height + units.gu(4)
                clip: true
                Column {
                    id: col
                    x: units.gu(2); y: units.gu(2); width: parent.width - units.gu(4)
                    spacing: units.gu(1.5)
                    Row { spacing: units.gu(1); anchors.horizontalCenter: parent.horizontalCenter
                        Key { k: "power"; label: "⏻"; color: theme.palette.normal.negative }
                        Key { k: "source"; label: "Izvor" }
                        Key { k: "mute"; label: "🔇" }
                    }
                    Grid { columns: 3; spacing: units.gu(1); anchors.horizontalCenter: parent.horizontalCenter
                        Repeater { model: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]; Key { k: modelData } }
                        Key { k: "info"; label: "Info" } Key { k: "0" } Key { k: "guide"; label: "Vodič" }
                    }
                    Grid { columns: 3; spacing: units.gu(1); anchors.horizontalCenter: parent.horizontalCenter
                        Key { k: "home"; label: "⌂" } Key { k: "up"; label: "▲" } Key { k: "menu"; label: "Meni" }
                        Key { k: "left"; label: "◀" } Key { k: "ok"; label: "OK" } Key { k: "right"; label: "▶" }
                        Key { k: "back"; label: "↩" } Key { k: "down"; label: "▼" } Key { k: "exit"; label: "Izlaz" }
                    }
                    Grid { columns: 3; spacing: units.gu(1); anchors.horizontalCenter: parent.horizontalCenter
                        Key { k: "vol_up"; label: "Vol +" } Item { width: units.gu(9); height: 1 } Key { k: "ch_next"; label: "Ch +" }
                        Key { k: "vol_dn"; label: "Vol −" } Item { width: units.gu(9); height: 1 } Key { k: "ch_prev"; label: "Ch −" }
                    }
                    Label { id: msg; width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
                    Label { text: "Ostale tipke:"; visible: others.count > 0 }
                    Flow {
                        width: parent.width; spacing: units.gu(1)
                        Repeater {
                            id: others
                            model: rp.keys.filter(function(k) {
                                return ["power","source","mute","info","guide","home","up","menu","left","ok","right","back","down","exit",
                                        "vol_up","vol_dn","ch_next","ch_prev","0","1","2","3","4","5","6","7","8","9"].indexOf(k) < 0 })
                            Button { text: modelData; onClicked: rp.press(modelData) }
                        }
                    }
                }
            }
        }
    }
}
