import QtQuick
import qs.Common
import qs.Widgets

// Row of a popup menu: `label`, `icon`, `danger` (red); emits triggered().
Rectangle {
    id: item
    property string label: ""
    property string icon: ""
    property bool danger: false
    signal triggered
    width: parent ? parent.width : 200
    height: 32
    radius: 6
    color: itemMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        spacing: 8
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: item.icon
            size: 16
            color: item.danger ? Theme.error : Theme.surfaceVariantText
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: item.label
            color: item.danger ? Theme.error : Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
        }
    }
    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.triggered()
    }
}
