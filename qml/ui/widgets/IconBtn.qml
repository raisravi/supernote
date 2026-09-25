import QtQuick
import qs.Common
import qs.Widgets

// Square icon button: `icon` (Material symbol name), `active` highlights it; emits clicked().
Rectangle {
    id: btn
    property string icon: ""
    property string tip: ""
    property bool active: false
    signal clicked
    width: 32
    height: 32
    radius: 8
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : (active ? Theme.primaryContainer : "transparent")
    DankIcon {
        anchors.centerIn: parent
        name: btn.icon
        size: 18
        color: Theme.surfaceText
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
