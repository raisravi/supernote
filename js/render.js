.pragma library

// Diagram/math render cache helpers (pure; tests/render.test.js). Rendering itself is supernote-render.sh.

// 64-bit-ish FNV-1a as 16 hex chars (two independent 32-bit lanes).
function hash(str) {
    var h1 = 0x811c9dc5, h2 = 0x01000193 ^ 0x9e3779b9;
    for (var i = 0; i < str.length; i++) {
        var c = str.charCodeAt(i);
        h1 = Math.imul(h1 ^ c, 0x01000193) >>> 0;
        h2 = Math.imul(h2 ^ c ^ (i & 0xff), 0x85ebca6b) >>> 0;
    }
    return ("00000000" + h1.toString(16)).slice(-8) + ("00000000" + h2.toString(16)).slice(-8);
}

// style: {display, fg: "#rrggbb", dark}. Includes everything that changes the picture.
function key(kind, src, style) {
    var s = [kind, style.display ? "1" : "0", style.fg, style.dark ? "d" : "l", src.length, src].join("\u0001");
    return kind + "-" + hash(s);
}

function hex(r, g, b) {
    function p(x) {
        var v = Math.round(Math.max(0, Math.min(1, x)) * 255);
        return (v < 16 ? "0" : "") + v.toString(16);
    }
    return "#" + p(r) + p(g) + p(b);
}

function isDark(r, g, b) {
    return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.5;
}

// Pictures are rendered at 2x for crispness: shown at half size, never wider than the pane (0 = no limit).
function shownWidth(pxW, maxWidth) {
    var w = Math.max(1, Math.round(pxW / 2));
    return maxWidth > 0 ? Math.min(w, maxWidth) : w;
}

function parseDims(out) {
    var m = /^\s*(\d+)\s+(\d+)\s*$/.exec(out || "");
    if (!m || parseInt(m[1], 10) < 1 || parseInt(m[2], 10) < 1)
        return null;
    return { w: parseInt(m[1], 10), h: parseInt(m[2], 10) };
}
