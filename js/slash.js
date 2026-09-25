.pragma library
.import "config.js" as Config
.import "fuzzy.js" as Fuzzy

// Slash menu ("/" at the start of a line). Pure; tests/slash.test.js. \u0001 in `insert` marks the caret.
var ITEMS = [
    { id: "h1", title: "Heading 1", hint: "#", keywords: "heading title h1", insert: "# \u0001" },
    { id: "h2", title: "Heading 2", hint: "##", keywords: "heading h2", insert: "## \u0001" },
    { id: "h3", title: "Heading 3", hint: "###", keywords: "heading h3", insert: "### \u0001" },
    { id: "bullet", title: "Bulleted list", hint: "-", keywords: "list unordered ul", insert: "- \u0001" },
    { id: "numbered", title: "Numbered list", hint: "1.", keywords: "list ordered ol", insert: "1. \u0001" },
    { id: "task", title: "Task", hint: "- [ ]", keywords: "todo checkbox checklist", insert: "- [ ] \u0001" },
    { id: "quote", title: "Quote", hint: ">", keywords: "blockquote", insert: "> \u0001" },
    { id: "code", title: "Code block", hint: "```", keywords: "fence snippet", insert: "```\n\u0001\n```" },
    { id: "table", title: "Table", hint: "| |", keywords: "grid columns", insert: "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |\u0001" },
    { id: "callout", title: "Callout", hint: "> [!note]", keywords: "admonition note warning info", insert: "> [!note]\n> \u0001" },
    { id: "divider", title: "Divider", hint: "---", keywords: "rule line hr separator", insert: "---\n\u0001" },
    { id: "link", title: "Link to note", hint: "[[ ]]", keywords: "wikilink note", insert: "[[\u0001]]" },
    { id: "date", title: "Today's date", hint: "", keywords: "today now day", insert: "@date" },
    { id: "time", title: "Current time", hint: "", keywords: "now clock", insert: "@time" },
    { id: "template", title: "Insert template…", hint: "", keywords: "templates snippet", insert: "" }
];

// Caret right after "/query" that starts a line (indent allowed) -> {start, query}.
function context(text, cursor) {
    var ls = text.lastIndexOf("\n", cursor - 1) + 1;
    var before = text.slice(ls, cursor);
    var m = /^(\s*)\/(\S*)$/.exec(before);
    if (!m)
        return null;
    return { start: ls + m[1].length, query: m[2] };
}

function filter(query) {
    if (!query)
        return ITEMS.slice();
    return Fuzzy.rank(ITEMS.map(function (it) { return { name: it.title, path: it.keywords, item: it }; }), query, 20).map(function (r) { return r.item.item; });
}

// Replace "/query" (ctx.start .. cursor) by the item -> {text, cursor}.
function apply(text, cursor, id, ctx, now) {
    var it = null;
    ITEMS.forEach(function (x) { if (x.id === id) it = x; });
    var ins = it ? it.insert : "";
    if (ins === "@date")
        ins = Config.formatDate("YYYY-MM-DD", now);
    else if (ins === "@time")
        ins = Config.formatDate("HH:mm", now);
    var caret = ins.indexOf("\u0001");
    var body = ins.replace("\u0001", "");
    if (caret < 0)
        caret = body.length;
    return { text: text.slice(0, ctx.start) + body + text.slice(cursor), cursor: ctx.start + caret };
}
