import QtQuick
import qs.Common
import qs.Widgets
import "widgets"

// Right-click menu of a tree row (new note/folder, rename, pin, move, delete). Inputs: ui (ctx = target + position).
Rectangle {
    required property var ui

    visible: ui.ctx !== null
    x: ui.ctx ? Math.min(ui.ctx.x, ui.panelBg.width - width - 8) : 0
    y: ui.ctx ? Math.min(ui.ctx.y, ui.panelBg.height - height - 8) : 0
    z: 60
    width: 200
    height: ctxCol.implicitHeight + 12
    radius: 10
    color: Theme.surfaceContainerHigh
    border.width: 1
    border.color: Theme.outline
    Column {
        id: ctxCol
        x: 6
        y: 6
        width: parent.width - 12
        spacing: 2
        MenuItem {
            label: "New note here"
            icon: "note_add"
            onTriggered: {
                const c = ui.ctx;
                ui.ctx = null;
                ui.core.newNote(c.type === "dir" ? c.path : ui.core.parentOf(c.path));
            }
        }
        MenuItem {
            label: "New folder here"
            icon: "create_new_folder"
            onTriggered: {
                const c = ui.ctx;
                ui.ctx = null;
                ui.askNewFolder(c.type === "dir" ? c.path : ui.core.parentOf(c.path));
            }
        }
        MenuItem {
            label: "Rename"
            icon: "edit"
            onTriggered: {
                const c = ui.ctx;
                ui.ctx = null;
                ui.askRename(c.path, c.type);
            }
        }
        MenuItem {
            visible: ui.ctx && ui.ctx.type !== "dir"
            label: ui.ctx && ui.core.pins.indexOf(ui.ctx.path) >= 0 ? "Unpin" : "Pin to top"
            icon: "push_pin"
            onTriggered: {
                const c = ui.ctx;
                ui.ctx = null;
                ui.core.togglePin(c.path);
            }
        }
        MenuItem {
            label: "Move to…"
            icon: "drive_file_move"
            onTriggered: {
                const c = ui.ctx;
                ui.ctx = null;
                ui.askMove(c.path);
            }
        }
        MenuItem {
            label: "Delete"
            icon: "delete"
            danger: true
            onTriggered: {
                const c = ui.ctx;
                ui.ctx = null;
                ui.askDelete(c.path, c.type);
            }
        }
    }
}
