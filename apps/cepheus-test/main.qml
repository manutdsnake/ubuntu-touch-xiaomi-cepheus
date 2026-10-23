// Cepheus Test - hardware check for the Mi 9 Ubuntu Touch port.
import QtQuick 2.12
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import QtSensors 5.12
import QtPositioning 5.12
import QtMultimedia 5.12
import QtFeedback 5.0
import io.thp.pyotherside 1.5

MainView {
    id: root
    applicationName: "cepheus-test"
    width: units.gu(45); height: units.gu(80)

    // name -> "ok" | "fail" | ""
    property var results: ({})
    property string dev: ""   // device-info Name: cepheus (Mi 9), dipper (Mi 8)
    function mark(name, r) { var x = results; x[name] = r; results = x }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("."))
            importModule("backend", function() { ready = true; call("backend.device", [], function(r) { root.dev = r }) })
        }
        property bool ready: false
        onError: console.log("python: " + traceback)
    }

    // One test row: title, hint, optional status, pass/fail buttons.
    component ResultRow: Row {
        property string name
        spacing: units.gu(1)
        Button { text: "Radi"; color: theme.palette.normal.positive; onClicked: mark(name, "ok") }
        Button { text: "Ne radi"; color: theme.palette.normal.negative; onClicked: mark(name, "fail") }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: results[name] === "ok" ? "✔" : results[name] === "fail" ? "✘" : ""
            color: results[name] === "ok" ? "green" : "red"
            textSize: Label.Large
        }
    }

    component Info: Label { width: parent.width; wrapMode: Text.Wrap; font.family: "Ubuntu Mono" }

    PageStack {
        id: stack
        Component.onCompleted: push(menu)
    }

    Page {
        id: menu
        visible: false
        header: PageHeader { title: "Test hardvera" + (root.dev ? " – " + root.dev : "") }
        ListView {
            anchors { fill: parent; topMargin: menu.header.height }
            model: ([
                ["Zaslon", displayPage], ["Dodir", touchPage], ["Zvučnik", speakerPage],
                ["Slušalica (poziv)", earpiecePage], ["Mikrofoni", micPage], ["Vibracija", vibraPage],
                ["Svjetiljka", flashPage], ["Senzori", sensorPage], ["Proximity", proxPage],
                ["GPS", gpsPage], ["Kamere", cameraPage], ["Tipke", keyPage],
                ["Baterija i punjenje", batteryPage], ["WiFi / Bluetooth / Mreža", netPage],
                ["NFC", nfcPage]].concat(root.dev === "dipper" ? [] : [["IR odašiljač", irPage]]).concat([["Otisak prsta", fpPage],
                ["Sustav", sysPage], ["Rezultati", summaryPage]]))
            delegate: ListItem {
                height: units.gu(6)
                Label {
                    anchors { left: parent.left; leftMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                    text: modelData[0]
                }
                Label {
                    anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                    text: results[modelData[0]] === "ok" ? "✔" : results[modelData[0]] === "fail" ? "✘" : "›"
                    color: results[modelData[0]] === "ok" ? "green" : results[modelData[0]] === "fail" ? "red" : theme.palette.normal.baseText
                }
                onClicked: stack.push(modelData[1])
            }
        }
    }

    // ------------------------------------------------------------ display
    Component {
        id: displayPage
        Page {
            header: PageHeader { title: "Zaslon"; visible: step < 0 }
            property int step: -1
            property var colors: ["red", "lime", "blue", "white", "black", "gray"]
            Rectangle {
                anchors.fill: parent
                visible: parent.step >= 0
                z: 10
                color: parent.step >= 0 && parent.step < 6 ? parent.colors[parent.step] : "black"
                Rectangle {   // gradient for banding
                    anchors.fill: parent; visible: parent.parent.step === 6
                    gradient: Gradient { GradientStop { position: 0; color: "black" } GradientStop { position: 1; color: "white" } }
                }
                MouseArea { anchors.fill: parent; onClicked: parent.parent.step = parent.parent.step < 6 ? parent.parent.step + 1 : -1 }
            }
            Column {
                anchors { fill: parent; topMargin: units.gu(8); margins: units.gu(2) }
                spacing: units.gu(2)
                Info { text: "Dodirni za redom: crvena, zelena, plava, bijela, crna, siva, gradijent. Traži mrtve piksele, mrlje, nejednoliku svjetlinu i pruge u gradijentu. Provjeri i rubove i izrez za kameru." }
                Button { text: "Pokreni"; onClicked: step = 0 }
                ResultRow { name: "Zaslon" }
            }
        }
    }

    // ------------------------------------------------------------ touch
    Component {
        id: touchPage
        Page {
            header: PageHeader { title: "Dodir" }
            Canvas {
                id: canvas
                anchors { fill: parent; topMargin: parent.header.height }
                property var pts: []
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.fillStyle = "#e91e63"
                    for (var i = 0; i < pts.length; i++) ctx.fillRect(pts[i].x - 6, pts[i].y - 6, 12, 12)
                    pts = []
                }
            }
            MultiPointTouchArea {
                anchors.fill: canvas
                maximumTouchPoints: 10
                onUpdated: {
                    for (var i = 0; i < touchPoints.length; i++) canvas.pts.push({x: touchPoints[i].x, y: touchPoints[i].y})
                    cnt.text = "Prstiju: " + touchPoints.length
                    canvas.requestPaint()
                }
                onPressed: cnt.text = "Prstiju: " + touchPoints.length
            }
            Column {
                anchors { bottom: parent.bottom; left: parent.left; margins: units.gu(2) }
                spacing: units.gu(1)
                Label { id: cnt; text: "Oboji cijeli ekran, uključujući rubove. Probaj i 5+ prstiju." }
                Row {
                    spacing: units.gu(1)
                    Button { text: "Očisti"; onClicked: { var c = canvas.getContext("2d"); c.clearRect(0, 0, canvas.width, canvas.height); canvas.requestPaint() } }
                    ResultRow { name: "Dodir" }
                }
            }
        }
    }

    // ------------------------------------------------------------ audio
    Component {
        id: speakerPage
        TestPage {
            name: "Zvučnik"
            content: [
                Info { text: "Svira ton od 2 s na glavnom zvučniku (dno)." },
                Row { spacing: units.gu(1)
                    Button { text: "440 Hz"; onClicked: py.call("backend.play", [440, "speaker"], function(r) { out.text = r }) }
                    Button { text: "1 kHz"; onClicked: py.call("backend.play", [1000, "speaker"], function(r) { out.text = r }) }
                    Button { text: "5 kHz"; onClicked: py.call("backend.play", [5000, "speaker"], function(r) { out.text = r }) }
                },
                Info { id: out },
                ResultRow { name: "Zvučnik" }
            ]
        }
    }
    Component {
        id: earpiecePage
        TestPage {
            name: "Slušalica (poziv)"
            content: [
                Info { text: "Svira ton na slušalici (gornji zvučnik za pozive). Prisloni uho na vrh telefona." },
                Button { text: "Ton na slušalici"; onClicked: py.call("backend.play", [1000, "earpiece"], function(r) { out.text = r }) },
                Info { id: out },
                ResultRow { name: "Slušalica (poziv)" }
            ]
        }
    }
    Component {
        id: micPage
        TestPage {
            name: "Mikrofoni"
            property var last: ({})
            content: [
                Info { text: "Snimi 4 s govora, pa reproduciraj. Donji mikrofon je glavni, gornji (back) služi za poništavanje buke." },
                Row { spacing: units.gu(1)
                    Button { text: "Snimi donji"; onClicked: { out.text = "snimam…"; py.call("backend.record", ["builtin_mic"], function(r) { last = r; out.text = "vršna razina " + r.peak + " / 32767, " + r.bytes + " B" }) } }
                    Button { text: "Snimi gornji"; onClicked: { out.text = "snimam…"; py.call("backend.record", ["back_mic"], function(r) { last = r; out.text = "vršna razina " + r.peak + " / 32767, " + r.bytes + " B" }) } }
                },
                Button { text: "Reproduciraj zadnju snimku"; enabled: last.path !== undefined; onClicked: py.call("backend.playback", [last.path], function(r) {}) },
                Info { id: out },
                ResultRow { name: "Mikrofoni" }
            ]
        }
    }

    // ------------------------------------------------------------ vibration / flash
    Component {
        id: vibraPage
        TestPage {
            name: "Vibracija"
            content: [
                HapticsEffect { id: fx; attackIntensity: 0; attackTime: 50; intensity: 1.0; fadeTime: 50; fadeIntensity: 0 },
                Row { spacing: units.gu(1)
                    Button { text: "Kratko"; onClicked: { fx.duration = 60; fx.start() } }
                    Button { text: "Dugo (1 s)"; onClicked: { fx.duration = 1000; fx.start() } }
                },
                ResultRow { name: "Vibracija" }
            ]
        }
    }
    Component {
        id: flashPage
        TestPage {
            name: "Svjetiljka"
            content: [
                Info { text: "Dvije stražnje LED diode trebaju svijetliti zajedno." },
                Row { spacing: units.gu(1)
                    Button { text: "Upali"; onClicked: py.call("backend.flash", [true], function(r) { out.text = r }) }
                    Button { text: "Ugasi"; onClicked: py.call("backend.flash", [false], function(r) { out.text = r }) }
                },
                Info { id: out },
                ResultRow { name: "Svjetiljka" }
            ]
        }
    }

    // ------------------------------------------------------------ sensors
    Component {
        id: sensorPage
        TestPage {
            name: "Senzori"
            Accelerometer { id: acc; active: true }
            Gyroscope { id: gyro; active: true }
            Magnetometer { id: mag; active: true; returnGeoValues: false }
            Compass { id: comp; active: true }
            LightSensor { id: light; active: true }
            OrientationSensor { id: orient; active: true }
            RotationSensor { id: rot; active: true }
            PressureSensor { id: baro; active: true }
            function f(v) { return v === undefined ? "-" : Number(v).toFixed(2) }
            content: [
                Info { text: "Akcelerometar (m/s²): " + (acc.reading ? f(acc.reading.x) + ", " + f(acc.reading.y) + ", " + f(acc.reading.z) : "nema podataka") },
                Info { text: "Žiroskop (°/s): " + (gyro.reading ? f(gyro.reading.x) + ", " + f(gyro.reading.y) + ", " + f(gyro.reading.z) : "nema podataka") },
                Info { text: "Magnetometar (µT): " + (mag.reading ? f(mag.reading.x * 1e6) + ", " + f(mag.reading.y * 1e6) + ", " + f(mag.reading.z * 1e6) : "nema podataka") },
                Info { text: "Kompas: " + (comp.reading ? f(comp.reading.azimuth) + "° (kalibracija " + f(comp.reading.calibrationLevel) + ")" : "nema podataka") },
                Info { text: "Svjetlo (lux): " + (light.reading ? f(light.reading.illuminance) : "nema podataka") },
                Info { text: "Orijentacija: " + (orient.reading ? ["?", "gore", "dolje", "lijevo", "desno", "lice gore", "lice dolje"][orient.reading.orientation] : "nema podataka") },
                Info { text: "Rotacija: " + (rot.reading ? f(rot.reading.x) + ", " + f(rot.reading.y) + ", " + f(rot.reading.z) : "nema podataka") },
                Info { text: "Barometar (hPa): " + (baro.reading ? f(baro.reading.pressure / 100) : (root.dev === "cepheus" ? "nema (Mi 9 nema barometar)" : "nema podataka")) },
                Info { text: "Okreći telefon, pokrij gornji dio rukom (svjetlo), okreni se oko sebe (kompas)." },
                ResultRow { name: "Senzori" }
            ]
        }
    }
    Component {
        id: proxPage
        TestPage {
            name: "Proximity"
            ProximitySensor { id: prox; active: true }
            content: [
                Info { text: root.dev === "cepheus" ? "Mi 9 nema klasični senzor blizine nego ultrazvučni (preko zvučnika slušalice i mikrofona). Poznato je da na ovom portu još ne radi."
                                                    : "Pokrij gornji dio telefona (uz slušalicu) rukom." },
                Label { text: prox.reading ? (prox.reading.near ? "BLIZU" : "daleko") : "nema podataka"; textSize: Label.XLarge },
                ResultRow { name: "Proximity" }
            ]
        }
    }

    // ------------------------------------------------------------ GPS
    Component {
        id: gpsPage
        TestPage {
            name: "GPS"
            PositionSource { id: pos; active: true; updateInterval: 1000; preferredPositioningMethods: PositionSource.SatellitePositioningMethods }
            content: [
                Info { text: "Izađi van ili stani uz prozor. Prvi fix može trajati nekoliko minuta." },
                Info { text: "Izvor: " + pos.name + (pos.valid ? "" : " (nije valjan)") + "\nStatus: " + ["bez greške", "pristup odbijen", "zatvoren", "nepoznato", "nema izvora"][pos.sourceError] },
                Info {
                    text: pos.position.coordinate.isValid
                          ? "Pozicija: " + pos.position.coordinate.latitude.toFixed(6) + ", " + pos.position.coordinate.longitude.toFixed(6)
                            + "\nVisina: " + (pos.position.altitudeValid ? pos.position.coordinate.altitude.toFixed(0) + " m" : "-")
                            + "\nTočnost: " + (pos.position.horizontalAccuracyValid ? pos.position.horizontalAccuracy.toFixed(0) + " m" : "-")
                            + "\nBrzina: " + (pos.position.speedValid ? (pos.position.speed * 3.6).toFixed(1) + " km/h" : "-")
                          : "Čekam fix…"
                },
                ResultRow { name: "GPS" }
            ]
        }
    }

    // ------------------------------------------------------------ cameras
    Component {
        id: cameraPage
        Page {
            header: PageHeader { title: "Kamere (" + (camIdx + 1) + "/" + lenses.length + ")" }
            property int camIdx: 0
            // Physical lenses only; ids 4-10 are Xiaomi's logical multi-cameras.
            property var lenses: root.dev === "cepheus"
                ? [["0", "Glavna 48 MP (IMX586)"], ["2", "Tele 12 MP 2× (S5K3M5)"], ["3", "Širokokutna 16 MP (IMX481)"], ["1", "Prednja 20 MP (S5K3T1)"]]
                : root.dev === "dipper"
                ? [["0", "Glavna 12 MP (IMX363)"], ["2", "Tele 12 MP 2× (S5K3M3)"], ["1", "Prednja 20 MP (S5K3T1)"]]
                : QtMultimedia.availableCameras.map(function(c) { return [c.deviceId, c.displayName + (c.position === Camera.FrontFace ? " (prednja)" : " (stražnja)")] })
            Camera {
                id: cam
                deviceId: lenses[camIdx][0]
                flash.mode: flashOn ? Camera.FlashTorch : Camera.FlashOff
                property bool flashOn: false
                imageCapture.onImageSaved: out.text = "Spremljeno: " + path
            }
            VideoOutput {
                anchors { fill: parent; topMargin: parent.header.height; bottomMargin: units.gu(16) }
                source: cam; autoOrientation: true; fillMode: VideoOutput.PreserveAspectFit
                MouseArea { anchors.fill: parent; onClicked: cam.searchAndLock() }
            }
            Column {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: units.gu(1) }
                spacing: units.gu(1)
                Info { id: out; text: lenses[camIdx][1] + " - dodir = fokus" }
                Row { spacing: units.gu(1)
                    Button { text: "Sljedeća"; onClicked: camIdx = (camIdx + 1) % lenses.length }
                    Button { text: "Slikaj"; onClicked: cam.imageCapture.capture() }
                    Button { text: "Blic"; onClicked: cam.flashOn = !cam.flashOn }
                }
                ResultRow { name: "Kamere" }
            }
        }
    }

    // ------------------------------------------------------------ keys
    Component {
        id: keyPage
        TestPage {
            name: "Tipke"
            focus: true
            property var seen: ({})
            Keys.onPressed: { var s = seen; s[event.key] = true; seen = s; out.text = "Zadnja tipka: " + event.key + " (" + (event.key === Qt.Key_VolumeUp ? "Glasnoća +" : event.key === Qt.Key_VolumeDown ? "Glasnoća -" : event.text) + ")"; event.accepted = true }
            content: [
                Info { text: "Pritisni Glasnoća +, Glasnoća -. Tipku za uključivanje testiraj gašenjem i paljenjem ekrana." },
                Info { text: "Glasnoća +: " + (seen[Qt.Key_VolumeUp] ? "✔" : "…") + "   Glasnoća -: " + (seen[Qt.Key_VolumeDown] ? "✔" : "…") },
                Info { id: out },
                ResultRow { name: "Tipke" }
            ]
        }
    }

    // ------------------------------------------------------------ battery
    Component {
        id: batteryPage
        TestPage {
            name: "Baterija i punjenje"
            property var b: ({})
            Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (py.ready) py.call("backend.battery", [], function(r) { b = r }) }
            content: [
                Info { text: "Razina: " + b.capacity + " %   Status: " + b.status + "   Zdravlje: " + b.health },
                Info { text: "Napon: " + b.voltage_now + " V   Struja: " + b.current_now + " A   Temperatura: " + b.temp + " °C" },
                Info { text: "Kapacitet: " + b.charge_full + " / " + b.charge_full_design + " µAh   Ciklusi: " + b.cycle_count },
                Info { text: "USB: online=" + b.usb_online + " tip=" + b.usb_type + " type-c=" + b.typec + "   Punjenje: " + b.charge_type },
                Info { text: "Bežično: prisutno=" + b.wireless + " online=" + b.wireless_online },
                Info { text: "Testiraj: USB punjač (brzo punjenje), računalo, bežični punjač, OTG (USB stick/miš preko adaptera)." },
                ResultRow { name: "Baterija i punjenje" }
            ]
        }
    }

    // ------------------------------------------------------------ network
    Component {
        id: netPage
        TestPage {
            name: "WiFi / Bluetooth / Mreža"
            property var c: ({})
            Component.onCompleted: py.call("backend.connectivity", [], function(r) { c = r })
            content: [
                Button { text: "Osvježi"; onClicked: py.call("backend.connectivity", [], function(r) { c = r }) },
                Info { text: "WiFi:\n" + c.wifi + "\n" + (c.wifi_signal || "") + "\n\nIP:\n" + c.ip },
                Button { text: "Skeniraj WiFi"; onClicked: { scan.text = "…"; py.call("backend.wifi_scan", [], function(r) { scan.text = r }) } },
                Info { id: scan },
                Info { text: "Bluetooth:\n" + c.bt },
                Button { text: "Skeniraj Bluetooth (8 s)"; onClicked: { bts.text = "…"; py.call("backend.bt_scan", [], function(r) { bts.text = r }) } },
                Info { id: bts },
                Info { text: "Modem / SIM:\n" + c.modem },
                Info { text: "Testiraj: poziv (čuješ li i čuju li tebe), SMS, mobilni podaci s ugašenim WiFi-jem, drugi SIM." },
                ResultRow { name: "WiFi / Bluetooth / Mreža" }
            ]
        }
    }
    Component {
        id: nfcPage
        TestPage {
            name: "NFC"
            property var n: ({})
            Timer { interval: 500; running: true; repeat: true; triggeredOnStart: true
                onTriggered: if (py.ready) py.call("backend.nfc_state", [], function(r) { n = r }) }
            content: [
                Info { text: "Drži ekran upaljen i otključan (NFC ne čita dok je ekran ugašen). Prisloni karticu na sredinu leđa, malo ispod kamera." },
                Info { text: "Uključen: " + n.powered + "   Način: " + n.mode },
                Label { text: n.present === "true" ? "KARTICA PRISUTNA" : "nema kartice"; textSize: Label.Large
                        color: n.present === "true" ? "green" : theme.palette.normal.baseText },
                Info { text: "Kartice:\n" + n.tags },
                ResultRow { name: "NFC" }
            ]
        }
    }
    Component {
        id: irPage
        TestPage {
            name: "IR odašiljač"
            content: [
                Info { text: root.dev === "cepheus" ? "IR dioda je na vrhu telefona. Ljudsko oko je ne vidi - usmjeri je u kameru DRUGOG telefona (selfie kamere često nemaju IR filter) i gledaj bljeskanje."
                                                    : "Ovaj telefon nema IR odašiljač." },
                Button { text: "Pošalji IR signal"; onClicked: py.call("backend.ir_blast", [], function(r) { out.text = r }) },
                Info { id: out },
                ResultRow { name: "IR odašiljač" }
            ]
        }
    }
    Component {
        id: fpPage
        TestPage {
            name: "Otisak prsta"
            property var s: ({})
            Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (py.ready) py.call("backend.system_info", [], function(r) { s = r }) }
            content: [
                Info { text: root.dev === "cepheus" ? "Upis: Postavke → Sigurnost i privatnost → Otisak prsta. Senzor je ispod ekrana, oko 2,5 cm iznad donjeg ruba, na sredini - kad je upis aktivan i staviš prst, ekran se zatamni i pod prstom zasvijetli bijeli krug."
                                                    : "Upis: Postavke → Sigurnost i privatnost → Otisak prsta. Senzor je na stražnjoj strani." },
                Info { text: "biometryd / čeka prst:\n" + s.fp },
                ResultRow { name: "Otisak prsta" }
            ]
        }
    }
    Component {
        id: sysPage
        TestPage {
            name: "Sustav"
            property var s: ({})
            Component.onCompleted: py.call("backend.system_info", [], function(r) { s = r })
            content: [
                Info { text: "Kernel: " + s.kernel + "\nRadi: " + s.uptime + "\nMemorija (MB): " + s.mem + "\nPohrana: " + s.storage },
                Info { text: "Servisi koji ne rade:\n" + s.failed },
                Info { text: "Zaslon: " + Screen.width + "×" + Screen.height + " px, GridUnit " + units.gu(1) + " px" }
            ]
        }
    }
    Component {
        id: summaryPage
        TestPage {
            name: "Rezultati"
            content: [
                Info {
                    text: {
                        var t = ""
                        for (var k in results) t += (results[k] === "ok" ? "✔ " : "✘ ") + k + "\n"
                        return t || "Još nema rezultata."
                    }
                }
            ]
        }
    }
}
