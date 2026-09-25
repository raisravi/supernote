.pragma library

// Vault tag tree (pure; tests/tags.test.js). `index` is {notePath: [tag, ...]}.
// Tags are case-insensitive; nested tags use "/" (project/alpha).

function collect(index) {
    var tags = {};    // lower -> {tag (display), notes: {path: true}}
    for (var path in index) {
        (index[path] || []).forEach(function (t) {
            var parts = t.split("/");
            for (var k = 1; k <= parts.length; k++) {
                var full = parts.slice(0, k).join("/");
                var key = full.toLowerCase();
                if (!tags[key])
                    tags[key] = { tag: full, notes: {} };
                tags[key].notes[path] = true;
            }
        });
    }
    return tags;
}

// Visible rows: {tag (key), name, depth, count, hasChildren, expanded}. `expanded` is keyed by
// lower-case tag; a non-empty `filter` shows only matching tags and their ancestors, fully open.
function rows(index, expanded, filter) {
    var tags = collect(index);
    var f = (filter || "").toLowerCase();
    var keys = Object.keys(tags);
    var visible = {};
    keys.forEach(function (k) {
        if (f && k.indexOf(f) < 0)
            return;
        var parts = k.split("/");
        for (var i = 1; i <= parts.length; i++)
            visible[parts.slice(0, i).join("/")] = true;
    });
    var children = {};
    keys.forEach(function (k) {
        if (!visible[k])
            return;
        var slash = k.lastIndexOf("/");
        var parent = slash < 0 ? "" : k.slice(0, slash);
        (children[parent] = children[parent] || []).push(k);
    });
    for (var p in children)
        children[p].sort();
    var out = [];
    function walk(parent, depth) {
        (children[parent] || []).forEach(function (k) {
            var hasChildren = !!children[k];
            var open = hasChildren && (f !== "" || !!expanded[k]);
            out.push({
                tag: k,
                name: tags[k].tag.split("/").pop(),
                depth: depth,
                count: Object.keys(tags[k].notes).length,
                hasChildren: hasChildren,
                expanded: open
            });
            if (open)
                walk(k, depth + 1);
        });
    }
    walk("", 0);
    return out;
}

// Notes carrying `tag` or any tag nested under it, sorted.
function notesFor(index, tag) {
    var t = tags_(index)[(tag || "").toLowerCase()];
    return t ? Object.keys(t.notes).sort() : [];
}

function tags_(index) {
    return collect(index);
}
