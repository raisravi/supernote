.pragma library

// Small fuzzy matcher for the quick switcher / autocomplete / command palette.
// match(query, text) -> {score, positions} | null  (case-insensitive subsequence, best alignment).
// rank(items, query, limit) -> [{item, score, positions}] best first; items are {name, path}.

var NEG = -1e9;

function isBoundary(text, j) {
    if (j === 0)
        return true;
    var p = text.charAt(j - 1);
    var c = text.charAt(j);
    return " -_/.".indexOf(p) >= 0 || (p === p.toLowerCase() && c !== c.toLowerCase() && c === c.toUpperCase() && /[A-Za-z]/.test(c));
}

function match(query, text) {
    var q = query.toLowerCase();
    var t = text.toLowerCase();
    var n = q.length;
    var m = t.length;
    if (n === 0)
        return { score: 0, positions: [] };
    if (n > m)
        return null;
    // best[i][j]: best score with q[i] matched at t[j]; from[i][j] = previous match position
    var best = [];
    var from = [];
    for (var i = 0; i < n; i++) {
        best.push(new Array(m).fill(NEG));
        from.push(new Array(m).fill(-1));
        for (var j = 0; j < m; j++) {
            if (q.charAt(i) !== t.charAt(j))
                continue;
            var base = 16 + (isBoundary(text, j) ? 8 : 0) + (j === 0 ? 6 : 0);
            if (i === 0) {
                best[i][j] = base - Math.min(j, 10) * 0.3;
                continue;
            }
            var top = NEG;
            var arg = -1;
            for (var k = 0; k < j; k++) {
                if (best[i - 1][k] === NEG)
                    continue;
                var gap = j - k - 1;
                var s = best[i - 1][k] + (gap === 0 ? 12 : -Math.min(gap, 6));
                if (s > top) {
                    top = s;
                    arg = k;
                }
            }
            if (arg >= 0) {
                best[i][j] = top + base;
                from[i][j] = arg;
            }
        }
    }
    var endJ = -1;
    var score = NEG;
    for (var e = 0; e < m; e++) {
        if (best[n - 1][e] > score) {
            score = best[n - 1][e];
            endJ = e;
        }
    }
    if (endJ < 0)
        return null;
    var positions = [];
    var cur = endJ;
    for (var r = n - 1; r >= 0; r--) {
        positions.unshift(cur);
        cur = from[r][cur];
    }
    return { score: score - m * 0.05, positions: positions };
}

function rank(items, query, limit) {
    var out = [];
    for (var i = 0; i < items.length; i++) {
        var it = items[i];
        var mn = match(query, it.name);
        if (mn) {
            out.push({ item: it, score: mn.score, positions: mn.positions, order: i });
            continue;
        }
        var mp = it.path ? match(query, it.path) : null;
        if (mp)
            out.push({ item: it, score: mp.score * 0.5 - 20, positions: [], order: i });
    }
    if (query === "") {
        out.sort(function (a, b) { return a.order - b.order; });
    } else {
        out.sort(function (a, b) { return b.score - a.score || a.order - b.order; });
    }
    if (limit && out.length > limit)
        out = out.slice(0, limit);
    return out.map(function (r) { return { item: r.item, score: r.score, positions: r.positions }; });
}
