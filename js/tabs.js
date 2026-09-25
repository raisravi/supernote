.pragma library
.import "tree.js" as Tree

// Pure tab + per-tab navigation-history model. State is plain JSON:
//   { tabs: [{ rel, back: [rel], fwd: [rel], view: {cursor, scroll} | null }], active: index }
// A tab with rel "" is an empty tab. Every function returns a new state (or the same one when
// nothing changes); callers persist it as-is.

var HISTORY_MAX = 100;

function emptyTab() {
    return { rel: "", back: [], fwd: [], view: null };
}

function init() {
    return { tabs: [emptyTab()], active: 0 };
}

function clone(s) {
    return JSON.parse(JSON.stringify(s));
}

function clamp(i, n) {
    return Math.max(0, Math.min(i, n - 1));
}

function strings(a) {
    return Array.isArray(a) ? a.filter(function (x) { return typeof x === "string" && x.length > 0; }) : [];
}

// Repair whatever came out of a state file into a valid state.
function normalize(s) {
    if (!s || !Array.isArray(s.tabs))
        return init();
    var tabs = [];
    for (var i = 0; i < s.tabs.length; i++) {
        var t = s.tabs[i];
        if (!t || typeof t.rel !== "string")
            continue;
        tabs.push({ rel: t.rel, back: strings(t.back), fwd: strings(t.fwd), view: t.view && typeof t.view === "object" ? t.view : null });
    }
    if (tabs.length === 0)
        return init();
    var active = typeof s.active === "number" && isFinite(s.active) ? Math.floor(s.active) : 0;
    return { tabs: tabs, active: clamp(active, tabs.length) };
}

function activate(s, i) {
    if (i < 0 || i >= s.tabs.length || i === s.active)
        return s;
    var n = clone(s);
    n.active = i;
    return n;
}

function cycle(s, dir) {
    var n = s.tabs.length;
    return activate(s, ((s.active + dir) % n + n) % n);
}

function open(s, rel, newTab) {
    if (!rel)
        return s;
    for (var i = 0; i < s.tabs.length; i++) {
        if (s.tabs[i].rel === rel)
            return activate(s, i);
    }
    var n = clone(s);
    var cur = n.tabs[n.active];
    if (cur.rel === "") {
        cur.rel = rel;
        cur.view = null;
        return n;
    }
    if (newTab) {
        n.tabs.splice(n.active + 1, 0, { rel: rel, back: [], fwd: [], view: null });
        n.active += 1;
        return n;
    }
    cur.back.push(cur.rel);
    if (cur.back.length > HISTORY_MAX)
        cur.back.shift();
    cur.fwd = [];
    cur.rel = rel;
    cur.view = null;
    return n;
}

function addEmpty(s) {
    if (s.tabs[s.active].rel === "")
        return s;
    var n = clone(s);
    n.tabs.splice(n.active + 1, 0, emptyTab());
    n.active += 1;
    return n;
}

function close(s, i) {
    if (i < 0 || i >= s.tabs.length)
        return s;
    var n = clone(s);
    n.tabs.splice(i, 1);
    if (n.tabs.length === 0)
        return init();
    if (i < s.active)
        n.active = s.active - 1;
    else if (i === s.active)
        n.active = clamp(i, n.tabs.length);
    return n;
}

function canBack(s) {
    return s.tabs[s.active].back.length > 0;
}

function canForward(s) {
    return s.tabs[s.active].fwd.length > 0;
}

function back(s) {
    if (!canBack(s))
        return s;
    var n = clone(s);
    var t = n.tabs[n.active];
    t.fwd.push(t.rel);
    t.rel = t.back.pop();
    t.view = null;
    return n;
}

function forward(s) {
    if (!canForward(s))
        return s;
    var n = clone(s);
    var t = n.tabs[n.active];
    t.back.push(t.rel);
    t.rel = t.fwd.pop();
    t.view = null;
    return n;
}

function remap(s, from, to) {
    var n = clone(s);
    n.tabs.forEach(function (t) {
        t.rel = Tree.remapPath(t.rel, from, to);
        t.back = t.back.map(function (r) { return Tree.remapPath(r, from, to); });
        t.fwd = t.fwd.map(function (r) { return Tree.remapPath(r, from, to); });
    });
    return n;
}

function gone(rel, path) {
    return rel === path || rel.indexOf(path + "/") === 0;
}

// A note or folder was trashed: close its tabs and scrub it from every history.
function removePath(s, path) {
    var activeTab = s.tabs[s.active];
    var n = clone(s);
    n.tabs = n.tabs.filter(function (t) { return !gone(t.rel, path); });
    n.tabs.forEach(function (t) {
        t.back = t.back.filter(function (r) { return !gone(r, path); });
        t.fwd = t.fwd.filter(function (r) { return !gone(r, path); });
    });
    if (n.tabs.length === 0)
        return init();
    var idx = -1;
    for (var i = 0; i < n.tabs.length; i++) {
        if (n.tabs[i].rel === activeTab.rel && n.tabs[i].rel !== "")
            idx = i;
    }
    n.active = idx >= 0 ? idx : clamp(s.active, n.tabs.length);
    return n;
}

// After restoring from disk: keep only notes that still exist, one tab per note.
function prune(s, existing) {
    var have = {};
    existing.forEach(function (r) { have[r] = true; });
    var n = clone(s);
    var seen = {};
    n.tabs = n.tabs.filter(function (t) {
        if (t.rel !== "" && (!have[t.rel] || seen[t.rel]))
            return false;
        seen[t.rel] = true;
        return true;
    });
    n.tabs.forEach(function (t) {
        t.back = t.back.filter(function (r) { return have[r]; });
        t.fwd = t.fwd.filter(function (r) { return have[r]; });
    });
    if (n.tabs.length === 0)
        return init();
    n.active = clamp(n.active, n.tabs.length);
    return n;
}

function setView(s, view) {
    var n = clone(s);
    n.tabs[n.active].view = view;
    return n;
}

function activeView(s) {
    return s.tabs[s.active].view || null;
}

function activeRel(s) {
    return s.tabs[s.active].rel;
}
