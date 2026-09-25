import QtQuick
import "../../js/tree.js" as Tree
import "../../js/markdown.js" as Md

// The open note: buffer, dirty/conflict state, autosave (1 s), save/flush with mtime conflict detection,
// external-change check, view mode and per-note UI toggles. Everything that replaces the buffer goes through
// `safely()` so unsaved text is never lost.
VaultLayer {
    id: root

    function loadNoteState() {
        viewMode = readState("viewMode", "edit");
        showToolbar = readState("showToolbar", true);
        propsOpen = readState("propsOpen", false);
    }

    property string noteRel: ""
    property string buffer: ""
    property bool dirty: false
    property int editSerial: 0
    property int loadSerial: 0
    property int openSerial: 0
    property bool noteLoading: false
    property int baselineMtime: 0
    property bool conflict: false
    property int focusSerial: 0
    property string focusTarget: "editor"
    property string viewMode: "edit"
    property bool showToolbar: true
    property int editorSetSerial: 0
    readonly property string noteTitle: noteRel ? Tree.baseName(noteRel) : ""

    function setViewMode(mode) {
        if (["edit", "split", "preview"].indexOf(mode) < 0)
            return;
        viewMode = mode;
        writeState("viewMode", mode);
    }

    function cycleViewMode() {
        setViewMode(viewMode === "edit" ? "split" : (viewMode === "split" ? "preview" : "edit"));
    }

    property bool propsOpen: false

    function toggleProps() {
        propsOpen = !propsOpen;
        writeState("propsOpen", propsOpen);
    }

    function toggleToolbar() {
        showToolbar = !showToolbar;
        writeState("showToolbar", showToolbar);
    }

    // Change the buffer from outside the editor (e.g. ticking a checkbox in the preview).
    function applyExternalText(text) {
        if (!noteRel || noteLoading || conflict || text === buffer)
            return;
        buffer = text;
        dirty = true;
        editSerial++;
        editorSetSerial++;
        saveTimer.restart();
    }

    function toggleTaskLine(lineNo) {
        applyExternalText(Md.toggleCheckboxAtLine(buffer, lineNo));
    }

    function closeNoteNow() {
        openSerial++;
        noteRel = "";
        buffer = "";
        dirty = false;
        conflict = false;
        baselineMtime = 0;
        loadSerial++;
    }

    function refreshMtime(cb) {
        if (!noteRel) {
            if (cb)
                cb(0);
            return;
        }
        vaultRun("mtime", [noteRel], (code, out) => {
            baselineMtime = code === 0 ? parseInt(out) || 0 : 0;
            if (cb)
                cb(baselineMtime);
        });
    }

    function onEdited(text) {
        if (!noteRel || noteLoading)
            return;
        buffer = text;
        dirty = true;
        editSerial++;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: root.saveNow()
    }

    // Save pending edits; cb(ok) is false when they could not be saved (conflict / write failure),
    // so callers about to replace the buffer must not go on.
    function flushSave(cb) {
        saveTimer.stop();
        if (!noteRel || !dirty) {
            if (cb)
                cb(true);
            return;
        }
        if (conflict) {
            if (cb)
                cb(false);
            return;
        }
        saveNow(ok => {
            if (ok && dirty && !conflict) {
                flushSave(cb); // typed while the write was in flight
                return;
            }
            if (cb)
                cb(ok && !dirty);
        });
    }

    // flushSave that only continues when the buffer is safely on disk.
    function safely(cb, abort) {
        flushSave(ok => {
            if (ok) {
                cb();
                return;
            }
            pendingHeading = "";
            pendingLine = "";
            toast("Unsaved changes: resolve the conflict or save failure first", true);
            if (abort)
                abort();
        });
    }

    function saveNow(cb) {
        saveTimer.stop();
        if (!noteRel || !dirty) {
            if (cb)
                cb(true);
            return;
        }
        const rel = noteRel;
        const text = buffer;
        const serial = editSerial;
        vaultRun("mtime", [rel], (code, out) => {
            const m = code === 0 ? parseInt(out) || 0 : 0;
            if (baselineMtime && m && m !== baselineMtime) {
                conflict = true;
                if (cb)
                    cb(false);
                return;
            }
            const saved = ok => {
                if (!ok) {
                    toast("Could not save " + rel, true);
                    if (cb)
                        cb(false);
                    return;
                }
                delete embedCache[activeVault + "/" + rel];
                if (tagsWanted) {
                    const nt = clone(noteTags);
                    nt[rel] = Md.extractTags(text);
                    noteTags = nt;
                }
                if (rel === noteRel && serial === editSerial)
                    dirty = false;
                refreshMtime(() => {
                    if (cb)
                        cb(true);
                });
            };
            writeFile(activeVault + "/" + rel, text, saved);
        });
    }

    // On reopen: pick up edits made outside SuperNote (no file watchers on this machine).
    function checkExternalChange() {
        if (!noteRel)
            return;
        const rel = noteRel;
        vaultRun("mtime", [rel], (code, out) => {
            if (rel !== noteRel)
                return;
            const m = code === 0 ? parseInt(out) || 0 : 0;
            if (!m) {
                toast(rel + " no longer exists on disk", true);
                return;
            }
            if (baselineMtime && m !== baselineMtime) {
                if (dirty)
                    conflict = true;
                else
                    doOpen(rel);
            }
        });
    }

    function resolveKeepMine() {
        refreshMtime(() => {
            conflict = false;
            saveNow();
        });
    }

    function resolveReload() {
        const rel = noteRel;
        dirty = false;
        conflict = false;
        noteRel = "";
        doOpen(rel);
    }

    // The open note changed on disk: reload it, or flag a conflict when typing raced the operation.
    function reloadIfClean(changed) {
        if (!noteRel || !changed)
            return;
        if (dirty)
            conflict = true;
        else
            doOpen(noteRel);
    }
}
