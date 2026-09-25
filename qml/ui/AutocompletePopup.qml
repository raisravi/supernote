import QtQuick
import qs.Common
import qs.Widgets

// Popup under the caret for `[[` note completion and the `/` slash menu (items in ui.acItems, selection ui.acIndex).
// Inputs: ui.
Rectangle {
    required property var ui

    visible: ui.acOpen
    x: Math.max(8, Math.min(ui.acPos.x, ui.panelBg.width - width - 8))
    y: Math.min(ui.acPos.y, ui.panelBg.height - height - 8)
    z: 90
    width: 340
    height: acCol.implicitHeight + 8
    radius: 10
    color: Theme.surfaceContainerHigh
    border.width: 1
    border.color: Theme.outline
    Column {
        id: acCol
        x: 4
        y: 4
        width: parent.width - 8
        Repeater {
            model: ui.acItems
            Rectangle {
                required property var modelData
                required property int index
                width: parent.width
                height: 30
                radius: 6
                color: index === ui.acIndex ? Theme.primaryContainer : "transparent"
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    width: parent.width - 20
                    text: modelData.name + (modelData.folder ? "   " + modelData.folder : "")
                    elide: Text.ElideRight
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        ui.acIndex = index;
                        ui.acAccept();
                    }
                }
            }
        }
    }
}
