.pragma library

// Pure markdown helpers for SuperNote (no QML types here so they can be unit-tested in node).
// Editing helpers return an "edit": replace [start,end) with `text`, then select [selStart,selEnd).

var INDENT = "    ";

function lineStart(text, i) {
    return i <= 0 ? 0 : text.lastIndexOf("\n", i - 1) + 1;
}

function lineEnd(text, i) {
    var k = text.indexOf("\n", i);
    return k < 0 ? text.length : k;
}

// Lines touched by a selection; a selection ending right after a newline excludes the next line.
function lineSpan(text, s, e) {
    var effEnd = (e > s && text.charAt(e - 1) === "\n") ? e - 1 : e;
    return { start: lineStart(text, s), end: lineEnd(text, effEnd) };
}

// Rewrite whole lines with fn(line) -> newLine; keeps the selection anchored sensibly.
// Prefix-only changes: a caret in/after the changed prefix moves with it. keepStart: a
// selection starting at column 0 stays at column 0 (indent keeps the block selected).
function editLines(text, s, e, fn, keepStart) {
    var span = lineSpan(text, s, e);
    var lines = text.slice(span.start, span.end).split("\n");
    var out = [];
    var firstDelta = 0;
    var total = 0;
    for (var i = 0; i < lines.length; i++) {
        var nl = fn(lines[i], i);
        out.push(nl);
        var d = nl.length - lines[i].length;
        if (i === 0)
            firstDelta = d;
        total += d;
    }
    var selStart = s + firstDelta;
    if (selStart < span.start)
        selStart = span.start;
    if (keepStart && s === span.start)
        selStart = s;
    var selEnd = e + total;
    if (selEnd < selStart)
        selEnd = selStart;
    return { start: span.start, end: span.end, text: out.join("\n"), selStart: selStart, selEnd: selEnd };
}

var LIST_RE = /^(\s*)([-*+]|\d+[.)])(\s+)(\[[ xX]\]\s+)?/;
var TASK_RE = /^(\s*)([-*+]|\d+[.)])(\s+)\[( |x|X)\]\s?/;
var BULLET_RE = /^(\s*)([-*+]|\d+[.)])\s+/;

function wrapSelection(text, s, e, left, right) {
    var ll = left.length, rl = right.length;
    if (s === e)
        return { start: s, end: s, text: left + right, selStart: s + ll, selEnd: s + ll };
    var sel = text.slice(s, e);
    var single = ll === 1 && rl === 1;
    // selection itself carries the markers
    if (sel.length >= ll + rl + 1 && sel.indexOf(left) === 0 && sel.slice(-rl) === right && (!single || (sel.charAt(1) !== left && sel.charAt(sel.length - 2) !== right))) {
        var inner = sel.slice(ll, sel.length - rl);
        return { start: s, end: e, text: inner, selStart: s, selEnd: s + inner.length };
    }
    // markers surround the selection
    if (text.slice(s - ll, s) === left && text.slice(e, e + rl) === right && (!single || (text.charAt(s - ll - 1) !== left && text.charAt(e + rl) !== right))) {
        return { start: s - ll, end: e + rl, text: sel, selStart: s - ll, selEnd: e - ll };
    }
    return { start: s, end: e, text: left + sel + right, selStart: s + ll, selEnd: e + ll };
}

function setHeading(text, s, e, level) {
    var span = lineSpan(text, s, e);
    var lines = text.slice(span.start, span.end).split("\n");
    var allSame = level > 0 && lines.every(function (l) {
        var m = /^(#{1,6})\s+/.exec(l);
        return m && m[1].length === level;
    });
    return editLines(text, s, e, function (line) {
        var stripped = line.replace(/^#{1,6}\s+/, "");
        if (level === 0 || allSame)
            return stripped;
        return new Array(level + 1).join("#") + " " + stripped;
    });
}

function toggleTask(text, s, e) {
    return editLines(text, s, e, function (line) {
        if (TASK_RE.test(line))
            return line.replace(/^(\s*(?:[-*+]|\d+[.)])\s+\[)( |x|X)(\])/, function (_, a, st, c) {
                return a + (st === " " ? "x" : " ") + c;
            });
        var b = BULLET_RE.exec(line);
        if (b)
            return line.slice(0, b[0].length) + "[ ] " + line.slice(b[0].length);
        var indent = /^\s*/.exec(line)[0];
        return indent + "- [ ] " + line.slice(indent.length);
    });
}

// Toggle a literal line prefix ("- ", "> ") after the indent on every selected line.
function togglePrefix(text, s, e, prefix) {
    var span = lineSpan(text, s, e);
    var lines = text.slice(span.start, span.end).split("\n");
    var has = function (l) {
        return l.replace(/^\s*/, "").indexOf(prefix) === 0;
    };
    var allHave = lines.every(function (l) { return l.trim() === "" || has(l); }) && lines.some(has);
    return editLines(text, s, e, function (line) {
        var indent = /^\s*/.exec(line)[0];
        if (allHave)
            return has(line) ? indent + line.slice(indent.length + prefix.length) : line;
        return has(line) ? line : indent + prefix + line.slice(indent.length);
    });
}

function indentLines(text, s, e, dir) {
    if (dir > 0 && s === e && !BULLET_RE.test(text.slice(lineStart(text, s), lineEnd(text, s))))
        return { start: s, end: s, text: INDENT, selStart: s + INDENT.length, selEnd: s + INDENT.length };
    return editLines(text, s, e, function (line) {
        if (dir > 0)
            return line.length ? INDENT + line : line;
        return line.replace(/^( {1,4}|\t)/, "");
    }, true);
}

function continueList(text, cursor) {
    var ls = lineStart(text, cursor);
    var le = lineEnd(text, cursor);
    var line = text.slice(ls, le);
    var caret = cursor - ls;
    var m = LIST_RE.exec(line);
    if (m) {
        if (caret < m[0].length)
            return null;
        var content = line.slice(m[0].length);
        var indent = m[1];
        if (content.trim() === "") {
            var exited = indent.length > 0 ? line.replace(/^( {1,4}|\t)/, "") : "";
            return { start: ls, end: le, text: exited, selStart: ls + exited.length, selEnd: ls + exited.length };
        }
        var marker = m[2];
        var next = /^\d/.test(marker) ? (parseInt(marker, 10) + 1) + marker.slice(-1) : marker;
        var prefix = indent + next + m[3] + (m[4] ? "[ ] " : "");
        return { start: cursor, end: cursor, text: "\n" + prefix, selStart: cursor + 1 + prefix.length, selEnd: cursor + 1 + prefix.length };
    }
    var q = /^(\s*(?:>\s?)+)/.exec(line);
    if (q) {
        if (caret < q[0].length)
            return null;
        if (line.slice(q[0].length).trim() === "")
            return { start: ls, end: le, text: "", selStart: ls, selEnd: ls };
        var qp = q[1].replace(/\s*$/, " ");
        return { start: cursor, end: cursor, text: "\n" + qp, selStart: cursor + 1 + qp.length, selEnd: cursor + 1 + qp.length };
    }
    return null;
}

var OPEN = { "(": ")", "[": "]", "{": "}", "`": "`" };
var CLOSERS = ")]}`";

function pairInput(text, s, e, ch) {
    if (s !== e) {
        if (!OPEN[ch])
            return null;
        var sel = text.slice(s, e);
        return { start: s, end: e, text: ch + sel + OPEN[ch], selStart: s + 1, selEnd: e + 1 };
    }
    var next = text.charAt(s);
    if (CLOSERS.indexOf(ch) >= 0 && next === ch)
        return { start: s, end: s, text: "", selStart: s + 1, selEnd: s + 1 };
    if (OPEN[ch]) {
        if (/\w/.test(next))
            return null;
        return { start: s, end: s, text: ch + OPEN[ch], selStart: s + 1, selEnd: s + 1 };
    }
    return null;
}

function insertLink(text, s, e) {
    if (s === e)
        return { start: s, end: e, text: "[](url)", selStart: s + 1, selEnd: s + 1 };
    var sel = text.slice(s, e);
    if (/^https?:\/\/\S+$/.test(sel))
        return { start: s, end: e, text: "[](" + sel + ")", selStart: s + 1, selEnd: s + 1 };
    var urlStart = s + 1 + sel.length + 2;
    return { start: s, end: e, text: "[" + sel + "](url)", selStart: urlStart, selEnd: urlStart + 3 };
}

// ---------- structure extraction ----------

function parseFrontmatter(text) {
    var none = { props: [], body: text, bodyLine: 0, raw: "" };
    if (!/^---[ \t]*\r?\n/.test(text))
        return none;
    var lines = text.split("\n");
    var end = -1;
    for (var i = 1; i < lines.length; i++) {
        if (/^(---|\.\.\.)[ \t]*\r?$/.test(lines[i])) {
            end = i;
            break;
        }
    }
    if (end < 0)
        return none;
    var props = [];
    var cur = null;
    for (var k = 1; k < end; k++) {
        var line = lines[k].replace(/\r$/, "");
        var item = /^\s+-\s+(.*)$/.exec(line);
        if (item && cur && Array.isArray(cur.value)) {
            cur.value.push(unquote(item[1]));
            continue;
        }
        var kv = /^([A-Za-z0-9_\- ]+):\s*(.*)$/.exec(line);
        if (!kv)
            continue;
        var val = kv[2].trim();
        if (val === "") {
            cur = { key: kv[1].trim(), value: [] };
        } else if (val.charAt(0) === "[" && val.charAt(val.length - 1) === "]") {
            cur = { key: kv[1].trim(), value: val.slice(1, -1).split(",").map(function (x) { return unquote(x.trim()); }).filter(function (x) { return x.length; }) };
        } else {
            cur = { key: kv[1].trim(), value: unquote(val) };
        }
        props.push(cur);
    }
    return { props: props, body: lines.slice(end + 1).join("\n"), bodyLine: end + 1, raw: lines.slice(0, end + 1).join("\n") };
}

function unquote(v) {
    var m = /^(["'])(.*)\1$/.exec(v);
    return m ? m[2] : v;
}

// Calls fn(line, index, inFence) for every body line (frontmatter skipped).
function eachBodyLine(text, fn) {
    var fm = parseFrontmatter(text);
    var lines = text.split("\n");
    var fence = null;
    for (var i = fm.bodyLine; i < lines.length; i++) {
        var l = lines[i];
        var f = /^\s*(```+|~~~+)/.exec(l);
        if (f) {
            if (!fence)
                fence = f[1].charAt(0);
            else if (f[1].charAt(0) === fence)
                fence = null;
            fn(l, i, true);
            continue;
        }
        fn(l, i, fence !== null);
    }
}

function extractHeadings(text) {
    var out = [];
    var offsets = [];
    var pos = 0;
    text.split("\n").forEach(function (l) { offsets.push(pos); pos += l.length + 1; });
    eachBodyLine(text, function (l, i, inFence) {
        if (inFence)
            return;
        var m = /^(#{1,6})\s+(.*\S)\s*$/.exec(l);
        if (m)
            out.push({ level: m[1].length, text: m[2].replace(/\s+#+$/, ""), line: i, offset: offsets[i] });
    });
    return out;
}

function extractTags(text) {
    var seen = {};
    var out = [];
    function add(t) {
        if (t && !seen[t]) {
            seen[t] = true;
            out.push(t);
        }
    }
    parseFrontmatter(text).props.forEach(function (p) {
        if (p.key === "tags" || p.key === "tag") {
            var vals = Array.isArray(p.value) ? p.value : String(p.value).split(",");
            vals.forEach(function (v) { add(v.trim().replace(/^#/, "")); });
        }
    });
    eachBodyLine(text, function (l, i, inFence) {
        if (inFence)
            return;
        var clean = l.replace(/`[^`]*`/g, " ").replace(/https?:\/\/\S+/g, " ");
        var re = /(^|\s)#([A-Za-z_][\w\/-]*)/g;
        var m;
        while ((m = re.exec(clean)) !== null)
            add(m[2]);
    });
    return out;
}

// ---------- find / replace ----------

function makeRegex(query, opts) {
    if (!query)
        return null;
    var src = opts && opts.regex ? query : query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    try {
        return new RegExp(src, "g" + (opts && opts.caseSensitive ? "" : "i"));
    } catch (e) {
        return null;
    }
}

function findAll(text, query, opts) {
    var re = makeRegex(query, opts);
    if (!re)
        return [];
    var out = [];
    var m;
    while ((m = re.exec(text)) !== null) {
        if (m[0].length === 0) {
            re.lastIndex++;
            continue;
        }
        out.push({ start: m.index, end: m.index + m[0].length });
    }
    return out;
}

function replaceAll(text, query, repl, opts) {
    var re = makeRegex(query, opts);
    if (!re)
        return { text: text, count: 0 };
    var count = 0;
    var result = text.replace(re, function () {
        count++;
        if (opts && opts.regex) {
            var args = Array.prototype.slice.call(arguments);
            var groups = args.slice(0, args.length - 2);
            return repl.replace(/\$(\d+|&)/g, function (_, g) {
                return g === "&" ? groups[0] : (groups[parseInt(g, 10)] || "");
            });
        }
        return repl;
    });
    return { text: result, count: count };
}

function toggleCheckboxAtLine(text, lineNo) {
    var lines = text.split("\n");
    var l = lines[lineNo];
    if (l === undefined)
        return text;
    var m = /^(\s*(?:[-*+]|\d+[.)])\s+\[)( |x|X)(\].*)$/.exec(l);
    if (!m)
        return text;
    lines[lineNo] = m[1] + (m[2] === " " ? "x" : " ") + m[3];
    return lines.join("\n");
}

// ---------- preview preprocessing ----------
// Turns Obsidian-flavoured markdown into markdown Qt's Text.MarkdownText can render.
// Special link schemes (handled by the UI): sn-note:<name>[#heading], sn-tag:<tag>,
// sn-task:<original line number>.

var SUPERSCRIPT = "⁰¹²³⁴⁵⁶⁷⁸⁹";
var IMAGE_EXT = /\.(png|jpe?g|gif|webp|svg|bmp|avif)$/i;
var CALLOUT_ICONS = {
    note: "ⓘ", info: "ⓘ", abstract: "≡", summary: "≡", tldr: "≡", todo: "☐", tip: "✦", hint: "✦", important: "‼",
    success: "✔", check: "✔", done: "✔", question: "?", help: "?", faq: "?", warning: "⚠", caution: "⚠", attention: "⚠",
    failure: "✖", fail: "✖", missing: "✖", danger: "✖", error: "✖", bug: "✱", example: "◆", quote: "❝", cite: "❝"
};

function superscript(n) {
    return String(n).split("").map(function (d) { return SUPERSCRIPT.charAt(parseInt(d, 10)); }).join("");
}

function fileUrl(vaultAbs, rel) {
    return "file://" + (vaultAbs + "/" + rel).split("/").map(encodeURIComponent).join("/");
}

function safeDecode(s) {
    try {
        return decodeURIComponent(s);
    } catch (e) {
        return s;
    }
}

function encodeTarget(s) {
    return encodeURIComponent(s).replace(/\(/g, "%28").replace(/\)/g, "%29");
}

function noteLink(label, name, heading) {
    return "[" + label + "](sn-note:" + encodeTarget(name) + (heading ? "#" + encodeTarget(heading) : "") + ")";
}

function isBlockStart(line) {
    return /^\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|>|\||```|~~~|(-{3,}|\*{3,}|_{3,})\s*$|<|    |\t)/.test(line);
}

function renderPreview(text, ctx) {
    ctx = ctx || {};
    var depth = ctx.depth || 0;
    var fm = parseFrontmatter(text);
    var srcLines = fm.body.split("\n");

    // pass 1: footnote definitions (outside code fences)
    var defs = {};
    var fence = null;
    var kept = [];
    for (var i = 0; i < srcLines.length; i++) {
        var l = srcLines[i];
        var f = /^\s*(```+|~~~+)/.exec(l);
        if (f) {
            fence = !fence ? f[1].charAt(0) : (f[1].charAt(0) === fence ? null : fence);
            kept.push({ line: l, idx: i, fence: true });
            continue;
        }
        var d = !fence && /^\[\^([^\]\s]+)\]:\s*(.*)$/.exec(l);
        if (d) {
            defs[d[1]] = d[2];
            continue;
        }
        kept.push({ line: l, idx: i, fence: fence !== null });
    }

    var refIndex = {};
    var refOrder = [];
    function footRef(label) {
        if (!(label in defs))
            return null;
        if (!(label in refIndex)) {
            refOrder.push(label);
            refIndex[label] = refOrder.length;
        }
        return superscript(refIndex[label]);
    }

    function inline(seg) {
        // embeds (images / files); whole-line note embeds are handled before this
        seg = seg.replace(/!\[\[([^\]|#\n]+)(?:#[^\]|\n]*)?(?:\|([^\]\n]*))?\]\]/g, function (_, name, extra) {
            name = name.trim();
            if (IMAGE_EXT.test(name)) {
                var rel = ctx.resolveAsset ? ctx.resolveAsset(name, ctx.noteDir || "") : null;
                var size = extra && /^\d+$/.test(extra.trim()) ? "|" + extra.trim() : "";
                return rel ? "![" + name + size + "](" + fileUrl(ctx.vaultAbs || "", rel) + ")" : "*[missing image: " + name + "]*";
            }
            return noteLink(name, name);
        });
        seg = seg.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, function (all, alt, path) {
            if (/^[a-z][a-z0-9+.-]*:/i.test(path))
                return all;
            var rel = ctx.resolveAsset ? ctx.resolveAsset(safeDecode(path), ctx.noteDir || "") : null;
            return rel ? "![" + alt + "](" + fileUrl(ctx.vaultAbs || "", rel) + ")" : all;
        });
        seg = seg.replace(/\[\[([^\]|#\n]+)(?:#([^\]|\n]*))?(?:\|([^\]\n]*))?\]\]/g, function (_, name, heading, alias) {
            name = name.trim();
            var label = alias ? alias : (heading ? name + " > " + heading : name);
            return noteLink(label, name, heading);
        });
        seg = seg.replace(/\[\^([^\]\s]+)\]/g, function (all, label) {
            var s = footRef(label);
            return s === null ? all : s;
        });
        seg = seg.replace(/(^|\s)#([A-Za-z_][\w\/-]*)/g, function (_, ws, tag) {
            return ws + "[#" + tag + "](sn-tag:" + encodeURIComponent(tag) + ")";
        });
        return seg;
    }

    // ctx.diagram(kind, src, display) -> {url, w} once the picture exists (else null and a render is started)
    function picture(kind, src, display) {
        var e = ctx.diagram ? ctx.diagram(kind, src, display) : null;
        return e ? "![" + kind + "|" + e.w + "](" + e.url + ")" : null;
    }

    // $x^2$ (not prices like "$5 and $6", not \$ escapes, not inside code)
    function inlineMath(seg) {
        if (!ctx.diagram || seg.indexOf("$") < 0)
            return seg;
        seg = seg.replace(/(^|[^\\$])\$\$([^$\n]+?)\$\$/g, function (all, lead, src) {
            var img = src.trim() !== "" ? picture("math", src.trim(), true) : null;
            return img ? lead + img : all;
        });
        return seg.replace(/(^|[^\\$])\$([^\s$][^$\n]*?[^\s$\\]|[^\s$\\])\$(?!\d)/g, function (all, lead, src) {
            if (/^\d[\d.,]*\s+[A-Za-z]{2,}\b/.test(src))
                return all;   // "$5 and 5$": prices, not a formula
            var img = picture("math", src, false);
            return img ? lead + img : all;
        });
    }

    function inlineOutsideCode(line) {
        var parts = line.split(/(`[^`\n]*`)/);
        for (var p = 0; p < parts.length; p += 2)
            parts[p] = inline(inlineMath(parts[p])).replace(/==([^=\n]+)==/g, "\uE000$1\uE001");
        return parts.join("");
    }

    // ```mermaid fences and $$ blocks that already have a picture become one image line
    function diagramBlocks(items) {
        var res = [];
        var inFence = false;
        for (var a = 0; a < items.length; a++) {
            var it = items[a];
            if (it.fence) {
                var open = !inFence && /^\s*(```+|~~~+)\s*mermaid\s*$/i.test(it.line);
                var fm = /^\s*(```+|~~~+)/.exec(it.line);
                if (open) {
                    var z = -1;
                    var marker = fm[1].charAt(0);
                    for (var b = a + 1; b < items.length; b++) {
                        var cl = /^\s*(```+|~~~+)\s*$/.exec(items[b].line);
                        if (items[b].fence && cl && cl[1].charAt(0) === marker) {
                            z = b;
                            break;
                        }
                    }
                    if (z > 0) {
                        var msrc = items.slice(a + 1, z).map(function (x) { return x.line; }).join("\n");
                        var mimg = picture("mermaid", msrc, true);
                        if (mimg) {
                            res.push({ line: mimg, idx: it.idx, fence: false, raw: true });
                            a = z;
                            continue;
                        }
                    }
                }
                if (fm)
                    inFence = !inFence;
                res.push(it);
                continue;
            }
            var t = it.line.trim();
            if (t.indexOf("$$") === 0) {
                var one = /^\$\$([^$]+)\$\$$/.exec(t);
                var src = null;
                var last = a;
                if (one) {
                    src = one[1];
                } else {
                    var body = [t.slice(2)];
                    for (var c = a + 1; c < items.length && c < a + 200 && !items[c].fence; c++) {
                        var ct = items[c].line.trim();
                        if (ct.slice(-2) === "$$") {
                            body.push(ct.slice(0, -2));
                            src = body.join("\n").replace(/^\n+|\n+$/g, "");
                            last = c;
                            break;
                        }
                        body.push(items[c].line);
                    }
                }
                var dimg = src !== null && src.trim() !== "" ? picture("math", src.trim(), true) : null;
                if (dimg) {
                    res.push({ line: dimg, idx: it.idx, fence: false, raw: true });
                    a = last;
                    continue;
                }
            }
            res.push(it);
        }
        return res;
    }

    if (ctx.diagram)
        kept = diagramBlocks(kept);

    var out = [];
    for (var k = 0; k < kept.length; k++) {
        var item = kept[k];
        var line = item.line;
        if (item.fence || item.raw) {
            out.push(line);
            continue;
        }
        var m;
        // whole-line note embed
        if ((m = /^\s*!\[\[([^\]|#\n]+)(?:#[^\]|\n]*)?(?:\|[^\]\n]*)?\]\]\s*$/.exec(line)) && !IMAGE_EXT.test(m[1].trim()) && !/\.[A-Za-z0-9]{2,4}$/.test(m[1].trim())) {
            var name = m[1].trim();
            var body = depth < 1 && ctx.getEmbed ? ctx.getEmbed(name) : null;
            if (body === null || body === undefined) {
                out.push(noteLink(name, name));
            } else {
                var sub = renderPreview(body, { vaultAbs: ctx.vaultAbs, noteDir: ctx.noteDir, resolveAsset: ctx.resolveAsset, resolveNote: ctx.resolveNote, getEmbed: ctx.getEmbed, diagram: ctx.diagram, depth: depth + 1 });
                out.push("> **" + name + "**", ">");
                sub.markdown.split("\n").forEach(function (sl) { out.push(sl === "" ? ">" : "> " + sl); });
            }
            continue;
        }
        // callout header
        if ((m = /^\s*>\s*\[!([A-Za-z-]+)\][+-]?\s*(.*)$/.exec(line))) {
            var type = m[1].toLowerCase();
            var title = m[2].trim() || (type.charAt(0).toUpperCase() + type.slice(1));
            out.push("> **" + (CALLOUT_ICONS[type] || "ⓘ") + " " + inlineOutsideCode(title) + "**  ");
            continue;
        }
        // task list item
        if ((m = /^(\s*(?:[-*+]|\d+[.)])\s+)\[( |x|X)\](\s.*|)$/.exec(line))) {
            var glyph = m[2] === " " ? "☐" : "☑";
            var box = depth > 0 ? glyph : "[" + glyph + "](sn-task:" + (fm.bodyLine + item.idx) + ")";
            out.push(m[1] + box + inlineOutsideCode(m[3]));
            continue;
        }
        out.push(inlineOutsideCode(line));
    }

    // Obsidian shows single newlines inside a paragraph as line breaks
    var fenceOpen = false;
    for (var n = 0; n < out.length - 1; n++) {
        var ol = out[n];
        if (/^\s*(```+|~~~+)/.test(ol)) {
            fenceOpen = !fenceOpen;
            continue;
        }
        if (fenceOpen || ol.trim() === "" || / $/.test(ol))
            continue;
        if (/^\s*>+\s?\S/.test(ol)) {
            if (/^\s*>+\s?\S/.test(out[n + 1]))
                out[n] = ol + "  ";
            continue;
        }
        if (isBlockStart(ol))
            continue;
        var nx = out[n + 1];
        if (nx.trim() !== "" && !isBlockStart(nx) && !/^\s*(```+|~~~+)/.test(nx))
            out[n] = ol + "  ";
    }

    var result = out.join("\n");
    if (refOrder.length > 0) {
        result += "\n\n---\n\n" + refOrder.map(function (label, idx) {
            return (idx + 1) + ". " + defs[label];
        }).join("\n");
    }
    return { markdown: result, props: fm.props, bodyLine: fm.bodyLine };
}

// ---------- syntax highlighting (colored underlay behind the editor) ----------
// Returns HTML whose visible text is exactly `text` (only spans/bold/italic are added), so it can
// sit pixel-aligned behind a transparent text editor. colors: {heading, bold, italic, code,
// codeBlock, link, wikilink, tag, quote, marker, dim, strike, task, highlight}.

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function span(color, html) {
    return '<span style="color:' + color + '">' + html + "</span>";
}

var INLINE_SRC = "(`[^`\\n]+`)|(!?\\[\\[[^\\]\\n]+\\]\\])|(\\[[^\\]\\n]*\\]\\([^)\\n]*\\))|(\\*\\*[^*\\n]+\\*\\*|__[^_\\n]+__)|(~~[^~\\n]+~~)|(==[^=\\n]+==)|(\\*[^*\\s][^*\\n]*\\*|_[^_\\s][^_\\n]*_)|(\\[\\^[^\\]\\n]+\\])|((?:^|\\s)#[A-Za-z_][\\w/-]*)";

function inlineHtml(line, c, base) {
    var out = "";
    var pos = 0;
    var re = new RegExp(INLINE_SRC, "g");
    var m;
    function plain(t) {
        return base ? span(base, esc(t)) : esc(t);
    }
    while ((m = re.exec(line)) !== null) {
        var start = m.index;
        var tok = m[0];
        var lead = "";
        if (m[9]) {
            if (/^\s/.test(tok)) {
                lead = tok.charAt(0);
                tok = tok.slice(1);
                start += 1;
            }
        }
        var underscore = (m[4] || m[7]) && tok.charAt(0) === "_";
        if (underscore && (/\w/.test(line.charAt(start - 1)) || /\w/.test(line.charAt(start + tok.length)))) {
            re.lastIndex = start + 1;
            continue;
        }
        out += plain(line.slice(pos, start - lead.length)) + (lead ? plain(lead) : "");
        var body = esc(tok);
        if (m[1])
            out += span(c.code, body);
        else if (m[2])
            out += span(c.wikilink, body);
        else if (m[3])
            out += span(c.link, body);
        else if (m[4])
            out += "<b>" + span(c.bold, body) + "</b>";
        else if (m[5])
            out += span(c.strike, body);
        else if (m[6])
            out += span(c.highlight, body);
        else if (m[7])
            out += "<i>" + span(c.italic, body) + "</i>";
        else if (m[8])
            out += span(c.link, body);
        else
            out += span(c.tag, body);
        pos = start + tok.length;
        re.lastIndex = pos;
    }
    return out + plain(line.slice(pos));
}

function highlightHtml(text, c) {
    var fm = parseFrontmatter(text);
    var lines = text.split("\n");
    var fence = null;
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var m;
        if (i < fm.bodyLine) {
            out.push(span(c.dim, esc(line)));
            continue;
        }
        var f = /^\s*(```+|~~~+)/.exec(line);
        if (f) {
            fence = !fence ? f[1].charAt(0) : (f[1].charAt(0) === fence ? null : fence);
            out.push(span(c.codeBlock, esc(line)));
            continue;
        }
        if (fence) {
            out.push(span(c.codeBlock, esc(line)));
            continue;
        }
        if (/^#{1,6}\s/.test(line)) {
            out.push("<b>" + span(c.heading, esc(line)) + "</b>");
        } else if (/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) {
            out.push(span(c.dim, esc(line)));
        } else if ((m = /^(\s*>[> ]*)/.exec(line))) {
            out.push(span(c.marker, esc(m[1])) + inlineHtml(line.slice(m[1].length), c, c.quote));
        } else if ((m = /^(\s*)([-*+]|\d+[.)])(\s+)(\[[ xX]\])?/.exec(line))) {
            out.push(esc(m[1]) + span(c.marker, esc(m[2])) + esc(m[3]) + (m[4] ? span(c.task, esc(m[4])) : "") + inlineHtml(line.slice(m[0].length), c, null));
        } else {
            out.push(inlineHtml(line, c, null));
        }
    }
    return out.join("\n");
}

// ---------- wikilinks: extraction, autocomplete, heading lookup ----------

// Wikilinks (and embeds) in the note body; code and frontmatter are skipped.
function extractLinks(text) {
    var out = [];
    eachBodyLine(text, function (l, i, inFence) {
        if (inFence)
            return;
        var clean = l.replace(/`[^`\n]*`/g, function (m) { return new Array(m.length + 1).join(" "); });
        var re = /(!?)\[\[([^\]|#\n]*)(?:#([^\]|\n]*))?(?:\|([^\]\n]*))?\]\]/g;
        var m;
        while ((m = re.exec(clean)) !== null) {
            var name = m[2].trim();
            if (!name)
                continue;
            out.push({ name: name, heading: (m[3] || "").trim(), alias: (m[4] || "").trim(), embed: m[1] === "!", line: i });
        }
    });
    return out;
}

// Caret inside an unfinished [[ ... ? -> {start, query}; the alias/heading parts are not completed.
function linkContext(text, cursor) {
    var ls = lineStart(text, cursor);
    var before = text.slice(ls, cursor);
    var open = before.lastIndexOf("[[");
    if (open < 0)
        return null;
    var query = before.slice(open + 2);
    if (/[\]|#\[]/.test(query))
        return null;
    return { start: ls + open + 2, query: query };
}

function completeLink(text, cursor, name) {
    var ctx = linkContext(text, cursor);
    if (!ctx)
        return null;
    var end = cursor;
    var k = 0;
    while (k < 2 && text.charAt(end) === "]") {
        end++;
        k++;
    }
    var pos = ctx.start + name.length + 2;
    return { start: ctx.start, end: end, text: name + "]]", selStart: pos, selEnd: pos };
}

function headingOffset(text, heading) {
    var norm = function (s) { return s.trim().toLowerCase().replace(/\s+/g, " "); };
    var want = norm(heading);
    var hs = extractHeadings(text);
    for (var i = 0; i < hs.length; i++) {
        if (norm(hs[i].text) === want)
            return hs[i].offset;
    }
    return -1;
}

// ---------- properties (frontmatter) editing ----------

function yamlScalar(v) {
    v = String(v);
    if (v === "" || /^[\s\[\]{}#&*!|>'"%@`,-]|:\s|:$|\s#|\s$/.test(v))
        return '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
    return v;
}

function listItem(x) {
    x = String(x);
    return /[,\]]/.test(x) ? '"' + x.replace(/"/g, '\\"') + '"' : yamlScalar(x);
}

function propLines(key, value) {
    if (Array.isArray(value))
        return [key + ": [" + value.map(listItem).join(", ") + "]"];
    return [key + ": " + yamlScalar(value)];
}

// Frontmatter line span: {lines, end} (end = index of the closing fence) or null.
function fmSpan(text) {
    var fm = parseFrontmatter(text);
    if (fm.bodyLine === 0)
        return null;
    return { lines: text.split("\n"), end: fm.bodyLine - 1 };
}

// Lines [from, to) holding `key` (its value line plus any indented / "- item" continuation lines).
function keyLines(lines, end, key) {
    var re = /^([A-Za-z0-9_\- ]+):/;
    for (var i = 1; i < end; i++) {
        var m = re.exec(lines[i]);
        if (m && m[1].trim() === key) {
            var j = i + 1;
            while (j < end && !re.test(lines[j]))
                j++;
            return [i, j];
        }
    }
    return null;
}

function setProperty(text, key, value) {
    var sp = fmSpan(text);
    if (!sp)
        return "---\n" + propLines(key, value).join("\n") + "\n---\n" + text;
    var at = keyLines(sp.lines, sp.end, key);
    var repl = propLines(key, value);
    if (at)
        sp.lines.splice.apply(sp.lines, [at[0], at[1] - at[0]].concat(repl));
    else
        sp.lines.splice.apply(sp.lines, [sp.end, 0].concat(repl));
    return sp.lines.join("\n");
}

function removeProperty(text, key) {
    var sp = fmSpan(text);
    if (!sp)
        return text;
    var at = keyLines(sp.lines, sp.end, key);
    if (!at)
        return text;
    sp.lines.splice(at[0], at[1] - at[0]);
    if (sp.lines[1] !== undefined && /^(---|\.\.\.)[ \t]*\r?$/.test(sp.lines[1]))
        return sp.lines.slice(2).join("\n");
    return sp.lines.join("\n");
}
