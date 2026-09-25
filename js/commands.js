.pragma library
.import "fuzzy.js" as Fuzzy

// Command palette entries + the shortcut cheat sheet (pure data; tests/commands.test.js).
// `needsNote`: only offered while a note is open. `keys`: shown in the palette and the cheat sheet.
var COMMANDS = [
    { id: "new-note", group: "Notes", title: "New note", keys: "Ctrl+N" },
    { id: "new-from-template", group: "Notes", title: "New note from template…", keys: "" },
    { id: "insert-template", group: "Notes", title: "Insert template…", keys: "", needsNote: true },
    { id: "daily", group: "Notes", title: "Open today's daily note", keys: "" },
    { id: "capture", group: "Notes", title: "Quick capture", keys: "Super+Ctrl+N" },
    { id: "switcher", group: "Notes", title: "Open note…", keys: "Ctrl+O" },
    { id: "rename", group: "Notes", title: "Rename this note", keys: "F2", needsNote: true },
    { id: "pin", group: "Notes", title: "Pin / unpin this note", keys: "", needsNote: true },
    { id: "delete", group: "Notes", title: "Delete this note", keys: "", needsNote: true },
    { id: "toggle-view", group: "View", title: "Cycle Edit / Split / Preview", keys: "Ctrl+E", needsNote: true },
    { id: "right-panel", group: "View", title: "Toggle right panel", keys: "Ctrl+Shift+B" },
    { id: "toggle-sidebar", group: "View", title: "Toggle left panel (files / search / tags)", keys: "Ctrl+\\" },
    { id: "expand-window", group: "View", title: "Expand to window / dock to the right", keys: "" },
    { id: "toolbar", group: "View", title: "Toggle formatting toolbar", keys: "" },
    { id: "properties", group: "View", title: "Toggle properties", keys: "", needsNote: true },
    { id: "search", group: "Navigate", title: "Search all notes", keys: "Ctrl+Shift+F" },
    { id: "tags", group: "Navigate", title: "Show tags", keys: "" },
    { id: "files", group: "Navigate", title: "Show / hide files panel", keys: "Ctrl+Shift+E" },
    { id: "back", group: "Navigate", title: "Go back", keys: "Alt+Left" },
    { id: "forward", group: "Navigate", title: "Go forward", keys: "Alt+Right" },
    { id: "new-tab", group: "Navigate", title: "New tab", keys: "Ctrl+T" },
    { id: "close-tab", group: "Navigate", title: "Close tab", keys: "Ctrl+W" },
    { id: "find", group: "Edit", title: "Find in note", keys: "Ctrl+F", needsNote: true },
    { id: "replace", group: "Edit", title: "Find and replace", keys: "Ctrl+H", needsNote: true },
    { id: "undo-rename", group: "Vault", title: "Undo last rename / move", keys: "" },
    { id: "add-vault", group: "Vault", title: "Open another vault…", keys: "" },
    { id: "palette", group: "Help", title: "Command palette", keys: "Ctrl+P" },
    { id: "cheatsheet", group: "Help", title: "Keyboard shortcuts", keys: "Ctrl+/" }
];

function filter(query, hasNote) {
    var list = COMMANDS.filter(function (c) { return hasNote !== false || !c.needsNote; });
    if (!query)
        return list;
    return Fuzzy.rank(list.map(function (c) { return { name: c.title, path: c.group, item: c }; }), query, 30).map(function (r) { return r.item.item; });
}

// Extra editing shortcuts that are not palette commands.
var EDITING = [
    { title: "Bold / italic / strikethrough", keys: "Ctrl+B / Ctrl+I / Ctrl+Shift+X" },
    { title: "Inline code", keys: "Ctrl+Shift+C" },
    { title: "Insert link", keys: "Ctrl+K" },
    { title: "Toggle task", keys: "Ctrl+L" },
    { title: "Heading 1-6 (0 clears)", keys: "Ctrl+1 … Ctrl+6" },
    { title: "Indent / outdent", keys: "Tab / Shift+Tab" },
    { title: "Paste image from clipboard", keys: "Ctrl+V" },
    { title: "Slash menu (blocks, date, template)", keys: "/ at line start" },
    { title: "Link to a note", keys: "[[" },
    { title: "Follow the link under the caret", keys: "Ctrl+Enter / Ctrl+click" },
    { title: "Save now", keys: "Ctrl+S" },
    { title: "Command palette", keys: "Ctrl+P" },
    { title: "Next / previous tab", keys: "Ctrl+Tab / Ctrl+Shift+Tab" }
];

function cheatSheet() {
    var groups = {};
    var order = [];
    COMMANDS.forEach(function (c) {
        if (!c.keys)
            return;
        if (!groups[c.group]) {
            groups[c.group] = [];
            order.push(c.group);
        }
        groups[c.group].push({ title: c.title, keys: c.keys });
    });
    var out = order.map(function (g) { return { group: g, items: groups[g] }; });
    out.push({ group: "Writing", items: EDITING });
    return out;
}
