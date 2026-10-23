/*
 * System Settings > Side button: what the Mi 9's left-side (AI) button does.
 * Backend: sidebutton.py (pyotherside) writes ~/.config/cepheus/sidebutton.json,
 * which /usr/libexec/cepheus-sidebutton re-reads on every press.
 */
import QtQuick 2.12
import SystemSettings 1.0
import Lomiri.Components 1.3
import SystemSettings.ListItems 1.0 as SettingsListItems
import io.thp.pyotherside 1.4

ItemPage {
    id: root
    title: i18n.tr("Side button")
    flickable: flick

    property var cfg: ({})
    property var apps: []

    function label(action) {
        if (!action || action === "none")
            return i18n.tr("Nothing")
        if (action === "torch")
            return i18n.tr("Torch")
        for (var i = 0; i < apps.length; i++)
            if (apps[i].id === action)
                return apps[i].name
        return action.indexOf("app:") === 0 ? action.substring(4) : action
    }

    function pick(gesture, title) {
        var page = pageStack.addPageToNextColumn(root, Qt.resolvedUrl("ActionPicker.qml"), {
            title: title, current: cfg[gesture], apps: apps
        })
        page.chosen.connect(function (action) {
            py.call("sidebutton.save", [gesture, action], function (c) { root.cfg = c })
            pageStack.removePages(page)
        })
    }

    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("."))
            importModule("sidebutton", function () {
                call("sidebutton.load", [], function (c) { root.cfg = c })
                call("sidebutton.apps", [], function (a) { root.apps = a })
            })
        }
        onError: console.log("sidebutton: " + traceback)
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height
        boundsBehavior: (contentHeight > root.height) ?
                            Flickable.DragAndOvershootBounds : Flickable.StopAtBounds

        Column {
            id: column
            anchors { left: parent.left; right: parent.right }

            SettingsListItems.SingleValueProgression {
                text: i18n.tr("Single press")
                value: root.label(root.cfg.single)
                onClicked: root.pick("single", text)
            }
            SettingsListItems.SingleValueProgression {
                text: i18n.tr("Double press")
                value: root.label(root.cfg.double)
                onClicked: root.pick("double", text)
            }
            SettingsListItems.SingleValueProgression {
                text: i18n.tr("Press and hold")
                value: root.label(root.cfg.long)
                onClicked: root.pick("long", text)
            }
            Label {
                anchors { left: parent.left; right: parent.right; margins: units.gu(2) }
                topPadding: units.gu(2)
                wrapMode: Text.WordWrap
                textSize: Label.Small
                text: i18n.tr("The button on the left side of the phone, below the volume keys. With a double press set, a single press waits a moment to tell the two apart.")
            }
        }
    }
}
