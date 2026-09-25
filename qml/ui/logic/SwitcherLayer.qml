import QtQuick
import "../../../js/markdown.js" as Md
import "../../../js/fuzzy.js" as Fuzzy
import "../../../js/commands.js" as Commands
import "../../../js/slash.js" as Slash

// Panel logic, part 5: quick switcher / command palette / template + folder pickers, `[[` and `/` autocomplete,
// outline / links / backlinks data for the right panel, cheat sheet rows.
SidebarLayer {
    id: ui

    property bool switcherOpen: false
    property var switcherResults: []
    property int switcherIndex: 0
    property bool acOpen: false
    property string acKind: "link"
    property var acItems: []
    property int acIndex: 0
    property point acPos: Qt.point(0, 0)
    property var outline: []
    property var props: []
    property var noteLinks: []
    readonly property var backlinkRows: flattenBacklinks(core.backlinks)

    function noteItems() {
        return core.entries.filter(e => e.type === "file").map(e => ({ name: core.noteTitleOf(e.path), path: e.path, folder: core.parentOf(e.path) }));
    }

    // recent notes first, then A-Z
    function orderedItems() {
        const rank = {};
        core.recent.forEach((r, i) => { rank[r] = i; });
        return noteItems().sort((a, b) => (a.path in rank ? rank[a.path] : 1e6) - (b.path in rank ? rank[b.path] : 1e6) || a.name.localeCompare(b.name));
    }

    // Name to write inside [[ ]]: the plain name, or folder/name when two notes share it.
    function insertName(item) {
        const clash = noteItems().filter(x => x.name.toLowerCase() === item.name.toLowerCase()).length > 1;
        return clash ? item.path.replace(/\.md$/i, "") : item.name;
    }

    property string moveSource: ""   // non-empty: the switcher picks a destination folder for this path
    property string switcherMode: "notes"   // notes | commands | template-insert | template-new
    property bool cheatOpen: false

    readonly property var cheatRows: {
        const rows = [];
        Commands.cheatSheet().forEach(g => {
            rows.push({ header: g.group });
            g.items.forEach(i => rows.push(i));
        });
        return rows;
    }

    function openPalette() {
        if (!core.vaultReady)
            return;
        moveSource = "";
        switcherMode = "commands";
        switcherField.text = "";
        updateSwitcher();
        switcherOpen = true;
        Qt.callLater(() => switcherField.forceActiveFocus());
    }

    function openTemplatePicker(kind) {
        if (core.templates().length === 0) {
            core.toast("No templates yet: add notes to the \"" + core.cfg.templatesFolder + "\" folder", true);
            return;
        }
        moveSource = "";
        switcherMode = "template-" + kind;
        switcherField.text = "";
        updateSwitcher();
        switcherOpen = true;
        Qt.callLater(() => switcherField.forceActiveFocus());
    }

    function runCommand(id) {
        switch (id) {
        case "new-note": core.newNote(); break;
        case "new-from-template": openTemplatePicker("new"); break;
        case "insert-template": openTemplatePicker("insert"); break;
        case "daily": core.openDaily(); break;
        case "capture": core.close(); core.captureVisible = true; break;
        case "switcher": openSwitcher(); break;
        case "rename": focusTitle(); break;
        case "pin": core.togglePin(core.noteRel); break;
        case "delete": askDelete(core.noteRel, "file"); break;
        case "toggle-view": core.cycleViewMode(); break;
        case "right-panel": core.setRightPanel(!core.rightPanel); break;
        case "toolbar": core.toggleToolbar(); break;
        case "toggle-sidebar": core.toggleSidebar(); break;
        case "expand-window": if (core.windowMode === "window") core.dockAgain(); else core.expandToWindow(); break;
        case "properties": core.toggleProps(); break;
        case "search": openSearch(); break;
        case "tags": core.setSidebarTab("tags"); break;
        case "files": toggleTree(); break;
        case "back": core.goBack(); break;
        case "forward": core.goForward(); break;
        case "new-tab": core.newTab(); break;
        case "close-tab": core.closeTab(core.tabState.active); break;
        case "find": openFind(false); break;
        case "replace": openFind(true); break;
        case "undo-rename": core.undoRename(); break;
        case "add-vault": addVault(); break;
        case "palette": openPalette(); break;
        case "cheatsheet": cheatOpen = true; break;
        }
    }

    function folderItems() {
        const src = moveSource;
        const out = [{ name: "Vault root", path: "", folder: "" }];
        core.entries.filter(e => e.type === "dir" && e.path !== src && e.path.indexOf(src + "/") !== 0 && e.path !== core.parentOf(src)).forEach(e => out.push({ name: e.path.split("/").pop(), path: e.path, folder: core.parentOf(e.path) }));
        return core.parentOf(src) === "" ? out.slice(1) : out;
    }

    function askMove(path) {
        if (!core.vaultReady)
            return;
        moveSource = path;
        switcherField.text = "";
        updateSwitcher();
        switcherMode = "notes";
        switcherOpen = true;
        Qt.callLater(() => switcherField.forceActiveFocus());
    }

    function openSwitcher() {
        if (!core.vaultReady)
            return;
        moveSource = "";
        switcherMode = "notes";
        switcherField.text = "";
        updateSwitcher();
        switcherOpen = true;
        Qt.callLater(() => switcherField.forceActiveFocus());
    }

    function closeSwitcher() {
        switcherOpen = false;
        moveSource = "";
        switcherMode = "notes";
        focusEditor();
    }

    function updateSwitcher() {
        const q = switcherField.text.trim();
        if (switcherMode === "commands") {
            switcherResults = Commands.filter(q, !!core.noteRel).map(c => ({ kind: "command", item: { name: c.title, folder: c.keys, id: c.id }, positions: [] }));
            switcherIndex = 0;
            return;
        }
        if (switcherMode.indexOf("template-") === 0) {
            switcherResults = Fuzzy.rank(core.templates().map(t => ({ name: t.name, path: t.path, folder: "" })), q, 30).map(r => ({ kind: "template", item: r.item, positions: r.positions }));
            switcherIndex = 0;
            return;
        }
        if (moveSource) {
            switcherResults = Fuzzy.rank(folderItems(), q, 30).map(r => ({ kind: "folder", item: r.item, positions: r.positions }));
            switcherIndex = 0;
            return;
        }
        const ranked = Fuzzy.rank(orderedItems(), q, 30);
        const rows = ranked.map(r => ({ kind: "note", item: r.item, positions: r.positions }));
        if (q && !ranked.some(r => r.item.name.toLowerCase() === q.toLowerCase()))
            rows.push({ kind: "create", name: q });
        switcherResults = rows;
        switcherIndex = 0;
    }

    function switcherAccept(newTab) {
        const row = switcherResults[switcherIndex];
        if (!row)
            return;
        const moving = moveSource;
        const mode = switcherMode;
        closeSwitcher();
        if (row.kind === "command") {
            Qt.callLater(() => runCommand(row.item.id));
            return;
        }
        if (row.kind === "template") {
            if (mode === "template-insert")
                core.useTemplate(row.item.path);
            else
                Qt.callLater(() => ask({ title: "New note from template", input: true, confirm: "Create", value: "Untitled", action: name => core.newFromTemplate(row.item.path, name) }));
            return;
        }
        if (row.kind === "folder")
            core.moveEntry(moving, row.item.path);
        else if (row.kind === "note")
            core.openNote(row.item.path, newTab);
        else
            core.createNamed(row.name);
    }

    function updateAutocomplete() {
        if (syncing || core.viewMode === "preview" || !core.noteRel || !editor.focus) {
            acOpen = false;
            return;
        }
        let sctx = Slash.context(editor.text, editor.cursorPosition);
        if (sctx && (editor.text.slice(0, sctx.start).match(/^\s*(```|~~~)/gm) || []).length % 2 === 1)
            sctx = null;   // inside a code fence
        if (sctx) {
            const items = Slash.filter(sctx.query).slice(0, 8);
            if (items.length === 0) {
                acOpen = false;
                return;
            }
            acKind = "slash";
            acItems = items.map(it => ({ id: it.id, name: it.title, folder: it.hint }));
            acIndex = 0;
            const sr = editor.cursorRectangle;
            acPos = editor.mapToItem(panelBg, sr.x, sr.y + sr.height + 4);
            acOpen = true;
            return;
        }
        acKind = "link";
        const ctx = Md.linkContext(editor.text, editor.cursorPosition);
        if (!ctx) {
            acOpen = false;
            return;
        }
        const ranked = Fuzzy.rank(orderedItems(), ctx.query, 8);
        if (ranked.length === 0) {
            acOpen = false;
            return;
        }
        acItems = ranked.map(r => r.item);
        acIndex = 0;
        const r = editor.cursorRectangle;
        acPos = editor.mapToItem(panelBg, r.x, r.y + r.height + 4);
        acOpen = true;
    }

    function acAccept() {
        const it = acItems[acIndex];
        acOpen = false;
        if (!it)
            return;
        if (acKind === "slash") {
            const t = editor.text;
            const cur = editor.cursorPosition;
            const sctx = Slash.context(t, cur);
            if (!sctx)
                return;
            if (it.id === "template") {
                applyEdit({ start: sctx.start, end: cur, text: "", selStart: sctx.start, selEnd: sctx.start });
                openTemplatePicker("insert");
                return;
            }
            const r = Slash.apply(t, cur, it.id, sctx, new Date());
            applyEdit({ start: sctx.start, end: cur, text: r.text.slice(sctx.start, r.text.length - (t.length - cur)), selStart: r.cursor, selEnd: r.cursor });
            return;
        }
        const ed = Md.completeLink(editor.text, editor.cursorPosition, insertName(it));
        if (ed)
            applyEdit(ed);
    }

    function refreshNav() {
        props = Md.parseFrontmatter(core.buffer).props;
        outline = Md.extractHeadings(core.buffer);
        const seen = {};
        const out = [];
        Md.extractLinks(core.buffer).forEach(l => {
            const k = l.name.toLowerCase() + "#" + l.heading.toLowerCase();
            if (seen[k] === undefined) {
                seen[k] = out.length;
                out.push({ name: l.name, heading: l.heading, count: 1, resolved: core.resolveNote(l.name) !== null });
            } else {
                out[seen[k]].count++;
            }
        });
        noteLinks = out;
    }

    readonly property Timer navTimer: Timer {
        interval: 200
        onTriggered: ui.refreshNav()
    }

    function flattenBacklinks(list) {
        const rows = [];
        const byPath = {};
        list.forEach(b => {
            if (byPath[b.path] === undefined) {
                byPath[b.path] = rows.length;
                rows.push({ kind: "file", path: b.path, count: 0 });
            }
            rows[byPath[b.path]].count++;
        });
        const out = [];
        rows.forEach(f => {
            out.push(f);
            list.filter(b => b.path === f.path).forEach(b => out.push({ kind: "line", path: b.path, line: b.line, text: b.text.trim() }));
        });
        return out;
    }

    function jumpToOffset(off) {
        const frac = core.buffer.length > 0 ? off / core.buffer.length : 0;
        if (core.viewMode !== "edit")
            previewFlick.contentY = Math.max(0, Math.min(Math.max(0, previewFlick.contentHeight - previewFlick.height), frac * previewFlick.contentHeight - 20));
        if (core.viewMode !== "preview") {
            editor.forceActiveFocus();
            editor.cursorPosition = Math.max(0, Math.min(off, editor.text.length));
            Qt.callLater(() => {
                flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), editor.cursorRectangle.y - 16));
            });
        }
    }
}
