import QtQuick
import qs.Common
import qs.Widgets

// Quick switcher overlay: also the command palette, template picker and move-to-folder picker (ui.switcherMode).
// Inputs: ui. Exposes the text field (`field`) so the panel can focus it.
Rectangle {
    required property var ui

    visible: ui.switcherOpen
    anchors.fill: parent
    z: 110
    radius: Theme.cornerRadius
    color: Qt.rgba(0, 0, 0, 0.4)
    MouseArea {
        anchors.fill: parent
        onClicked: ui.closeSwitcher()
    }

    FocusScope {
        id: switcherScope
        anchors.horizontalCenter: parent.horizontalCenter
        y: 70
        width: 580
        height: swCol.implicitHeight + 20
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                ui.closeSwitcher();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                ui.switcherIndex = Math.min(ui.switcherIndex + 1, ui.switcherResults.length - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                ui.switcherIndex = Math.max(ui.switcherIndex - 1, 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                ui.switcherAccept((event.modifiers & Qt.ControlModifier) !== 0);
                event.accepted = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outline
        }
        Column {
            id: swCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8
            DankTextField {
                id: switcherField
                width: parent.width
                height: 44
                leftIconName: "search"
                leftIconSize: 18
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                placeholderText: ui.moveSource ? "Move \"" + ui.moveSource.split("/").pop() + "\" to…" : (ui.switcherMode === "commands" ? "Type a command…" : (ui.switcherMode.indexOf("template-") === 0 ? "Pick a template…" : "Find or create a note…"))
                keyForwardTargets: [switcherScope]
                onTextEdited: ui.updateSwitcher()
            }
            ListView {
                id: swList
                width: parent.width
                height: Math.min(contentHeight, 360)
                clip: true
                model: ui.switcherResults
                currentIndex: ui.switcherIndex
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 36
                    radius: 8
                    color: index === ui.switcherIndex ? Theme.primaryContainer : "transparent"
                    DankIcon {
                        id: swIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.kind === "create" ? "note_add" : (modelData.kind === "folder" ? "folder" : (modelData.kind === "command" ? "keyboard_command_key" : "description"))
                        size: 18
                        color: modelData.kind === "create" ? Theme.primary : Theme.surfaceVariantText
                    }
                    StyledText {
                        anchors.left: swIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.kind === "create" ? "Create “" + modelData.name + "”" : (modelData.item.name + (modelData.item.folder ? "     " + modelData.item.folder : ""))
                        elide: Text.ElideRight
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            ui.switcherIndex = index;
                            ui.switcherAccept(false);
                        }
                    }
                }
            }
            StyledText {
                text: ui.moveSource ? "↑↓ move  ·  Enter move here  ·  Esc cancel" : (ui.switcherMode === "notes" ? "↑↓ move  ·  Enter open  ·  Ctrl+Enter new tab  ·  Esc close" : "↑↓ move  ·  Enter run  ·  Esc close")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    readonly property var field: switcherField
}
