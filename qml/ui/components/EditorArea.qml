import QtQuick
import qs.Common
import qs.Widgets

// Center area: tab bar, the empty state and the open note (NoteView). Inputs: ui. The host anchors it between the sidebar
// and the right panel. Re-exports the editor items the panel logic needs.
Item {
    id: editorArea
    required property var ui

    TabBar {
        id: tabBar
        ui: editorArea.ui
    }

    Column {
        anchors.centerIn: parent
        visible: ui.core.noteRel === "" && !ui.core.noteLoading
        spacing: 8
        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "edit_note"
            size: 48
            color: Theme.surfaceVariantText
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No note open"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, editorArea.width - 40)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: ui.core.showSidebar ? "Pick a note on the left, Ctrl+O to search, or Ctrl+N for a new one" : "Ctrl+O to open a note, Ctrl+N for a new one"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }
    }

    NoteView {
        id: noteView
        ui: editorArea.ui
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: ui.core.noteRel !== ""
    }

    readonly property var titleField: noteView.titleField
    readonly property var editor: noteView.editor
    readonly property var flick: noteView.flick
    readonly property var underlay: noteView.underlay
    readonly property var previewFlick: noteView.previewFlick
    readonly property var findField: noteView.findField
    readonly property var replaceField: noteView.replaceField
}
