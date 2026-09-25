import QtQuick
import qs.Common
import qs.Widgets

// Sidebar tags pane: tag filter and the nested tag tree with the notes of the selected tag (ui.tagRows). Inputs: ui.
FocusScope {
    id: tagScope
    required property var ui

    visible: ui.core.sidebarTab === "tags"
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (tagField.text.length > 0) {
                tagField.text = "";
                ui.tagFilter = "";
            } else {
                ui.focusEditor();
            }
            event.accepted = true;
        }
    }
    DankTextField {
        id: tagField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        leftIconName: "sell"
        leftIconSize: 16
        textColor: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
        placeholderText: "Filter tags…"
        keyForwardTargets: [tagScope]
        onTextEdited: ui.tagFilter = text.trim().replace(/^#/, "")
    }
    ListView {
        id: tagList
        anchors.top: tagField.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 1
        model: ui.tagRows
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            id: trow
            required property var modelData
            width: ListView.view.width
            height: 28
            radius: 6
            color: modelData.selected ? Theme.primaryContainer : (trMouse.containsMouse ? Theme.surfaceContainer : "transparent")
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 6 + modelData.depth * 16
                spacing: 4
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.kind === "tag" ? (modelData.hasChildren ? (modelData.expanded ? "expand_more" : "chevron_right") : "tag") : "description"
                    size: 16
                    color: modelData.kind === "tag" ? Theme.primary : Theme.surfaceVariantText
                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.kind === "tag" && modelData.hasChildren
                        onClicked: ui.core.toggleTag(modelData.tag)
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: trow.width - 6 - modelData.depth * 16 - 60
                    text: modelData.kind === "tag" ? modelData.name : ui.core.noteTitleOf(modelData.path)
                    elide: Text.ElideRight
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: modelData.kind === "tag" && modelData.selected ? Font.DemiBold : Font.Normal
                }
            }
            StyledText {
                visible: modelData.kind === "tag"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.count
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
            MouseArea {
                id: trMouse
                anchors.fill: parent
                hoverEnabled: true
                z: -1
                onClicked: {
                    if (modelData.kind === "tag")
                        ui.core.selectTag(modelData.selected ? "" : modelData.tag);
                    else
                        ui.core.openNote(modelData.path);
                }
            }
        }
    }
    StyledText {
        anchors.centerIn: tagList
        width: tagList.width - 24
        visible: ui.tagRows.length === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: ui.tagFilter ? "No tags match." : "No tags yet.\nWrite #tag in a note, or add tags: to its properties."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
    }
}
