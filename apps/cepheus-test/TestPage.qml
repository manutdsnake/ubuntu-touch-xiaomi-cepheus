import QtQuick 2.12
import Lomiri.Components 1.3

Page {
    id: page
    property string name
    property alias content: col.data
    header: PageHeader { title: page.name }
    Flickable {
        anchors { fill: parent; topMargin: page.header.height; margins: units.gu(2) }
        contentHeight: col.height + units.gu(4)
        clip: true
        Column { id: col; width: parent.width; spacing: units.gu(1.5) }
    }
}
