import QtQuick
import qs.Common
import "../../js/markdown.js" as Md
import "../../js/mdkeys.js" as MdKeys

// Panel logic, part 2: editing helpers (formatting, edits, paste, editor keys), syntax-highlight state, cursor info.
PanelBase {
    id: ui

    property bool coloringOk: true
    property string hlHtml: ""
    property int cursorLine: 1
    property int cursorCol: 1

    readonly property var hlColors: ({
            heading: Theme.primary.toString(),
            bold: Theme.surfaceText.toString(),
            italic: Theme.surfaceText.toString(),
            code: Theme.secondary.toString(),
            codeBlock: Theme.secondary.toString(),
            link: Theme.primary.toString(),
            wikilink: Theme.primary.toString(),
            tag: Theme.secondary.toString(),
            quote: Theme.surfaceVariantText.toString(),
            marker: Theme.primary.toString(),
            dim: Theme.surfaceVariantText.toString(),
            strike: Theme.surfaceVariantText.toString(),
            task: Theme.primary.toString(),
            highlight: Theme.warning.toString()
        })

    function tint(c) {
        return Qt.tint(Theme.surface, Qt.rgba(c.r, c.g, c.b, 0.22)).toString();
    }

    onHlColorsChanged: refreshHighlight()

    function refreshHighlight() {
        const t = editor.text;
        if (!coloringOk || t.length > 200000) {
            hlHtml = "";
            return;
        }
        hlHtml = '<div style="white-space: pre-wrap;">' + Md.highlightHtml(t, hlColors) + (t.endsWith("\n") ? "&#8203;" : "") + "</div>";
        Qt.callLater(checkAlignment);
    }

    // If the colored layer and the real text ever disagree on height (wrapping differences),
    // fall back to plain text rather than show misaligned colors.
    function checkAlignment() {
        if (!coloringOk || !hlHtml)
            return;
        if (Math.abs(underlay.contentHeight - editor.contentHeight) > 4) {
            coloringOk = false;
            hlHtml = "";
        }
    }

    function updateCursorInfo() {
        const p = editor.cursorPosition;
        const before = editor.text.slice(0, p);
        cursorLine = before.split("\n").length;
        cursorCol = p - before.lastIndexOf("\n");
    }

    function applyEdit(ed) {
        MdKeys.applyEdit(editor, ed);
    }

    function fmt(name) {
        const ed = MdKeys.format(name, editor.text, editor.selectionStart, editor.selectionEnd);
        if (ed) {
            editor.forceActiveFocus();
            applyEdit(ed);
        }
    }

    // Ctrl+V: an image-only clipboard becomes an attachment + ![[embed]]; anything else pastes as text.
    function pasteFromClipboard() {
        core.run(["wl-paste", "--list-types"], (code, out) => {
            const types = out.split("\n");
            const image = types.some(t => t.indexOf("image/") === 0);
            const text = types.some(t => t.indexOf("text/") === 0);
            if (code === 0 && image && !text) {
                const target = core.noteRel;
                core.pasteImage(name => {
                    if (!name)
                        return;
                    if (core.noteRel !== target) {
                        core.toast("Image saved as " + name + " (you switched notes, so it was not inserted)");
                        return;
                    }
                    const p = editor.selectionStart;
                    applyEdit({ start: p, end: editor.selectionEnd, text: "![[" + name + "]]", selStart: p + name.length + 5, selEnd: p + name.length + 5 });
                });
            } else {
                editor.paste();
            }
        });
    }

    function editorKey(event) {
        if (acOpen) {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                acIndex = (acIndex + (event.key === Qt.Key_Down ? 1 : acItems.length - 1)) % acItems.length;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                acAccept();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                acOpen = false;
                event.accepted = true;
                return;
            }
        }
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        if (ctrl && !alt && !shift && event.key === Qt.Key_V) {
            pasteFromClipboard();
            event.accepted = true;
            return;
        }
        const ed = MdKeys.handle(editor.text, editor.selectionStart, editor.selectionEnd, { key: event.key, ctrl: ctrl, shift: shift, alt: alt, text: event.text });
        if (ed) {
            applyEdit(ed);
            event.accepted = true;
        } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && !ctrl && !alt) {
            event.accepted = true;   // Tab never leaves the editor (Ctrl+Tab still cycles tabs)
        }
    }

    function commitProp(key, text, wasList) {
        if (core.conflict || core.noteLoading) {
            core.toast("Resolve the conflict in this note before editing its properties", true);
            return;
        }
        const asList = wasList || key === "tags" || key === "aliases" || key === "cssclasses";
        const value = asList ? text.split(",").map(x => x.trim().replace(/^#/, "")).filter(x => x.length) : text.trim();
        core.applyExternalText(Md.setProperty(core.buffer, key, value));
    }

    property bool syncing: false
}
