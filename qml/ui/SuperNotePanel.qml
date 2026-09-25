import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.FileBrowser
import "../../js/markdown.js" as Md
import "../../js/previewhtml.js" as Html
import "../../js/fuzzy.js" as Fuzzy
import "../../js/tabs.js" as Tabs
import "../../js/tags.js" as Tags
import "../../js/search.js" as Search
import "../../js/commands.js" as Commands
import "../../js/slash.js" as Slash
import "../../js/mdkeys.js" as MdKeys

// SuperNote UI (milestone 1: vault tree + monospace editor + inline title).
// All state and file operations live in core (SuperNote.qml).
Item {
    id: ui

    required property var core

    property bool browsing: false
    property var ctx: null          // context menu target {path, type, x, y}
    property bool vaultMenuOpen: false
    property string treeAction: ""

    // --- small building blocks --------------------------------------------------------
    component IconBtn: Rectangle {
        id: btn
        property string icon: ""
        property string tip: ""
        property bool active: false
        signal clicked
        width: 32
        height: 32
        radius: 8
        color: mouse.containsMouse ? Theme.surfaceContainerHigh : (active ? Theme.primaryContainer : "transparent")
        DankIcon {
            anchors.centerIn: parent
            name: btn.icon
            size: 18
            color: Theme.surfaceText
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component MenuItem: Rectangle {
        id: item
        property string label: ""
        property string icon: ""
        property bool danger: false
        signal triggered
        width: parent ? parent.width : 200
        height: 32
        radius: 6
        color: itemMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 8
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: item.icon
                size: 16
                color: item.danger ? Theme.error : Theme.surfaceVariantText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: item.label
                color: item.danger ? Theme.error : Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }
        }
        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.triggered()
        }
    }

    // --- dialogs / actions ---------------------------------------------------------------
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


    // --- markdown editing ---------------------------------------------------------------------
    property bool coloringOk: true
    property string hlHtml: ""
    property int cursorLine: 1
    property int cursorCol: 1
    property string previewHtml: ""
    property var previewProps: []
    property bool findOpen: false
    property bool replaceOpen: false
    property bool findCase: false
    property bool findRegex: false
    property var matches: []
    property int matchIndex: -1

    readonly property var hlColors: ({
            heading: Theme.primary.toString(),
            bold: Theme.surfaceText.toString(),
            italic: Theme.surfaceText.toString(),
            code: Theme.secondary.toString(),
            codeBlock: Theme.secondary.toString(),
            link: Theme.primary.toString(),
            wikilink: Theme.primary.toString(),
            tag: Theme.secondary.toString(),
            quote: Theme.surfaceVariantText.toString(),
            marker: Theme.primary.toString(),
            dim: Theme.surfaceVariantText.toString(),
            strike: Theme.surfaceVariantText.toString(),
            task: Theme.primary.toString(),
            highlight: Theme.warning.toString()
        })
    function tint(c) {
        return Qt.tint(Theme.surface, Qt.rgba(c.r, c.g, c.b, 0.22)).toString();
    }

    readonly property var previewColors: ({
            link: Theme.primary.toString(),
            highlight: tint(Theme.warning),
            mono: Theme.monoFontFamily,
            codeText: Theme.secondary.toString(),
            codeBg: Theme.surfaceContainerHigh.toString(),
            quoteBar: Theme.outline.toString(),
            border: Theme.outline.toString(),
            headBg: Theme.surfaceContainerHigh.toString(),
            calloutNote: tint(Theme.primary),
            calloutWarn: tint(Theme.warning),
            calloutDanger: tint(Theme.error),
            calloutOk: tint(Theme.success),
            calloutTip: tint(Theme.secondary)
        })
    onPreviewColorsChanged: refreshPreview()
    onHlColorsChanged: refreshHighlight()

    function refreshHighlight() {
        const t = editor.text;
        if (!coloringOk || t.length > 200000) {
            hlHtml = "";
            return;
        }
        hlHtml = '<div style="white-space: pre-wrap;">' + Md.highlightHtml(t, hlColors) + (t.endsWith("\n") ? "&#8203;" : "") + "</div>";
        Qt.callLater(checkAlignment);
    }

    // If the colored layer and the real text ever disagree on height (wrapping differences),
    // fall back to plain text rather than show misaligned colors.
    function checkAlignment() {
        if (!coloringOk || !hlHtml)
            return;
        if (Math.abs(underlay.contentHeight - editor.contentHeight) > 4) {
            coloringOk = false;
            hlHtml = "";
        }
    }

    function updateCursorInfo() {
        const p = editor.cursorPosition;
        const before = editor.text.slice(0, p);
        cursorLine = before.split("\n").length;
        cursorCol = p - before.lastIndexOf("\n");
    }

    function applyEdit(ed) {
        MdKeys.applyEdit(editor, ed);
    }

    function fmt(name) {
        const ed = MdKeys.format(name, editor.text, editor.selectionStart, editor.selectionEnd);
        if (ed) {
            editor.forceActiveFocus();
            applyEdit(ed);
        }
    }

    // Ctrl+V: an image-only clipboard becomes an attachment + ![[embed]]; anything else pastes as text.
    function pasteFromClipboard() {
        core.run(["wl-paste", "--list-types"], (code, out) => {
            const types = out.split("\n");
            const image = types.some(t => t.indexOf("image/") === 0);
            const text = types.some(t => t.indexOf("text/") === 0);
            if (code === 0 && image && !text) {
                const target = core.noteRel;
                core.pasteImage(name => {
                    if (!name)
                        return;
                    if (core.noteRel !== target) {
                        core.toast("Image saved as " + name + " (you switched notes, so it was not inserted)");
                        return;
                    }
                    const p = editor.selectionStart;
                    applyEdit({ start: p, end: editor.selectionEnd, text: "![[" + name + "]]", selStart: p + name.length + 5, selEnd: p + name.length + 5 });
                });
            } else {
                editor.paste();
            }
        });
    }

    function editorKey(event) {
        if (acOpen) {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                acIndex = (acIndex + (event.key === Qt.Key_Down ? 1 : acItems.length - 1)) % acItems.length;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                acAccept();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                acOpen = false;
                event.accepted = true;
                return;
            }
        }
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        if (ctrl && !alt && !shift && event.key === Qt.Key_V) {
            pasteFromClipboard();
            event.accepted = true;
            return;
        }
        const ed = MdKeys.handle(editor.text, editor.selectionStart, editor.selectionEnd, { key: event.key, ctrl: ctrl, shift: shift, alt: alt, text: event.text });
        if (ed) {
            applyEdit(ed);
            event.accepted = true;
        } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && !ctrl && !alt) {
            event.accepted = true;   // Tab never leaves the editor (Ctrl+Tab still cycles tabs)
        }
    }

    // --- sidebar: search + tags --------------------------------------------------------------------
    property var searchCollapsed: ({})
    property string tagFilter: ""
    readonly property var searchRows: buildSearchRows(core.searchResults, core.searchQuery, searchCollapsed)
    readonly property var tagRows: buildTagRows(core.noteTags, core.tagExpanded, tagFilter, core.tagSelected)

    function buildSearchRows(results, query, collapsed) {
        const q = query.trim();
        if (q.length < 2)
            return [];
        const rows = [];
        Fuzzy.rank(noteItems(), q, 5).forEach(r => rows.push({ kind: "name", path: r.item.path, name: r.item.name, folder: r.item.folder }));
        Search.flatRows(Search.group(results), collapsed).forEach(r => rows.push(r));
        return rows;
    }

    function buildTagRows(index, expanded, filter, selected) {
        const out = [];
        Tags.rows(index, expanded, filter).forEach(r => {
            out.push({ kind: "tag", tag: r.tag, name: r.name, depth: r.depth, count: r.count, hasChildren: r.hasChildren, expanded: r.expanded, selected: r.tag === selected });
            if (r.tag === selected)
                Tags.notesFor(index, selected).forEach(p => out.push({ kind: "note", path: p, depth: r.depth + 1 }));
        });
        return out;
    }

    function openSearch() {
        core.setSidebarTab("search");
        Qt.callLater(() => {
            searchField.forceActiveFocus();
            searchField.selectAll();
        });
    }

    function toggleSearchFile(path) {
        const m = Object.assign({}, searchCollapsed);
        if (m[path])
            delete m[path];
        else
            m[path] = true;
        searchCollapsed = m;
    }

    // --- navigation: quick switcher, [[ autocomplete, right panel data --------------------------
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

    function commitProp(key, text, wasList) {
        if (core.conflict || core.noteLoading) {
            core.toast("Resolve the conflict in this note before editing its properties", true);
            return;
        }
        const asList = wasList || key === "tags" || key === "aliases" || key === "cssclasses";
        const value = asList ? text.split(",").map(x => x.trim().replace(/^#/, "")).filter(x => x.length) : text.trim();
        core.applyExternalText(Md.setProperty(core.buffer, key, value));
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

    Timer {
        id: navTimer
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

    // --- find / replace ---------------------------------------------------------------------
    function findOpts() {
        return { caseSensitive: findCase, regex: findRegex };
    }

    function openFind(withReplace) {
        if (!core.noteRel || core.viewMode === "preview")
            return;
        findOpen = true;
        if (withReplace)
            replaceOpen = true;
        const sel = editor.selectedText;
        if (sel.length > 0 && sel.indexOf("\n") < 0)
            findField.text = sel;
        recomputeMatches();
        findField.forceActiveFocus();
        findField.selectAll();
    }

    function closeFind() {
        findOpen = false;
        replaceOpen = false;
        matches = [];
        matchIndex = -1;
        editor.forceActiveFocus();
    }

    function recomputeMatches() {
        matches = Md.findAll(editor.text, findField.text, findOpts());
        if (matches.length === 0) {
            matchIndex = -1;
            return;
        }
        let idx = matches.findIndex(m => m.start >= editor.selectionStart);
        matchIndex = idx < 0 ? 0 : idx;
    }

    function gotoMatch(i) {
        if (matches.length === 0)
            return;
        matchIndex = ((i % matches.length) + matches.length) % matches.length;
        const m = matches[matchIndex];
        editor.select(m.start, m.end);
    }

    function findStep(dir) {
        if (matches.length === 0)
            recomputeMatches();
        if (matches.length === 0)
            return;
        gotoMatch(matchIndex < 0 ? 0 : matchIndex + dir);
    }

    function replaceCurrent() {
        if (matchIndex < 0 || matchIndex >= matches.length)
            return;
        const m = matches[matchIndex];
        const piece = editor.text.slice(m.start, m.end);
        const r = findRegex ? Md.replaceAll(piece, findField.text, replaceField.text, findOpts()).text : replaceField.text;
        applyEdit({ start: m.start, end: m.end, text: r, selStart: m.start + r.length, selEnd: m.start + r.length });
        recomputeMatches();
        if (matches.length > 0)
            gotoMatch(matchIndex);
    }

    function replaceEverything() {
        const r = Md.replaceAll(editor.text, findField.text, replaceField.text, findOpts());
        if (r.count === 0)
            return;
        applyEdit({ start: 0, end: editor.text.length, text: r.text, selStart: 0, selEnd: 0 });
        core.toast("Replaced " + r.count + (r.count === 1 ? " match" : " matches"));
        recomputeMatches();
    }

    Timer {
        id: findTimer
        interval: 150
        onTriggered: if (ui.findOpen)
            ui.recomputeMatches()
    }

    // --- preview ------------------------------------------------------------------------------
    function previewCtx() {
        return {
            vaultAbs: core.activeVault,
            noteDir: core.parentOf(core.noteRel),
            resolveNote: n => core.resolveNote(n),
            resolveAsset: (n, d) => core.resolveAsset(n, d),
            getEmbed: n => core.getEmbed(n),
            diagram: (kind, src, display) => core.render.diagram(kind, src, display, Math.max(200, previewFlick.width - 64))
        };
    }

    function refreshPreview() {
        if (core.viewMode === "edit" || !core.noteRel) {
            return;
        }
        core.render.beginPass();
        const r = Md.renderPreview(core.buffer, previewCtx());
        previewHtml = Html.renderHtml(r.markdown, previewColors);
        previewProps = r.props.map(p => ({ key: p.key, text: Array.isArray(p.value) ? p.value.join(", ") : String(p.value) }));
    }

    Timer {
        id: previewTimer
        interval: 150
        onTriggered: ui.refreshPreview()
    }

    function safeDecode(t) {
        try {
            return decodeURIComponent(t);
        } catch (e) {
            return t;
        }
    }

    function handleLink(link) {
        if (link.indexOf("sn-task:") === 0) {
            core.toggleTaskLine(parseInt(link.slice(8), 10));
        } else if (link.indexOf("sn-note:") === 0) {
            const parts = link.slice(8).split("#");
            core.openLink(safeDecode(parts[0]), parts.length > 1 ? safeDecode(parts[1]) : "");
        } else if (link.indexOf("sn-tag:") === 0) {
            core.showTag(safeDecode(link.slice(7)));
        } else if (/^https?:\/\//.test(link)) {
            Qt.openUrlExternally(link);
        }
    }

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
                Qt.callLater(ui.focusEditor);
            }
        }
    }

    // a math / Mermaid picture became available: refresh the preview
    readonly property int pictureSerial: core.render.serial
    onPictureSerialChanged: {
        if (core.viewMode !== "edit")
            previewTimer.restart();
    }

    property bool syncing: false

    Component.onCompleted: {
        syncing = true;
        editor.text = core.buffer;
        syncing = false;
        titleInput.text = core.noteTitle;
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

    // --- windows ------------------------------------------------------------------------------
    // "Expand": the same panel content (keys) is re-parented into a real, compositor-managed window.
    DankFloatingWindow {
        id: floatWin
        title: "SuperNote"
        implicitWidth: 1180
        implicitHeight: 780
        visible: ui.core.panelVisible && ui.core.windowMode === "window"
        onVisibleChanged: {
            if (visible)
                Qt.callLater(ui.focusEditor);
            else if (ui.core.windowMode === "window" && ui.core.panelVisible)
                ui.core.close();   // closed by the compositor
        }
        Item {
            id: winHost
            anchors.fill: parent
        }
    }

    PanelWindow {
        id: overlay
        visible: ui.core.panelVisible && !ui.browsing && ui.core.windowMode !== "window"
        color: "transparent"

        WlrLayershell.namespace: "dms:plugins:supernote"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible) {
                const s = CompositorService.getFocusedScreen();
                if (s)
                    overlay.screen = s;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ui.core.close()
        }

        FocusScope {
            id: keys
            readonly property bool inWindow: ui.core.windowMode === "window"
            // docked: right edge of the screen, below the bar; window: fills the floating window
            parent: inWindow ? winHost : overlay.contentItem
            x: inWindow ? 0 : parent.width - width - 12
            y: inWindow ? 0 : 52
            width: inWindow ? parent.width : Math.min(500, parent.width - 24)
            height: inWindow ? parent.height : parent.height - 52 - 12
            focus: ui.core.panelVisible

            Keys.onPressed: event => ui.handleKey(event)

            Rectangle {
                id: panelBg
                anchors.fill: parent
                radius: keys.inWindow ? 0 : Theme.cornerRadius
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        ui.ctx = null;
                        ui.vaultMenuOpen = false;
                    }
                }

                // ---------------- header ----------------
                Item {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 48

                    Rectangle {
                        id: vaultBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        width: vaultRow.implicitWidth + 20
                        radius: 8
                        color: vaultMouse.containsMouse || ui.vaultMenuOpen ? Theme.surfaceContainerHigh : "transparent"
                        Row {
                            id: vaultRow
                            anchors.centerIn: parent
                            spacing: 6
                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "folder_open"
                                size: 18
                                color: Theme.primary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, keys.inWindow ? 260 : 110)
                                elide: Text.ElideRight
                                text: ui.core.vaultName(ui.core.activeVault) || "Vault"
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.DemiBold
                            }
                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "expand_more"
                                size: 18
                                color: Theme.surfaceVariantText
                            }
                        }
                        MouseArea {
                            id: vaultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ui.vaultMenuOpen = !ui.vaultMenuOpen
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        IconBtn {
                            icon: "note_add"
                            onClicked: ui.core.newNote()
                        }
                        IconBtn {
                            icon: "today"
                            onClicked: ui.core.openDaily()
                        }
                        IconBtn {
                            visible: ui.core.showSidebar
                            icon: "create_new_folder"
                            onClicked: ui.askNewFolder(ui.core.targetDir())
                        }
                        IconBtn {
                            visible: ui.core.showSidebar
                            icon: "schedule"
                            active: ui.core.sortByMtime
                            onClicked: ui.core.toggleSort()
                        }
                        IconBtn {
                            visible: ui.core.showSidebar
                            icon: "refresh"
                            onClicked: ui.core.refreshTree()
                        }
                        IconBtn {
                            visible: ui.core.noteRel !== ""
                            icon: "push_pin"
                            active: ui.core.pins.indexOf(ui.core.noteRel) >= 0
                            onClicked: ui.core.togglePin(ui.core.noteRel)
                        }
                        IconBtn {
                            icon: "right_panel_open"
                            active: ui.core.rightPanel
                            onClicked: ui.core.setRightPanel(!ui.core.rightPanel)
                        }
                        IconBtn {
                            icon: "left_panel_open"
                            active: ui.core.showSidebar
                            onClicked: ui.core.toggleSidebar()
                        }
                        IconBtn {
                            icon: keys.inWindow ? "close_fullscreen" : "open_in_new"
                            onClicked: keys.inWindow ? ui.core.dockAgain() : ui.core.expandToWindow()
                        }
                        IconBtn {
                            icon: "close"
                            onClicked: ui.core.close()
                        }
                    }
                }

                Rectangle {
                    id: headerLine
                    anchors.top: header.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.outline
                    opacity: 0.4
                }

                // ---------------- sidebar: file tree ----------------
                Item {
                    id: sidebar
                    visible: ui.core.showSidebar
                    anchors.top: headerLine.bottom
                    anchors.left: parent.left
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

                    ListView {
                        id: tree
                        visible: ui.core.sidebarTab === "files"
                        anchors.top: sideTabs.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
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
                                        const p = rowMouse.mapToItem(panelBg, mouse.x, mouse.y);
                                        ui.ctx = { path: modelData.path, type: row.isShortcut ? "file" : modelData.type, x: p.x, y: p.y };
                                    } else {
                                        ui.ctx = null;
                                        tree.currentIndex = index;
                                        ui.activateRow(modelData, (mouse.modifiers & Qt.ControlModifier) !== 0);
                                    }
                                }
                            }
                        }
                    }


                    // ---- search pane ----
                    FocusScope {
                        id: searchScope
                        visible: ui.core.sidebarTab === "search"
                        anchors.top: sideTabs.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        property int cur: -1
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                cur = Math.min(cur + 1, ui.searchRows.length - 1);
                            } else if (event.key === Qt.Key_Up) {
                                cur = Math.max(cur - 1, 0);
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                const r = ui.searchRows[Math.max(cur, 0)];
                                if (r)
                                    searchScope.activate(r);
                            } else if (event.key === Qt.Key_Escape) {
                                if (searchField.text.length > 0) {
                                    searchField.text = "";
                                    ui.core.search("");
                                } else {
                                    ui.focusEditor();
                                }
                            } else {
                                return;
                            }
                            if (cur >= 0)
                                searchList.positionViewAtIndex(cur, ListView.Contain);
                            event.accepted = true;
                        }
                        function activate(r) {
                            if (r.kind === "file")
                                ui.toggleSearchFile(r.path);
                            else
                                ui.core.openNote(r.path, false, "", r.kind === "match" ? r.line : 0);
                        }
                        DankTextField {
                            id: searchField
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 38
                            leftIconName: "search"
                            leftIconSize: 16
                            textColor: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            placeholderText: "Search all notes…"
                            keyForwardTargets: [searchScope]
                            onTextEdited: searchTimer.restart()
                        }
                        Timer {
                            id: searchTimer
                            interval: 250
                            onTriggered: ui.core.search(searchField.text)
                        }
                        ListView {
                            id: searchList
                            anchors.top: searchField.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            clip: true
                            spacing: 1
                            model: ui.searchRows
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                id: srow
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: modelData.kind === "match" ? 24 : 28
                                radius: 6
                                color: index === searchScope.cur ? Theme.primaryContainer : (srMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                                Row {
                                    visible: modelData.kind !== "match"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 6
                                    spacing: 6
                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.kind === "file" ? (modelData.collapsed ? "chevron_right" : "expand_more") : "description"
                                        size: 16
                                        color: Theme.surfaceVariantText
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: srow.width - 60
                                        text: modelData.kind === "file" ? ui.core.noteTitleOf(modelData.path) + "  (" + modelData.count + ")" : modelData.name + (modelData.folder ? "   " + modelData.folder : "")
                                        elide: Text.ElideRight
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: modelData.kind === "file" ? Font.DemiBold : Font.Normal
                                    }
                                }
                                StyledText {
                                    visible: modelData.kind === "match"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 26
                                    width: parent.width - 34
                                    textFormat: Text.StyledText
                                    text: modelData.kind === "match" ? '<font color="' + Theme.surfaceVariantText + '">' + modelData.line + '  </font>' + Search.snippetHtml(modelData.text, ui.core.searchQuery.trim(), Theme.primary, 90) : ""
                                    elide: Text.ElideRight
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                MouseArea {
                                    id: srMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        searchScope.cur = index;
                                        searchScope.activate(modelData);
                                    }
                                }
                            }
                        }
                        StyledText {
                            anchors.centerIn: searchList
                            width: searchList.width - 24
                            visible: ui.searchRows.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: ui.core.searching ? "Searching…" : (ui.core.searchQuery.trim().length < 2 ? "Type at least two characters.\nCtrl+Shift+F jumps here." : "No matches.")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }

                    // ---- tags pane ----
                    FocusScope {
                        id: tagScope
                        visible: ui.core.sidebarTab === "tags"
                        anchors.top: sideTabs.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (tagField.text.length > 0) {
                                    tagField.text = "";
                                    ui.tagFilter = "";
                                } else {
                                    ui.focusEditor();
                                }
                                event.accepted = true;
                            }
                        }
                        DankTextField {
                            id: tagField
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 38
                            leftIconName: "sell"
                            leftIconSize: 16
                            textColor: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            placeholderText: "Filter tags…"
                            keyForwardTargets: [tagScope]
                            onTextEdited: ui.tagFilter = text.trim().replace(/^#/, "")
                        }
                        ListView {
                            id: tagList
                            anchors.top: tagField.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            clip: true
                            spacing: 1
                            model: ui.tagRows
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                id: trow
                                required property var modelData
                                width: ListView.view.width
                                height: 28
                                radius: 6
                                color: modelData.selected ? Theme.primaryContainer : (trMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 6 + modelData.depth * 16
                                    spacing: 4
                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.kind === "tag" ? (modelData.hasChildren ? (modelData.expanded ? "expand_more" : "chevron_right") : "tag") : "description"
                                        size: 16
                                        color: modelData.kind === "tag" ? Theme.primary : Theme.surfaceVariantText
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: modelData.kind === "tag" && modelData.hasChildren
                                            onClicked: ui.core.toggleTag(modelData.tag)
                                        }
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: trow.width - 6 - modelData.depth * 16 - 60
                                        text: modelData.kind === "tag" ? modelData.name : ui.core.noteTitleOf(modelData.path)
                                        elide: Text.ElideRight
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: modelData.kind === "tag" && modelData.selected ? Font.DemiBold : Font.Normal
                                    }
                                }
                                StyledText {
                                    visible: modelData.kind === "tag"
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.count
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                MouseArea {
                                    id: trMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    z: -1
                                    onClicked: {
                                        if (modelData.kind === "tag")
                                            ui.core.selectTag(modelData.selected ? "" : modelData.tag);
                                        else
                                            ui.core.openNote(modelData.path);
                                    }
                                }
                            }
                        }
                        StyledText {
                            anchors.centerIn: tagList
                            width: tagList.width - 24
                            visible: ui.tagRows.length === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: ui.tagFilter ? "No tags match." : "No tags yet.\nWrite #tag in a note, or add tags: to its properties."
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: ui.core.vaultReady && ui.core.rows.length === 0 && ui.core.sidebarTab === "files"
                        text: "This vault is empty.\nCtrl+N creates a note."
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }

                Rectangle {
                    id: sidebarLine
                    anchors.top: headerLine.bottom
                    anchors.left: sidebar.right
                    anchors.bottom: parent.bottom
                    width: ui.core.showSidebar ? 1 : 0
                    color: Theme.outline
                    opacity: 0.4
                }

                // ---------------- editor area ----------------
                Item {
                    id: editorArea
                    anchors.top: headerLine.bottom
                    anchors.left: sidebarLine.right
                    anchors.right: rightPanelItem.left
                    anchors.bottom: parent.bottom

                    // ---- tab bar + back/forward ----
                    Rectangle {
                        id: tabBar
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 36
                        color: Theme.surfaceContainer

                        Row {
                            id: navBtns
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            IconBtn {
                                width: 28
                                height: 28
                                icon: "arrow_back"
                                opacity: Tabs.canBack(ui.core.tabState) ? 1 : 0.35
                                onClicked: ui.core.goBack()
                            }
                            IconBtn {
                                width: 28
                                height: 28
                                icon: "arrow_forward"
                                opacity: Tabs.canForward(ui.core.tabState) ? 1 : 0.35
                                onClicked: ui.core.goForward()
                            }
                        }

                        Row {
                            anchors.left: navBtns.right
                            anchors.leftMargin: 6
                            anchors.right: newTabBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: 2
                            Repeater {
                                model: ui.core.tabState.tabs
                                Rectangle {
                                    id: tabItem
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: index === ui.core.tabState.active
                                    width: Math.max(80, Math.min(190, (tabBar.width - 120) / Math.max(1, ui.core.tabState.tabs.length)))
                                    height: 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 8
                                    color: active ? Theme.surface : (tabMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                                    border.width: active ? 1 : 0
                                    border.color: Theme.outline
                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.right: closeBtn.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.rel ? ui.core.noteTitleOf(modelData.rel) : "New tab"
                                        elide: Text.ElideRight
                                        color: tabItem.active ? Theme.surfaceText : Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.italic: modelData.rel === ""
                                    }
                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.MiddleButton)
                                                ui.core.closeTab(tabItem.index);
                                            else
                                                ui.core.activateTab(tabItem.index);
                                        }
                                    }
                                    IconBtn {
                                        id: closeBtn
                                        width: 22
                                        height: 22
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: "close"
                                        opacity: tabItem.active || tabMouse.containsMouse ? 1 : 0
                                        onClicked: ui.core.closeTab(tabItem.index)
                                    }
                                }
                            }
                        }

                        IconBtn {
                            id: newTabBtn
                            width: 28
                            height: 28
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "add"
                            onClicked: ui.core.newTab()
                        }
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

                    Item {
                        anchors.top: tabBar.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        visible: ui.core.noteRel !== ""

                        Rectangle {
                            id: banner
                            visible: ui.core.conflict
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: visible ? 44 : 0
                            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: "This note changed on disk while you were editing."
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Rectangle {
                                    width: keepLabel.implicitWidth + 24
                                    height: 28
                                    radius: 14
                                    color: Theme.primary
                                    StyledText {
                                        id: keepLabel
                                        anchors.centerIn: parent
                                        text: "Keep my edits"
                                        color: Theme.primaryText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: ui.core.resolveKeepMine()
                                    }
                                }
                                Rectangle {
                                    width: reloadLabel.implicitWidth + 24
                                    height: 28
                                    radius: 14
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.outline
                                    StyledText {
                                        id: reloadLabel
                                        anchors.centerIn: parent
                                        text: "Reload from disk"
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: ui.core.resolveReload()
                                    }
                                }
                            }
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
                                    editor.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    editor.forceActiveFocus();
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

                        // ---- properties (frontmatter) ----
                        Item {
                            id: propsBlock
                            visible: ui.core.noteRel !== "" && ui.core.viewMode !== "preview"
                            anchors.top: titleLine.bottom
                            anchors.topMargin: 4
                            anchors.left: titleInput.left
                            anchors.right: titleInput.right
                            height: visible ? propsHead.height + (ui.core.propsOpen ? propsList.implicitHeight + 6 : 0) : 0
                            clip: true

                            Item {
                                id: propsHead
                                width: parent.width
                                height: 26
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    DankIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: ui.core.propsOpen ? "expand_more" : "chevron_right"
                                        size: 16
                                        color: Theme.surfaceVariantText
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Properties" + (ui.props.length ? "  " + ui.props.length : "")
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: ui.core.toggleProps()
                                }
                            }

                            Column {
                                id: propsList
                                visible: ui.core.propsOpen
                                anchors.top: propsHead.bottom
                                width: parent.width
                                spacing: 2
                                Repeater {
                                    model: ui.props
                                    Rectangle {
                                        id: prow
                                        required property var modelData
                                        readonly property string forNote: ui.core.noteRel
                                        width: propsList.width
                                        height: 28
                                        radius: 6
                                        color: Theme.surfaceContainer
                                        StyledText {
                                            id: pkey
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 120
                                            text: modelData.key
                                            elide: Text.ElideRight
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                        TextInput {
                                            id: pval
                                            anchors.left: pkey.right
                                            anchors.right: pdel.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.rightMargin: 6
                                            clip: true
                                            color: Theme.surfaceText
                                            selectionColor: Theme.primary
                                            selectedTextColor: Theme.primaryText
                                            font.pixelSize: Theme.fontSizeMedium
                                            text: Array.isArray(modelData.value) ? modelData.value.join(", ") : modelData.value
                                            selectByMouse: true
                                            onEditingFinished: {
                                                if (prow.forNote !== ui.core.noteRel)
                                                    return;
                                                const cur = Array.isArray(prow.modelData.value) ? prow.modelData.value.join(", ") : prow.modelData.value;
                                                if (text !== cur)
                                                    ui.commitProp(prow.modelData.key, text, Array.isArray(prow.modelData.value));
                                            }
                                            Keys.onPressed: event => {
                                                if (event.key === Qt.Key_Escape) {
                                                    text = Array.isArray(prow.modelData.value) ? prow.modelData.value.join(", ") : prow.modelData.value;
                                                    ui.focusEditor();
                                                    event.accepted = true;
                                                }
                                            }
                                        }
                                        IconBtn {
                                            id: pdel
                                            anchors.right: parent.right
                                            anchors.rightMargin: 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 24
                                            height: 24
                                            icon: "close"
                                            onClicked: ui.core.applyExternalText(Md.removeProperty(ui.core.buffer, prow.modelData.key))
                                        }
                                    }
                                }
                                Rectangle {
                                    width: propsList.width
                                    height: 28
                                    radius: 6
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.outline
                                    TextInput {
                                        id: newKey
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 110
                                        clip: true
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                        Keys.onTabPressed: newVal.forceActiveFocus()
                                        StyledText {
                                            visible: newKey.text.length === 0
                                            text: "+ new property"
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }
                                    TextInput {
                                        id: newVal
                                        anchors.left: newKey.right
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        clip: true
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        visible: newKey.text.length > 0
                                        onAccepted: {
                                            const k = newKey.text.trim();
                                            if (!k || !/^[A-Za-z0-9_\- ]+$/.test(k))
                                                return;
                                            ui.commitProp(k, text, false);
                                            newKey.text = "";
                                            text = "";
                                            ui.focusEditor();
                                        }
                                        StyledText {
                                            visible: newVal.text.length === 0
                                            text: "value, Enter to add"
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }
                                }
                            }
                        }

                        // ---- formatting toolbar ----
                        Rectangle {
                            id: toolbar
                            visible: ui.core.showToolbar && ui.core.viewMode !== "preview"
                            anchors.top: propsBlock.bottom
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

                        // ---- find / replace ----
                        Rectangle {
                            id: findBar
                            visible: ui.findOpen && ui.core.viewMode !== "preview"
                            anchors.top: toolbar.bottom
                            anchors.topMargin: visible ? 6 : 0
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            height: visible ? (ui.replaceOpen ? 76 : 40) : 0
                            radius: 8
                            color: Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.outline

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4
                                Row {
                                    spacing: 6
                                    height: 32
                                    DankTextField {
                                        id: findField
                                        width: 300
                                        height: 32
                                        leftIconName: "search"
                                        leftIconSize: 16
                                        textColor: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        placeholderText: "Find"
                                        keyForwardTargets: [keys]
                                        onTextEdited: findTimer.restart()
                                        onAccepted: ui.findStep(1)
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 70
                                        text: ui.matches.length === 0 ? (findField.text ? "No matches" : "") : (ui.matchIndex + 1) + " / " + ui.matches.length
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                    IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "keyboard_arrow_up"; onClicked: ui.findStep(-1) }
                                    IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "keyboard_arrow_down"; onClicked: ui.findStep(1) }
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: ui.findCase ? Theme.primaryContainer : "transparent"
                                        StyledText { anchors.centerIn: parent; text: "Aa"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                        MouseArea { anchors.fill: parent; onClicked: { ui.findCase = !ui.findCase; ui.recomputeMatches(); } }
                                    }
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: ui.findRegex ? Theme.primaryContainer : "transparent"
                                        StyledText { anchors.centerIn: parent; text: ".*"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                        MouseArea { anchors.fill: parent; onClicked: { ui.findRegex = !ui.findRegex; ui.recomputeMatches(); } }
                                    }
                                    IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "find_replace"; active: ui.replaceOpen; onClicked: ui.replaceOpen = !ui.replaceOpen }
                                    IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "close"; onClicked: ui.closeFind() }
                                }
                                Row {
                                    visible: ui.replaceOpen
                                    spacing: 6
                                    height: 32
                                    DankTextField {
                                        id: replaceField
                                        width: 300
                                        height: 32
                                        leftIconName: "edit"
                                        leftIconSize: 16
                                        textColor: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        placeholderText: "Replace with"
                                        keyForwardTargets: [keys]
                                        onAccepted: ui.replaceCurrent()
                                    }
                                    Rectangle {
                                        width: replLabel.implicitWidth + 20
                                        height: 28
                                        radius: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.outline
                                        StyledText { id: replLabel; anchors.centerIn: parent; text: "Replace"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                        MouseArea { anchors.fill: parent; onClicked: ui.replaceCurrent() }
                                    }
                                    Rectangle {
                                        width: replAllLabel.implicitWidth + 20
                                        height: 28
                                        radius: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.outline
                                        StyledText { id: replAllLabel; anchors.centerIn: parent; text: "Replace all"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                                        MouseArea { anchors.fill: parent; onClicked: ui.replaceEverything() }
                                    }
                                }
                            }
                        }

                        // ---- panes ----
                        Item {
                            id: panes
                            anchors.top: findBar.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: statusBar.top

                            Flickable {
                                id: flick
                                visible: ui.core.viewMode !== "preview"
                                x: 0
                                width: ui.core.viewMode === "split" ? parent.width / 2 : parent.width
                                height: parent.height
                                clip: true
                                contentWidth: width
                                contentHeight: editor.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                onContentYChanged: ui.core.currentView = { cursor: editor.cursorPosition, scroll: contentY }
                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                // colored copy of the text, drawn behind the (transparent) editor
                                Text {
                                    id: underlay
                                    visible: ui.coloringOk && ui.hlHtml.length > 0
                                    x: editor.leftPadding
                                    y: editor.topPadding
                                    width: editor.width - editor.leftPadding - editor.rightPadding
                                    z: -1
                                    textFormat: Text.RichText
                                    wrapMode: Text.Wrap
                                    font: editor.font
                                    color: Theme.surfaceText
                                    text: ui.hlHtml
                                }

                                TextArea.flickable: TextArea {
                                    id: editor
                                    wrapMode: TextEdit.Wrap
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: ui.core.editorFontSize > 0 ? ui.core.editorFontSize : 15
                                    font.letterSpacing: 0
                                    color: ui.coloringOk && ui.hlHtml.length > 0 ? "transparent" : Theme.surfaceText
                                    selectedTextColor: ui.coloringOk && ui.hlHtml.length > 0 ? "transparent" : Theme.primaryText
                                    selectionColor: ui.coloringOk && ui.hlHtml.length > 0 ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Theme.primary
                                    selectByMouse: true
                                    persistentSelection: true
                                    textFormat: TextEdit.PlainText
                                    tabStopDistance: 32
                                    leftPadding: 28
                                    rightPadding: 28
                                    topPadding: 10
                                    bottomPadding: 40
                                    background: null
                                    placeholderText: "Start writing…"
                                    placeholderTextColor: Theme.surfaceVariantText
                                    cursorDelegate: Rectangle {
                                        width: 2
                                        color: Theme.primary
                                        visible: editor.activeFocus
                                    }
                                    Keys.onPressed: event => ui.editorKey(event)
                                    onTextChanged: {
                                        if (!ui.syncing) {
                                            ui.core.onEdited(text);
                                            if (ui.findOpen)
                                                findTimer.restart();
                                        }
                                        ui.refreshHighlight();
                                        ui.updateAutocomplete();
                                    }
                                    onCursorPositionChanged: {
                                        ui.updateCursorInfo();
                                        ui.core.currentView = { cursor: cursorPosition, scroll: flick.contentY };
                                        ui.updateAutocomplete();
                                    }
                                    onFocusChanged: if (!focus)
                                        ui.acOpen = false
                                    onCursorRectangleChanged: {
                                        if (cursorRectangle.y < flick.contentY)
                                            flick.contentY = cursorRectangle.y;
                                        else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height - 40)
                                            flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height + 40;
                                    }
                                }
                            }

                            Rectangle {
                                visible: ui.core.viewMode === "split"
                                x: parent.width / 2
                                width: 1
                                height: parent.height
                                color: Theme.outline
                                opacity: 0.4
                            }

                            Flickable {
                                id: previewFlick
                                visible: ui.core.viewMode !== "edit"
                                x: ui.core.viewMode === "split" ? parent.width / 2 + 1 : 0
                                width: ui.core.viewMode === "split" ? parent.width / 2 - 1 : parent.width
                                height: parent.height
                                clip: true
                                contentWidth: width
                                contentHeight: previewCol.implicitHeight + 40
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                Column {
                                    id: previewCol
                                    x: 28
                                    y: 12
                                    width: previewFlick.width - 56
                                    spacing: 12

                                    Rectangle {
                                        visible: ui.previewProps.length > 0
                                        width: parent.width
                                        height: propsCol.implicitHeight + 16
                                        radius: 8
                                        color: Theme.surfaceContainer
                                        border.width: 1
                                        border.color: Theme.outline
                                        Column {
                                            id: propsCol
                                            x: 12
                                            y: 8
                                            width: parent.width - 24
                                            spacing: 4
                                            Repeater {
                                                model: ui.previewProps
                                                Row {
                                                    required property var modelData
                                                    spacing: 10
                                                    StyledText {
                                                        width: 110
                                                        text: modelData.key
                                                        color: Theme.surfaceVariantText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        elide: Text.ElideRight
                                                    }
                                                    StyledText {
                                                        width: propsCol.width - 120
                                                        text: modelData.text
                                                        color: Theme.surfaceText
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        textFormat: Text.RichText
                                        text: ui.previewHtml
                                        wrapMode: Text.Wrap
                                        color: Theme.surfaceText
                                        linkColor: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 16
                                        onLinkActivated: link => ui.handleLink(link)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: statusBar
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
                    }
                }

                // ---------------- right panel: outline / backlinks / links ----------------
                Item {
                    id: rightPanelItem
                    visible: ui.core.rightPanel
                    anchors.top: headerLine.bottom
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: visible ? 300 : 0

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Theme.outline
                        opacity: 0.4
                    }

                    Row {
                        id: rpTabs
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        spacing: 6
                        Repeater {
                            model: [{ id: "outline", label: "Outline" }, { id: "backlinks", label: "Backlinks" }, { id: "links", label: "Links" }]
                            Rectangle {
                                required property var modelData
                                readonly property bool on: ui.core.rightTab === modelData.id
                                width: rpLabel.implicitWidth + 20
                                height: 28
                                radius: 14
                                color: on ? Theme.primaryContainer : "transparent"
                                border.width: 1
                                border.color: on ? Theme.primary : Theme.outline
                                StyledText {
                                    id: rpLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData.label + (parent.modelData.id === "backlinks" && ui.core.backlinks.length ? " " + ui.core.backlinks.length : (parent.modelData.id === "links" && ui.noteLinks.length ? " " + ui.noteLinks.length : ""))
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: ui.core.setRightTab(parent.modelData.id)
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: !ui.core.noteRel
                        text: "Open a note to see its outline,\nbacklinks and links."
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    ListView {
                        visible: ui.core.rightTab === "outline" && ui.core.noteRel !== ""
                        anchors.top: rpTabs.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        clip: true
                        model: ui.outline
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 28
                            radius: 6
                            color: olMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8 + (modelData.level - 1) * 14
                                width: parent.width - x - 8
                                text: modelData.text
                                elide: Text.ElideRight
                                color: modelData.level === 1 ? Theme.surfaceText : Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: modelData.level <= 2 ? Font.DemiBold : Font.Normal
                            }
                            MouseArea {
                                id: olMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ui.jumpToOffset(modelData.offset)
                            }
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: ui.outline.length === 0
                            text: "No headings in this note."
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }

                    ListView {
                        visible: ui.core.rightTab === "backlinks" && ui.core.noteRel !== ""
                        anchors.top: rpTabs.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        clip: true
                        model: ui.backlinkRows
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: modelData.kind === "file" ? 30 : 34
                            radius: 6
                            color: blMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                            Row {
                                visible: modelData.kind === "file"
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                spacing: 6
                                DankIcon { anchors.verticalCenter: parent.verticalCenter; name: "description"; size: 16; color: Theme.primary }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 210
                                    text: ui.core.noteTitleOf(modelData.path) + "  (" + modelData.count + ")"
                                    elide: Text.ElideRight
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                }
                            }
                            StyledText {
                                visible: modelData.kind === "line"
                                anchors.verticalCenter: parent.verticalCenter
                                x: 30
                                width: parent.width - 38
                                text: modelData.text
                                elide: Text.ElideRight
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            MouseArea {
                                id: blMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ui.core.openNote(modelData.path, false, "", modelData.line || 0)
                            }
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: ui.backlinkRows.length === 0
                            text: "No other note links here."
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }

                    ListView {
                        visible: ui.core.rightTab === "links" && ui.core.noteRel !== ""
                        anchors.top: rpTabs.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        clip: true
                        model: ui.noteLinks
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 30
                            radius: 6
                            color: lkMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                spacing: 6
                                DankIcon { anchors.verticalCenter: parent.verticalCenter; name: modelData.resolved ? "link" : "link_off"; size: 16; color: modelData.resolved ? Theme.primary : Theme.surfaceVariantText }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 220
                                    text: modelData.name + (modelData.heading ? " # " + modelData.heading : "") + (modelData.count > 1 ? "  ×" + modelData.count : "")
                                    elide: Text.ElideRight
                                    color: modelData.resolved ? Theme.surfaceText : Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }
                            MouseArea {
                                id: lkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ui.core.openLink(modelData.name, modelData.heading)
                            }
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: ui.noteLinks.length === 0
                            text: "This note links to nothing yet."
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }
                }

                // ---------------- [[ autocomplete popup ----------------
                Rectangle {
                    visible: ui.acOpen
                    x: Math.max(8, Math.min(ui.acPos.x, panelBg.width - width - 8))
                    y: Math.min(ui.acPos.y, panelBg.height - height - 8)
                    z: 90
                    width: 340
                    height: acCol.implicitHeight + 8
                    radius: 10
                    color: Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.outline
                    Column {
                        id: acCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        Repeater {
                            model: ui.acItems
                            Rectangle {
                                required property var modelData
                                required property int index
                                width: parent.width
                                height: 30
                                radius: 6
                                color: index === ui.acIndex ? Theme.primaryContainer : "transparent"
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    width: parent.width - 20
                                    text: modelData.name + (modelData.folder ? "   " + modelData.folder : "")
                                    elide: Text.ElideRight
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        ui.acIndex = index;
                                        ui.acAccept();
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------- cheat sheet ----------------
                Rectangle {
                    visible: ui.cheatOpen
                    anchors.fill: parent
                    z: 120
                    radius: Theme.cornerRadius
                    color: Qt.rgba(0, 0, 0, 0.5)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ui.cheatOpen = false
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 620
                        height: Math.min(parent.height - 80, 640)
                        radius: 12
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.outline
                        MouseArea {
                            anchors.fill: parent
                        }
                        StyledText {
                            id: cheatTitle
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 18
                            text: "Keyboard shortcuts"
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                        }
                        ListView {
                            anchors.top: cheatTitle.bottom
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 18
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: ui.cheatRows
                            delegate: Item {
                                required property var modelData
                                width: ListView.view.width
                                height: modelData.header ? 34 : 26
                                StyledText {
                                    visible: !!modelData.header
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    text: modelData.header ? modelData.header.toUpperCase() : ""
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                }
                                StyledText {
                                    visible: !modelData.header
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title || ""
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                                StyledText {
                                    visible: !modelData.header
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.keys || ""
                                    color: Theme.surfaceVariantText
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }

                // ---------------- quick switcher ----------------
                Rectangle {
                    visible: ui.switcherOpen
                    anchors.fill: parent
                    z: 110
                    radius: Theme.cornerRadius
                    color: Qt.rgba(0, 0, 0, 0.4)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ui.closeSwitcher()
                    }

                    FocusScope {
                        id: switcherScope
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 70
                        width: 580
                        height: swCol.implicitHeight + 20
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                ui.closeSwitcher();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                ui.switcherIndex = Math.min(ui.switcherIndex + 1, ui.switcherResults.length - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                ui.switcherIndex = Math.max(ui.switcherIndex - 1, 0);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                ui.switcherAccept((event.modifiers & Qt.ControlModifier) !== 0);
                                event.accepted = true;
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.outline
                        }
                        Column {
                            id: swCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 8
                            DankTextField {
                                id: switcherField
                                width: parent.width
                                height: 44
                                leftIconName: "search"
                                leftIconSize: 18
                                textColor: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                placeholderText: ui.moveSource ? "Move \"" + ui.moveSource.split("/").pop() + "\" to…" : (ui.switcherMode === "commands" ? "Type a command…" : (ui.switcherMode.indexOf("template-") === 0 ? "Pick a template…" : "Find or create a note…"))
                                keyForwardTargets: [switcherScope]
                                onTextEdited: ui.updateSwitcher()
                            }
                            ListView {
                                id: swList
                                width: parent.width
                                height: Math.min(contentHeight, 360)
                                clip: true
                                model: ui.switcherResults
                                currentIndex: ui.switcherIndex
                                boundsBehavior: Flickable.StopAtBounds
                                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: 36
                                    radius: 8
                                    color: index === ui.switcherIndex ? Theme.primaryContainer : "transparent"
                                    DankIcon {
                                        id: swIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.kind === "create" ? "note_add" : (modelData.kind === "folder" ? "folder" : (modelData.kind === "command" ? "keyboard_command_key" : "description"))
                                        size: 18
                                        color: modelData.kind === "create" ? Theme.primary : Theme.surfaceVariantText
                                    }
                                    StyledText {
                                        anchors.left: swIcon.right
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.kind === "create" ? "Create “" + modelData.name + "”" : (modelData.item.name + (modelData.item.folder ? "     " + modelData.item.folder : ""))
                                        elide: Text.ElideRight
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            ui.switcherIndex = index;
                                            ui.switcherAccept(false);
                                        }
                                    }
                                }
                            }
                            StyledText {
                                text: ui.moveSource ? "↑↓ move  ·  Enter move here  ·  Esc cancel" : (ui.switcherMode === "notes" ? "↑↓ move  ·  Enter open  ·  Ctrl+Enter new tab  ·  Esc close" : "↑↓ move  ·  Enter run  ·  Esc close")
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }

                // ---------------- vault menu ----------------
                Rectangle {
                    visible: ui.vaultMenuOpen
                    x: 10
                    y: 46
                    z: 50
                    width: 320
                    height: vaultCol.implicitHeight + 12
                    radius: 10
                    color: Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.outline
                    Column {
                        id: vaultCol
                        x: 6
                        y: 6
                        width: parent.width - 12
                        spacing: 2
                        Repeater {
                            model: ui.core.vaults
                            MenuItem {
                                id: vaultItem
                                required property string modelData
                                label: ui.core.vaultName(modelData) + (modelData === ui.core.activeVault ? "   (active)" : "")
                                icon: "folder"
                                onTriggered: {
                                    ui.vaultMenuOpen = false;
                                    if (modelData !== ui.core.activeVault)
                                        ui.core.activateVault(modelData);
                                }
                                IconBtn {
                                    visible: ui.core.vaults.length > 1
                                    anchors.right: parent.right
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28
                                    icon: "close"
                                    onClicked: {
                                        ui.vaultMenuOpen = false;
                                        ui.core.removeVault(vaultItem.modelData);
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.4
                        }
                        MenuItem {
                            visible: ui.core.lastRename !== null && ui.core.lastRename !== undefined && ui.core.lastRename.vault === ui.core.activeVault
                            label: ui.core.lastRename ? "Undo: " + ui.core.lastRename.from.split("/").pop().replace(/\.md$/, "") + " → " + ui.core.lastRename.to.split("/").pop().replace(/\.md$/, "") : ""
                            icon: "undo"
                            onTriggered: {
                                ui.vaultMenuOpen = false;
                                ui.core.undoRename();
                            }
                        }
                        MenuItem {
                            label: "Open another vault…"
                            icon: "add"
                            onTriggered: ui.addVault()
                        }
                    }
                }

                // ---------------- context menu ----------------
                Rectangle {
                    visible: ui.ctx !== null
                    x: ui.ctx ? Math.min(ui.ctx.x, panelBg.width - width - 8) : 0
                    y: ui.ctx ? Math.min(ui.ctx.y, panelBg.height - height - 8) : 0
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

                // ---------------- dialog ----------------
                Rectangle {
                    visible: ui.dlgOpen
                    anchors.fill: parent
                    z: 100
                    radius: Theme.cornerRadius
                    color: Qt.rgba(0, 0, 0, 0.45)
                    MouseArea {
                        anchors.fill: parent
                    }

                    FocusScope {
                        id: dlgScope
                        anchors.centerIn: parent
                        width: 420
                        height: dlgCol.implicitHeight + 40
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                ui.dlgCancel();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                ui.dlgAccept();
                                event.accepted = true;
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.outline
                        }
                        Column {
                            id: dlgCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 14
                            StyledText {
                                text: ui.dlgTitle
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                visible: ui.dlgMessage.length > 0
                                width: parent.width
                                text: ui.dlgMessage
                                wrapMode: Text.WordWrap
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            DankTextField {
                                id: dlgField
                                visible: ui.dlgInput
                                width: parent.width
                                height: 44
                                textColor: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                keyForwardTargets: [dlgScope]
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 8
                                Rectangle {
                                    width: cancelLabel.implicitWidth + 28
                                    height: 32
                                    radius: 16
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.outline
                                    StyledText {
                                        id: cancelLabel
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: ui.dlgCancel()
                                    }
                                }
                                Rectangle {
                                    visible: ui.dlgAlt.length > 0
                                    width: altLabel.implicitWidth + 28
                                    height: 32
                                    radius: 16
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.primary
                                    StyledText {
                                        id: altLabel
                                        anchors.centerIn: parent
                                        text: ui.dlgAlt
                                        color: Theme.primary
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: ui.dlgAccept2()
                                    }
                                }
                                Rectangle {
                                    width: okLabel.implicitWidth + 28
                                    height: 32
                                    radius: 16
                                    color: ui.dlgDanger ? Theme.error : Theme.primary
                                    StyledText {
                                        id: okLabel
                                        anchors.centerIn: parent
                                        text: ui.dlgConfirm
                                        color: ui.dlgDanger ? Theme.background : Theme.primaryText
                                        font.pixelSize: Theme.fontSizeMedium
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: ui.dlgAccept()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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
