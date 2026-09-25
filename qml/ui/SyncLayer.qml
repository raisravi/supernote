import QtQuick
import "../../js/markdown.js" as Md

// Panel logic, part 7: keeps the editor in step with the core (note loaded, buffer changed, jumps, prompts).
PreviewLayer {
    id: ui

    Connections {
        target: ui.core
        function onLoadSerialChanged() {
            ui.syncing = true;
            editor.text = ui.core.buffer;
            ui.syncing = false;
            const v = ui.core.activeTabView();
            editor.cursorPosition = v ? Math.min(v.cursor, editor.text.length) : 0;
            Qt.callLater(() => { flick.contentY = v ? v.scroll : 0; });
            titleInput.text = ui.core.noteTitle;
            ui.acOpen = false;
            ui.refreshNav();
            ui.coloringOk = true;
            ui.refreshHighlight();
            ui.updateCursorInfo();
            ui.refreshPreview();
        }
        function onEditorSetSerialChanged() {
            const pos = editor.cursorPosition;
            ui.syncing = true;
            editor.text = ui.core.buffer;
            ui.syncing = false;
            editor.cursorPosition = Math.min(pos, editor.text.length);
        }
        function onBufferChanged() {
            navTimer.restart();
            if (ui.core.viewMode !== "edit")
                previewTimer.restart();
        }
        function onMovePromptChanged() {
            const p = ui.core.movePrompt;
            if (!p)
                return;
            const n = p.plan.links;
            const m = p.plan.notes;
            ui.ask({
                title: "Update links?",
                message: n + " link" + (n === 1 ? "" : "s") + " in " + m + " note" + (m === 1 ? "" : "s") + " point to \"" + p.plan.from.split("/").pop().replace(/\.md$/, "") + "\". Update " + (n === 1 ? "it" : "them") + " so nothing breaks? (Originals are kept; the vault menu has \"Undo\".)" + (p.plan.unread ? " " + p.plan.unread + " linking note" + (p.plan.unread === 1 ? "" : "s") + " could not be read (not UTF-8 or too large) and will keep the old link." : ""),
                confirm: "Update links",
                alt: "Rename only",
                action: () => ui.core.answerMove("update"),
                altAction: () => ui.core.answerMove("only"),
                cancelAction: () => ui.core.answerMove("cancel")
            });
        }
        function onInsertTemplate(text, cursor) {
            const p = editor.selectionStart;
            const c = cursor >= 0 ? p + cursor : p + text.length;
            ui.applyEdit({ start: p, end: editor.selectionEnd, text: text, selStart: c, selEnd: c });
            ui.focusEditor();
        }
        function onJumpOffset(off) {
            ui.jumpToOffset(off);
        }
        function onCommandRequest(id) {
            ui.runCommand(id);
        }
        function onSearchRequest(q) {
            ui.openSearch();
            searchField.text = q;
            ui.core.search(q);
        }
        function onJumpLine(line) {
            const lines = ui.core.buffer.split("\n");
            let off = 0;
            for (let i = 0; i < Math.min(line - 1, lines.length - 1); i++)
                off += lines[i].length + 1;
            ui.jumpToOffset(off);
        }
        function onJumpHeading(heading) {
            const off = Md.headingOffset(ui.core.buffer, heading);
            if (off >= 0)
                ui.jumpToOffset(off);
            else
                ui.core.toast("Heading \"" + heading + "\" not found in this note");
        }
        function onEmbedSerialChanged() {
            if (ui.core.viewMode !== "edit")
                previewTimer.restart();
        }
        function onViewModeChanged() {
            ui.refreshPreview();
            Qt.callLater(ui.focusEditor);
        }
        function onNoteRelChanged() {
            if (!titleInput.activeFocus)
                titleInput.text = ui.core.noteTitle;
        }
        function onFocusSerialChanged() {
            if (!ui.core.panelVisible)
                return;
            if (ui.core.focusTarget === "title")
                ui.focusTitle();
            else
                ui.focusEditor();
        }
        function onWindowModeChanged() {
            Qt.callLater(ui.focusEditor);
        }
        function onPanelVisibleChanged() {
            if (ui.core.panelVisible) {
                ui.vaultMenuOpen = false;
                ui.ctx = null;
                ui.cheatOpen = false;    // overlays do not survive a close / reopen
                ui.switcherOpen = false;
                ui.moveSource = "";
                ui.switcherMode = "notes";
                ui.dlgOpen = false;
                Qt.callLater(ui.focusEditor);
            }
        }
    }

    Component.onCompleted: {
        syncing = true;
        editor.text = core.buffer;
        syncing = false;
        titleInput.text = core.noteTitle;
    }
}
