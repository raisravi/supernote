.pragma library

// Wikilink resolution and link-safe rewriting (pure; unit-tested in tests/links.test.js).

function depth(p) {
    return p.split("/").length;
}

// key -> rel path. Keys are lower-case and without ".md": the bare name, the full path and every
// trailing folder path (Obsidian's partial paths). When names clash the shortest path
// (then alphabetical) owns the bare/partial key; a full path always resolves to itself.
function buildIndex(paths) {
    var sorted = paths.slice().sort(function (a, b) {
        var d = depth(a) - depth(b);
        return d !== 0 ? d : (a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0));
    });
    var map = {};
    sorted.forEach(function (p) {
        var full = p.toLowerCase().replace(/\.md$/, "");
        var parts = full.split("/");
        for (var k = parts.length - 1; k >= 1; k--) {
            var suffix = parts.slice(k).join("/");
            if (!(suffix in map))
                map[suffix] = p;
        }
        map[full] = p;
    });
    return map;
}

function resolve(map, name) {
    var key = (name || "").toLowerCase().replace(/\.md$/, "");
    return Object.prototype.hasOwnProperty.call(map, key) ? map[key] : null;
}

// Base names of the moved notes: what a linking file must mention to be affected.
function moveTerms(moves) {
    var seen = {};
    var out = [];
    for (var from in moves) {
        var b = from.split("/").pop().replace(/\.md$/i, "");
        if (!seen[b.toLowerCase()]) {
            seen[b.toLowerCase()] = true;
            out.push(b);
        }
    }
    return out;
}

function stripMd(p) {
    return p.replace(/\.md$/i, "");
}

// New link target for a link that pointed at a note now living at `newRel`.
function newTarget(oldTarget, newRel, newMap) {
    var hadMd = /\.md$/i.test(oldTarget);
    var segs = stripMd(oldTarget).split("/").length;
    var newParts = stripMd(newRel).split("/");
    var cands = [newParts.slice(Math.max(0, newParts.length - segs)).join("/"), stripMd(newRel)];
    for (var i = 0; i < cands.length; i++) {
        if (resolve(newMap, cands[i]) === newRel)
            return cands[i] + (hadMd ? ".md" : "");
    }
    return stripMd(newRel) + (hadMd ? ".md" : "");
}

// Rewrite the wikilinks in `text` that resolve (in the old vault, `oldMap`) to a note in `moves`
// ({oldRel: newRel}); `newPaths` is every note path after the move. -> {text, count}
function rewrite(text, oldMap, moves, newPaths) {
    var newMap = buildIndex(newPaths);
    var count = 0;
    var fence = null;
    var lines = text.split("\n").map(function (l) {
        var f = /^\s*(```+|~~~+)/.exec(l);
        if (f) {
            if (!fence)
                fence = f[1].charAt(0);
            else if (f[1].charAt(0) === fence)
                fence = null;
            return l;
        }
        if (fence)
            return l;
        var codeSpans = [];
        l.replace(/`[^`\n]*`/g, function (m, off) { codeSpans.push([off, off + m.length]); return m; });
        return l.replace(/(!?\[\[)([^\]|#\n]*)((?:#[^\]|\n]*)?(?:\|[^\]\n]*)?\]\])/g, function (all, open, target, rest, off) {
            for (var i = 0; i < codeSpans.length; i++)
                if (off >= codeSpans[i][0] && off < codeSpans[i][1])
                    return all;
            var name = target.trim();
            if (!name)
                return all;
            var from = resolve(oldMap, name);
            if (!from || !Object.prototype.hasOwnProperty.call(moves, from))
                return all;
            var to = newTarget(name, moves[from], newMap);
            if (to.toLowerCase() === name.toLowerCase())
                return all;
            count++;
            return open + to + rest;
        });
    });
    return { text: lines.join("\n"), count: count };
}
