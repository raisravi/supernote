import QtQuick
import "../../js/markdown.js" as Md

// Panel logic, part 3: find / replace in the open note.
EditingLayer {
    id: ui

    property bool findOpen: false
    property bool replaceOpen: false
    property bool findCase: false
    property bool findRegex: false
    property var matches: []
    property int matchIndex: -1

    function findOpts() {
        return { caseSensitive: findCase, regex: findRegex };
    }

    function openFind(withReplace) {
        if (!core.noteRel || core.viewMode === "preview")
            return;
        findOpen = true;
        if (withReplace)
            replaceOpen = true;
        const sel = editor.selectedText;
        if (sel.length > 0 && sel.indexOf("\n") < 0)
            findField.text = sel;
        recomputeMatches();
        findField.forceActiveFocus();
        findField.selectAll();
    }

    function closeFind() {
        findOpen = false;
        replaceOpen = false;
        matches = [];
        matchIndex = -1;
        editor.forceActiveFocus();
    }

    function recomputeMatches() {
        matches = Md.findAll(editor.text, findField.text, findOpts());
        if (matches.length === 0) {
            matchIndex = -1;
            return;
        }
        let idx = matches.findIndex(m => m.start >= editor.selectionStart);
        matchIndex = idx < 0 ? 0 : idx;
    }

    function gotoMatch(i) {
        if (matches.length === 0)
            return;
        matchIndex = ((i % matches.length) + matches.length) % matches.length;
        const m = matches[matchIndex];
        editor.select(m.start, m.end);
    }

    function findStep(dir) {
        if (matches.length === 0)
            recomputeMatches();
        if (matches.length === 0)
            return;
        gotoMatch(matchIndex < 0 ? 0 : matchIndex + dir);
    }

    function replaceCurrent() {
        if (matchIndex < 0 || matchIndex >= matches.length)
            return;
        const m = matches[matchIndex];
        const piece = editor.text.slice(m.start, m.end);
        const r = findRegex ? Md.replaceAll(piece, findField.text, replaceField.text, findOpts()).text : replaceField.text;
        applyEdit({ start: m.start, end: m.end, text: r, selStart: m.start + r.length, selEnd: m.start + r.length });
        recomputeMatches();
        if (matches.length > 0)
            gotoMatch(matchIndex);
    }

    function replaceEverything() {
        const r = Md.replaceAll(editor.text, findField.text, replaceField.text, findOpts());
        if (r.count === 0)
            return;
        applyEdit({ start: 0, end: editor.text.length, text: r.text, selStart: 0, selEnd: 0 });
        core.toast("Replaced " + r.count + (r.count === 1 ? " match" : " matches"));
        recomputeMatches();
    }

    readonly property Timer findTimer: Timer {
        interval: 150
        onTriggered: if (ui.findOpen)
            ui.recomputeMatches()
    }
}
