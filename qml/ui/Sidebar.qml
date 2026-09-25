import QtQuick
import qs.Common
import qs.Widgets

// Left panel: Files / Search / Tags tabs and the three panes. Inputs: ui. The host anchors it below the header line.
// Exposes the tree list view and the search field for focusing.
Item {
    id: sidebar
    required property var ui
    visible: ui.core.showSidebar
    anchors.bottom: parent.bottom
    width: ui.core.showSidebar ? 280 : 0

    Row {
        id: sideTabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 30
        spacing: 4
        Repeater {
            model: [{ k: "files", i: "folder", t: "Files" }, { k: "search", i: "search", t: "Search" }, { k: "tags", i: "sell", t: "Tags" }]
            Rectangle {
                required property var modelData
                readonly property bool on: ui.core.sidebarTab === modelData.k
                width: (sideTabs.width - 8) / 3
                height: 30
                radius: 8
                color: on ? Theme.primaryContainer : (sideTabMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.i
                        size: 16
                        color: on ? Theme.surfaceText : Theme.surfaceVariantText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.t
                        color: on ? Theme.surfaceText : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                MouseArea {
                    id: sideTabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.k === "search")
                            ui.openSearch();
                        else
                            ui.core.setSidebarTab(modelData.k);
                    }
                }
            }
        }
    }

    FileTree {
        id: fileTree
        ui: sidebar.ui
        anchors.top: sideTabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
    }

    SearchPane {
        id: searchPane
        ui: sidebar.ui
        anchors.top: sideTabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
    }

    TagsPane {
        id: tagsPane
        ui: sidebar.ui
        anchors.top: sideTabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
    }

    StyledText {
        anchors.centerIn: parent
        visible: ui.core.vaultReady && ui.core.rows.length === 0 && ui.core.sidebarTab === "files"
        text: "This vault is empty.\nCtrl+N creates a note."
        horizontalAlignment: Text.AlignHCenter
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
    }

    readonly property var tree: fileTree.list
    readonly property var searchField: searchPane.field
}
