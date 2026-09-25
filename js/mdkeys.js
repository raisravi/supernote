.pragma library
.import "markdown.js" as Md

// Markdown editing keys shared by the main editor and the quick-capture box (pure; tests/mdkeys.test.js).
// `ev` = {key, ctrl, shift, alt, text} with Qt key codes; results are edits {start, end, text, selStart, selEnd}.

var KEY = { Return: 0x01000004, Enter: 0x01000005, Tab: 0x01000001, Backtab: 0x01000002, B: 0x42, I: 0x49, K: 0x4B, L: 0x4C, X: 0x58, C: 0x43, N0: 0x30, N1: 0x31, N6: 0x36, BracketLeft: 0x5B, BracketRight: 0x5D };

// Named formatting command (toolbar buttons, shortcuts, palette) -> edit or null.
function format(name, t, s, e) {
    switch (name) {
    case "bold": return Md.wrapSelection(t, s, e, "**", "**");
    case "italic": return Md.wrapSelection(t, s, e, "*", "*");
    case "strike": return Md.wrapSelection(t, s, e, "~~", "~~");
    case "code": return Md.wrapSelection(t, s, e, "`", "`");
    case "link": return Md.insertLink(t, s, e);
    case "task": return Md.toggleTask(t, s, e);
    case "bullet": return Md.togglePrefix(t, s, e, "- ");
    case "quote": return Md.togglePrefix(t, s, e, "> ");
    case "indent": return Md.indentLines(t, s, e, 1);
    case "outdent": return Md.indentLines(t, s, e, -1);
    }
    if (/^h[0-6]$/.test(name))
        return Md.setHeading(t, s, e, parseInt(name.slice(1), 10));
    return null;
}

function shortcutName(ev) {
    var k = ev.key;
    if (!ev.shift) {
        if (k === KEY.B) return "bold";
        if (k === KEY.I) return "italic";
        if (k === KEY.K) return "link";
        if (k === KEY.L) return "task";
        if (k === KEY.BracketRight) return "indent";
        if (k === KEY.BracketLeft) return "outdent";
        if (k >= KEY.N1 && k <= KEY.N6) return "h" + (k - KEY.N0);
        if (k === KEY.N0) return "h0";
    } else {
        if (k === KEY.X) return "strike";
        if (k === KEY.C) return "code";
    }
    return "";
}

// The edit for a key press, or null when the editor should do its normal thing.
function handle(text, s, e, ev) {
    if (ev.ctrl && !ev.alt)
        return format(shortcutName(ev), text, s, e);
    if (ev.alt || ev.ctrl)
        return null;
    if (ev.key === KEY.Return || ev.key === KEY.Enter) {
        if (ev.shift || s !== e)
            return null;
        return Md.continueList(text, e);
    }
    if (ev.key === KEY.Tab || ev.key === KEY.Backtab)
        return Md.indentLines(text, s, e, (ev.key === KEY.Backtab || ev.shift) ? -1 : 1);
    if (ev.text && ev.text.length === 1)
        return Md.pairInput(text, s, e, ev.text);
    return null;
}

// Replace [start,end) with text, touching only what actually changed (keeps undo tidy).
// `editor` is a TextArea/TextEdit.
function applyEdit(editor, ed) {
    var t = editor.text;
    var oldSlice = t.slice(ed.start, ed.end);
    var a = 0;
    var maxA = Math.min(oldSlice.length, ed.text.length);
    while (a < maxA && oldSlice.charAt(a) === ed.text.charAt(a))
        a++;
    var b = 0;
    var maxB = Math.min(oldSlice.length - a, ed.text.length - a);
    while (b < maxB && oldSlice.charAt(oldSlice.length - 1 - b) === ed.text.charAt(ed.text.length - 1 - b))
        b++;
    var rs = ed.start + a;
    var re = ed.end - b;
    var ins = ed.text.slice(a, ed.text.length - b);
    if (re > rs)
        editor.remove(rs, re);
    if (ins.length)
        editor.insert(rs, ins);
    if (ed.selStart === ed.selEnd)
        editor.cursorPosition = ed.selStart;
    else
        editor.select(ed.selStart, ed.selEnd);
}
