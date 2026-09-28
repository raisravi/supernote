import QtQuick
import Quickshell
import qs.Modals.FileBrowser

// Panel logic, part 1 of 7 (base): dialogs (`ask`), focus helpers, global key handling (`handleKey`), vault chooser.
// The panel is a chain of QML types -- PanelBase -> EditingLayer -> FindLayer -> SidebarLayer -> SwitcherLayer ->
// PreviewLayer -> SyncLayer -> SuperNotePanel -- that share one object; the visual parts are components (see docs/ARCHITECTURE.md).
// All state and file operations live in the core controller (`core`).
Item {
    id: ui

    required property var core

    property bool browsing: false
    property var ctx: null          // context menu target {path, type, x, y}
    property bool vaultMenuOpen: false
    property string treeAction: ""
    property string dlgTitle: ""
    property string dlgMessage: ""
    property bool dlgInput: false
    property string dlgConfirm: "OK"
    property bool dlgDanger: false
    property var dlgAction: null
    property string dlgAlt: ""
    property var dlgAltAction: null
    property var dlgCancelAction: null
    property bool dlgOpen: false

    function ask(opts) {
        dlgTitle = opts.title || "";
        dlgMessage = opts.message || "";
        dlgInput = !!opts.input;
        dlgConfirm = opts.confirm || "OK";
        dlgDanger = !!opts.danger;
        dlgAction = opts.action || null;
        dlgAlt = opts.alt || "";
        dlgAltAction = opts.altAction || null;
        dlgCancelAction = opts.cancelAction || null;
        dlgField.text = opts.value || "";
        dlgOpen = true;
        Qt.callLater(() => {
            if (dlgInput) {
                dlgField.forceActiveFocus();
                dlgField.selectAll();
            } else {
                dlgScope.forceActiveFocus();
            }
        });
    }

    function dlgAccept() {
        const action = dlgAction;
        const value = dlgField.text.trim();
        dlgOpen = false;
        focusEditor();
        if (action)
            action(value);
    }

    function dlgCancel() {
        const action = dlgCancelAction;
        dlgOpen = false;
        focusEditor();
        if (action)
            action();
    }

    function dlgAccept2() {
        const action = dlgAltAction;
        dlgOpen = false;
        focusEditor();
        if (action)
            action();
    }

    function focusEditor() {
        if (core.noteRel && core.viewMode !== "preview")
            editor.forceActiveFocus();
        else
            keys.forceActiveFocus();
    }

    function focusTitle() {
        titleInput.forceActiveFocus();
        titleInput.selectAll();
    }

    // Ctrl+Shift+E: show the left panel and focus the tree; pressed again (tree focused) it hides the panel.
    function toggleTree() {
        if (core.showSidebar && core.sidebarTab === "files" && tree.activeFocus) {
            core.setSidebar(false);
            focusEditor();
        } else {
            focusTree();
        }
    }

    function focusTree() {
        core.setSidebarTab("files");
        Qt.callLater(() => tree.forceActiveFocus());   // the sidebar may only just have become visible
    }

    function askNewFolder(dir) {
        ask({
            title: "New folder",
            input: true,
            confirm: "Create",
            action: name => {
                if (name)
                    core.newFolder(dir, name);
            }
        });
    }

    function askRename(path, type) {
        ask({
            title: type === "dir" ? "Rename folder" : "Rename note",
            input: true,
            confirm: "Rename",
            value: type === "dir" ? path.split("/").pop() : core.noteTitleOf(path),
            action: name => {
                if (name)
                    core.renameEntry(path, name);
            }
        });
    }

    function askDelete(path, type) {
        ask({
            title: type === "dir" ? "Delete folder?" : "Delete note?",
            message: "\"" + path.split("/").pop() + "\" will be moved to the trash." + (type === "dir" ? " Everything inside it goes too." : ""),
            confirm: "Move to trash",
            danger: true,
            action: () => core.trashEntry(path)
        });
    }

    function commitTitle() {
        const t = titleInput.text.trim();
        if (!core.noteRel || t === core.noteTitle)
            return;
        if (!t) {
            titleInput.text = core.noteTitle;
            return;
        }
        core.renameEntry(core.noteRel, t, ok => {
            if (!ok)
                titleInput.text = core.noteTitle;
        });
    }

    function wordCount(text) {
        const t = text.trim();
        return t ? t.split(/\s+/).length : 0;
    }

    function handleKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        if (event.key === Qt.Key_Escape) {
            if (cheatOpen) {
                cheatOpen = false;
            } else if (switcherOpen) {
                closeSwitcher();
            } else if (findOpen) {
                closeFind();
            } else if (ctx) {
                ctx = null;
            } else if (vaultMenuOpen) {
                vaultMenuOpen = false;
            } else if (titleInput.activeFocus && core.noteRel) {
                titleInput.text = core.noteTitle;
                editor.forceActiveFocus();
            } else {
                core.close();
            }
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_N) {
            core.newNote();
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_S) {
            core.saveNow();
            event.accepted = true;
        } else if (event.key === Qt.Key_F2 && core.noteRel) {
            focusTitle();
            event.accepted = true;
        } else if (ctrl && shift && event.key === Qt.Key_E) {
            toggleTree();
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_Backslash) {
            core.toggleSidebar();
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_O) {
            openSwitcher();
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_P) {
            openPalette();
            event.accepted = true;
        } else if (ctrl && event.key === Qt.Key_Slash) {
            cheatOpen = !cheatOpen;
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_T) {
            core.newTab();
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_W) {
            core.closeTab(core.tabState.active);
            event.accepted = true;
        } else if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)) {
            core.cycleTab(event.key === Qt.Key_Backtab || event.key === Qt.Key_PageUp || shift ? -1 : 1);
            event.accepted = true;
        } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Left) {
            core.goBack();
            event.accepted = true;
        } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Right) {
            core.goForward();
            event.accepted = true;
        } else if (alt && !ctrl && !shift && (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) && !keys.inWindow) {
            core.setDockWidth(core.dockWidth + core.dockWidthStep);
            event.accepted = true;
        } else if (alt && !ctrl && !shift && event.key === Qt.Key_Minus && !keys.inWindow) {
            core.setDockWidth(core.dockWidth - core.dockWidthStep);
            event.accepted = true;
        } else if (ctrl && shift && event.key === Qt.Key_F) {
            openSearch();
            event.accepted = true;
        } else if (ctrl && shift && event.key === Qt.Key_B) {
            core.setRightPanel(!core.rightPanel);
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_E && core.noteRel) {
            core.cycleViewMode();
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_F) {
            openFind(false);
            event.accepted = true;
        } else if (ctrl && !shift && event.key === Qt.Key_H) {
            openFind(true);
            event.accepted = true;
        } else if (core.viewMode === "preview" && core.noteRel && !ctrl) {
            const step = event.key === Qt.Key_Down ? 60 : (event.key === Qt.Key_Up ? -60 : (event.key === Qt.Key_PageDown ? previewFlick.height * 0.9 : (event.key === Qt.Key_PageUp ? -previewFlick.height * 0.9 : 0)));
            if (step !== 0) {
                previewFlick.contentY = Math.max(0, Math.min(previewFlick.contentHeight - previewFlick.height, previewFlick.contentY + step));
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                previewFlick.contentY = 0;
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                previewFlick.contentY = Math.max(0, previewFlick.contentHeight - previewFlick.height);
                event.accepted = true;
            }
        }
    }

    LazyLoader {
        id: vaultBrowser
        active: false
        FileBrowserModal {
            browserTitle: "Choose a vault folder"
            browserIcon: "folder_open"
            browserType: "generic"
            folderMode: true
            showHiddenFiles: false
            onFileSelected: path => {
                ui.browsing = false;
                ui.core.activateVault(path);
                close();
            }
            onDialogClosed: ui.browsing = false
        }
    }

    function addVault() {
        vaultMenuOpen = false;
        browsing = true;
        vaultBrowser.active = true;
        if (vaultBrowser.item)
            vaultBrowser.item.open();
    }

    function activateRow(row, newTab) {
        if (row.type === "hdr") {
            if (row.key !== "files")
                core.toggleSection(row.key);
            return;
        }
        core.selectedPath = row.path;
        if (row.type === "dir")
            core.toggleDir(row.path);
        else
            core.openNote(row.path, !!newTab);
    }
}
