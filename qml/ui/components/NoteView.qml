import QtQuick
import qs.Common

// The open note: conflict banner, inline title, properties, formatting toolbar, find bar, editor / preview panes and status bar.
// Inputs: ui. Exposes the items the panel logic needs (editor, title field, flickables, find fields).
Item {
    id: noteView
    required property var ui

    ConflictBanner {
        id: banner
        ui: noteView.ui
    }

    TextInput {
        id: titleInput
        anchors.top: banner.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.rightMargin: 28
        height: 40
        clip: true
        color: Theme.surfaceText
        selectionColor: Theme.primary
        selectedTextColor: Theme.primaryText
        font.pixelSize: 26
        font.weight: Font.DemiBold
        selectByMouse: true
        verticalAlignment: TextInput.AlignVCenter
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                ui.commitTitle();
                ui.editor.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                ui.editor.forceActiveFocus();
                event.accepted = true;
            }
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                ui.commitTitle();
        }
    }

    Rectangle {
        id: titleLine
        anchors.top: titleInput.bottom
        anchors.topMargin: 6
        anchors.left: titleInput.left
        anchors.right: titleInput.right
        height: 1
        color: titleInput.activeFocus ? Theme.primary : Theme.outline
        opacity: titleInput.activeFocus ? 1 : 0.35
    }

    PropertiesBlock {
        id: propsBlock
        ui: noteView.ui
        anchors.top: titleLine.bottom
        anchors.topMargin: 4
        anchors.left: titleInput.left
        anchors.right: titleInput.right
    }

    FormatToolbar {
        id: toolbar
        ui: noteView.ui
        anchors.top: propsBlock.bottom
        anchors.topMargin: 6
    }

    FindBar {
        id: findBar
        ui: noteView.ui
        anchors.top: toolbar.bottom
        anchors.topMargin: visible ? 6 : 0
    }

    Item {
        id: panes
        anchors.top: findBar.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusBar.top

        EditorPane {
            id: editorPane
            ui: noteView.ui
        }

        Rectangle {
            visible: ui.core.viewMode === "split"
            x: parent.width / 2
            width: 1
            height: parent.height
            color: Theme.outline
            opacity: 0.4
        }

        PreviewPane {
            id: previewPane
            ui: noteView.ui
        }
    }

    StatusBar {
        id: statusBar
        ui: noteView.ui
    }

    readonly property var titleField: titleInput
    readonly property var editor: editorPane.textArea
    readonly property var flick: editorPane.flickable
    readonly property var underlay: editorPane.underlayItem
    readonly property var previewFlick: previewPane.flickable
    readonly property var findField: findBar.field
    readonly property var replaceField: findBar.replaceInput
}
