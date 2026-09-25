import QtQuick
import qs.Common
import qs.Widgets
import "../widgets"

// Status bar: note path, cursor position, word count, save state, view mode / toolbar buttons. Inputs: ui.
Rectangle {
    id: statusBar
    required property var ui

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 30
    color: Theme.surfaceContainer
    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: ui.core.noteRel
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Ln " + ui.cursorLine + ", Col " + ui.cursorCol + "  ·  " + ui.wordCount(ui.core.buffer) + " words  ·  " + ui.core.buffer.length + " chars  ·  " + (ui.core.conflict ? "Conflict" : (ui.core.dirty ? "Unsaved…" : "Saved"))
            color: ui.core.conflict ? Theme.error : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }
        IconBtn {
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            icon: "format_size"
            active: ui.core.showToolbar
            onClicked: ui.core.toggleToolbar()
        }
        IconBtn {
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            icon: ui.core.viewMode === "edit" ? "edit" : (ui.core.viewMode === "split" ? "vertical_split" : "visibility")
            onClicked: ui.core.cycleViewMode()
        }
    }
}
