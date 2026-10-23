import QtQuick 2.12
import SystemSettings 1.0
import Lomiri.Components 1.3
import SystemSettings.ListItems 1.0 as SettingsListItems

ItemPage {
    id: picker
    property string current: "none"
    property var apps: []
    signal chosen(string action)
    flickable: list

    ListView {
        id: list
        anchors.fill: parent
        model: [{ id: "none", name: i18n.tr("Nothing"), icon: "" },
                { id: "torch", name: i18n.tr("Torch"), icon: "image://theme/torch-on" }].concat(picker.apps)

        delegate: SettingsListItems.IconProgression {
            text: modelData.name
            iconSource: modelData.icon
            progressionVisible: false
            Icon {
                name: "tick"
                width: units.gu(2); height: width
                visible: modelData.id === picker.current
                SlotsLayout.position: SlotsLayout.Trailing
            }
            onClicked: picker.chosen(modelData.id)
        }
    }
}
