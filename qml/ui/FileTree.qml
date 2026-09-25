import QtQuick
import qs.Common
import qs.Widgets

// File tree ListView: pinned/recent sections and the folder tree (ui.core.sideList). Keyboard: arrows, Enter, F2, Delete.
// Inputs: ui. The host anchors it below the sidebar tabs. Exposes the list view (`list`) for focusing.
ListView {
    id: tree
    required property var ui

    visible: ui.core.sidebarTab === "files"
    clip: true
    model: ui.core.sideList
    spacing: 1
    currentIndex: -1
    boundsBehavior: Flickable.StopAtBounds

    function indexOfPath(p) {
        for (let i = 0; i < ui.core.sideList.length; i++)
            if (ui.core.sideList[i].path === p)
                return i;
        return -1;
    }

    Keys.onPressed: event => {
        const row = ui.core.sideList[tree.currentIndex];
        if (event.key === Qt.Key_Down) {
            tree.currentIndex = Math.min(tree.currentIndex + 1, ui.core.sideList.length - 1);
        } else if (event.key === Qt.Key_Up) {
            tree.currentIndex = Math.max(tree.currentIndex - 1, 0);
        } else if (row && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            ui.activateRow(row);
        } else if (row && event.key === Qt.Key_Right && row.type === "dir" && !row.expanded) {
            ui.core.toggleDir(row.path);
        } else if (row && event.key === Qt.Key_Left && row.type === "dir" && row.expanded) {
            ui.core.toggleDir(row.path);
        } else if (row && row.type !== "hdr" && event.key === Qt.Key_Delete) {
            ui.askDelete(row.path, row.type);
        } else if (row && row.type !== "hdr" && row.type !== "pin" && row.type !== "recent" && event.key === Qt.Key_F2) {
            ui.askRename(row.path, row.type);
        } else if (event.key === Qt.Key_Escape) {
            ui.focusEditor();
        } else {
            return;
        }
        if (tree.currentIndex >= 0 && ui.core.sideList[tree.currentIndex] && ui.core.sideList[tree.currentIndex].path)
            ui.core.selectedPath = ui.core.sideList[tree.currentIndex].path;
        event.accepted = true;
    }

    onActiveFocusChanged: {
        if (activeFocus && currentIndex < 0)
            currentIndex = Math.max(indexOfPath(ui.core.selectedPath), 0);
    }

    delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property bool isDir: modelData.type === "dir"
        readonly property bool isHdr: modelData.type === "hdr"
        readonly property bool isShortcut: modelData.type === "pin" || modelData.type === "recent"
        readonly property bool isSelected: modelData.path === ui.core.selectedPath
        readonly property bool isCurrent: modelData.path === ui.core.noteRel
        width: ListView.view.width
        height: isHdr ? 26 : 30
        radius: 6
        color: isCurrent ? Theme.primaryContainer : (isSelected ? Theme.surfaceContainerHigh : (rowMouse.containsMouse ? Theme.surfaceContainer : "transparent"))
        border.width: tree.activeFocus && tree.currentIndex === index ? 1 : 0
        border.color: Theme.primary

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 6 + modelData.depth * 16
            spacing: 4
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: row.isHdr ? (modelData.open ? "expand_more" : "chevron_right") : (row.isDir ? (modelData.expanded ? "expand_more" : "chevron_right") : "chevron_right")
                size: 16
                color: Theme.surfaceVariantText
                opacity: row.isDir || (row.isHdr && modelData.key !== "files") ? 1 : 0
            }
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.isHdr
                name: row.isDir ? (modelData.expanded ? "folder_open" : "folder") : (modelData.type === "pin" ? "push_pin" : (modelData.type === "recent" ? "history" : "description"))
                size: 16
                color: row.isDir ? Theme.primary : Theme.surfaceVariantText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - 6 - modelData.depth * 16 - 16 - 16 - 16
                text: row.isHdr ? modelData.name.toUpperCase() + (modelData.count ? "  " + modelData.count : "") : modelData.name + (row.isShortcut && modelData.hint ? "   " + modelData.hint : "")
                elide: Text.ElideRight
                color: row.isHdr || (row.isShortcut && false) ? Theme.surfaceVariantText : Theme.surfaceText
                font.pixelSize: row.isHdr ? Theme.fontSizeSmall : Theme.fontSizeMedium
                font.weight: row.isHdr ? Font.DemiBold : Font.Normal
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                ui.vaultMenuOpen = false;
                if (mouse.button === Qt.RightButton) {
                    if (row.isHdr)
                        return;
                    ui.core.selectedPath = modelData.path;
                    const p = rowMouse.mapToItem(ui.panelBg, mouse.x, mouse.y);
                    ui.ctx = { path: modelData.path, type: row.isShortcut ? "file" : modelData.type, x: p.x, y: p.y };
                } else {
                    ui.ctx = null;
                    tree.currentIndex = index;
                    ui.activateRow(modelData, (mouse.modifiers & Qt.ControlModifier) !== 0);
                }
            }
        }
    }

    readonly property var list: tree
}
