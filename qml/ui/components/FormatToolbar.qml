import QtQuick
import qs.Common
import qs.Widgets
import "../widgets"

// Formatting toolbar (headings, bold, italic, lists, ...) and the find button. Inputs: ui. The host anchors it.
Rectangle {
    id: toolbar
    required property var ui

    visible: ui.core.showToolbar && ui.core.viewMode !== "preview"
    anchors.topMargin: 6
    anchors.left: parent.left
    anchors.leftMargin: 20
    anchors.right: parent.right
    anchors.rightMargin: 20
    height: visible ? 34 : 0
    radius: 8
    color: Theme.surfaceContainer
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 6
        spacing: 2
        IconBtn { width: 28; height: 28; icon: "format_h1"; onClicked: ui.fmt("h1") }
        IconBtn { width: 28; height: 28; icon: "format_h2"; onClicked: ui.fmt("h2") }
        IconBtn { width: 28; height: 28; icon: "format_h3"; onClicked: ui.fmt("h3") }
        Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.outline; opacity: 0.4 }
        IconBtn { width: 28; height: 28; icon: "format_bold"; onClicked: ui.fmt("bold") }
        IconBtn { width: 28; height: 28; icon: "format_italic"; onClicked: ui.fmt("italic") }
        IconBtn { width: 28; height: 28; icon: "strikethrough_s"; onClicked: ui.fmt("strike") }
        IconBtn { width: 28; height: 28; icon: "code"; onClicked: ui.fmt("code") }
        IconBtn { width: 28; height: 28; icon: "link"; onClicked: ui.fmt("link") }
        Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.outline; opacity: 0.4 }
        IconBtn { width: 28; height: 28; icon: "format_list_bulleted"; onClicked: ui.fmt("bullet") }
        IconBtn { width: 28; height: 28; icon: "checklist"; onClicked: ui.fmt("task") }
        IconBtn { width: 28; height: 28; icon: "format_quote"; onClicked: ui.fmt("quote") }
        IconBtn { width: 28; height: 28; icon: "format_indent_decrease"; onClicked: ui.fmt("outdent") }
        IconBtn { width: 28; height: 28; icon: "format_indent_increase"; onClicked: ui.fmt("indent") }
    }
    IconBtn {
        width: 28
        height: 28
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        icon: "search"
        active: ui.findOpen
        onClicked: ui.findOpen ? ui.closeFind() : ui.openFind(false)
    }
}
