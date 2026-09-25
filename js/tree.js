.pragma library

// Flatten vault entries ({type, path, mtime}) into visible tree rows.
// Folders first, then notes, case-insensitive A->Z (or newest first when byMtime).
function buildRows(entries, expanded, byMtime) {
    var children = { "": [] };
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e.type === "attachment")
            continue;
        var slash = e.path.lastIndexOf("/");
        var parent = slash < 0 ? "" : e.path.slice(0, slash);
        var base = slash < 0 ? e.path : e.path.slice(slash + 1);
        if (!children[parent])
            children[parent] = [];
        children[parent].push({
            path: e.path,
            type: e.type,
            name: e.type === "file" ? base.replace(/\.md$/i, "") : base,
            mtime: e.mtime || 0
        });
    }
    for (var key in children) {
        children[key].sort(function (a, b) {
            if (a.type !== b.type)
                return a.type === "dir" ? -1 : 1;
            if (byMtime && a.type === "file" && a.mtime !== b.mtime)
                return b.mtime - a.mtime;
            return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
        });
    }
    var rows = [];
    function walk(parent, depth) {
        var list = children[parent] || [];
        for (var j = 0; j < list.length; j++) {
            var c = list[j];
            var open = c.type === "dir" && !!expanded[c.path];
            rows.push({ path: c.path, name: c.name, type: c.type, depth: depth, expanded: open, mtime: c.mtime });
            if (open)
                walk(c.path, depth + 1);
        }
    }
    walk("", 0);
    return rows;
}

function parentOf(path) {
    var slash = path.lastIndexOf("/");
    return slash < 0 ? "" : path.slice(0, slash);
}

function baseName(path) {
    var slash = path.lastIndexOf("/");
    var b = slash < 0 ? path : path.slice(slash + 1);
    return b.replace(/\.md$/i, "");
}

function ancestors(path) {
    var out = [];
    var p = parentOf(path);
    while (p) {
        out.push(p);
        p = parentOf(p);
    }
    return out;
}

// Path after renaming entry `from` to `to` (handles items inside a renamed folder).
function remapPath(path, from, to) {
    if (path === from)
        return to;
    if (path.indexOf(from + "/") === 0)
        return to + path.slice(from.length);
    return path;
}

var RECENT_SHOWN = 6;

// Tree rows preceded by "Pinned" / "Recent" shortcut sections (hdr rows toggle them via `open`).
function sideRows(treeRows, pins, recents, open, exists) {
    var pinned = pins.filter(function (p) { return exists[p]; });
    var isPinned = {};
    pinned.forEach(function (p) { isPinned[p] = true; });
    var recent = recents.filter(function (p) { return exists[p] && !isPinned[p]; }).slice(0, RECENT_SHOWN);
    if (pinned.length === 0 && recent.length === 0)
        return treeRows;
    var out = [];
    function shortcut(type, p) {
        return { type: type, path: p, name: baseName(p), hint: parentOf(p), depth: 0 };
    }
    if (pinned.length) {
        out.push({ type: "hdr", key: "pins", name: "Pinned", count: pinned.length, open: !!open.pins, depth: 0 });
        if (open.pins)
            pinned.forEach(function (p) { out.push(shortcut("pin", p)); });
    }
    if (recent.length) {
        out.push({ type: "hdr", key: "recent", name: "Recent", count: recent.length, open: !!open.recent, depth: 0 });
        if (open.recent)
            recent.forEach(function (p) { out.push(shortcut("recent", p)); });
    }
    out.push({ type: "hdr", key: "files", name: "All notes", count: 0, open: true, depth: 0 });
    return out.concat(treeRows);
}
