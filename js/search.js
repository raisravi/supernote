.pragma library

// Full-text search presentation helpers (the search itself is `rg` in supernote-vault.sh).
// Smart case like rg -S: an all-lower-case query ignores case, otherwise it is exact.

function matchRanges(text, query) {
    var out = [];
    if (!query)
        return out;
    var exact = query !== query.toLowerCase();
    var hay = exact ? text : text.toLowerCase();
    var needle = exact ? query : query.toLowerCase();
    var i = 0;
    while ((i = hay.indexOf(needle, i)) >= 0) {
        out.push([i, i + needle.length]);
        i += needle.length;
    }
    return out;
}

// Trim a matched line to `max` chars around its first match; ranges follow the trimming.
function snippet(text, ranges, max) {
    var lead = text.length - text.replace(/^\s+/, "").length;
    var t = text.slice(lead).replace(/\s+$/, "");
    var rs = ranges.map(function (r) { return [r[0] - lead, r[1] - lead]; }).filter(function (r) { return r[1] > 0; });
    rs = rs.map(function (r) { return [Math.max(0, r[0]), Math.min(t.length, r[1])]; });
    if (t.length <= max)
        return { text: t, ranges: rs };
    var first = rs.length ? rs[0][0] : 0;
    var start = Math.max(0, Math.min(first - Math.floor(max / 4), t.length - max));
    var end = Math.min(t.length, start + max);
    var pre = start > 0 ? "…" : "";
    var post = end < t.length ? "…" : "";
    var out = [];
    rs.forEach(function (r) {
        if (r[1] <= start || r[0] >= end)
            return;
        out.push([Math.max(r[0], start) - start + pre.length, Math.min(r[1], end) - start + pre.length]);
    });
    return { text: pre + t.slice(start, end) + post, ranges: out };
}

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Qt StyledText: matches are bold + colored (StyledText has no background color).
function snippetHtml(text, query, color, max) {
    var sn = snippet(text, matchRanges(text, query), max || 120);
    var html = "";
    var pos = 0;
    sn.ranges.forEach(function (r) {
        html += escapeHtml(sn.text.slice(pos, r[0]));
        html += '<b><font color="' + color + '">' + escapeHtml(sn.text.slice(r[0], r[1])) + "</font></b>";
        pos = r[1];
    });
    return html + escapeHtml(sn.text.slice(pos));
}

// [{path, line, text}] -> [{path, matches: [{line, text}]}] in first-seen order.
function group(results) {
    var byPath = {};
    var out = [];
    results.forEach(function (r) {
        if (!byPath[r.path]) {
            byPath[r.path] = { path: r.path, matches: [] };
            out.push(byPath[r.path]);
        }
        byPath[r.path].matches.push({ line: r.line, text: r.text });
    });
    return out;
}

function flatRows(groups, collapsed) {
    var rows = [];
    groups.forEach(function (g) {
        rows.push({ kind: "file", path: g.path, count: g.matches.length, collapsed: !!collapsed[g.path] });
        if (!collapsed[g.path])
            g.matches.forEach(function (m) { rows.push({ kind: "match", path: g.path, line: m.line, text: m.text }); });
    });
    return rows;
}
