import QtQuick
import "../../js/tree.js" as Tree
import "../../js/config.js" as Config
import "../../js/templates.js" as Templates
import "../../js/capture.js" as Capture

// Capture and writing helpers: daily notes, quick capture (append to today's note / new Inbox note), templates
// and clipboard images.
FileOpsLayer {
    id: root

    property bool captureVisible: false

    function templateRel(name) {
        return /\.md$/i.test(name) ? name : name + ".md";
    }

    function templates() {
        const dir = cfg.templatesFolder;
        return entries.filter(e => e.type === "file" && (dir ? e.path.indexOf(dir + "/") === 0 : true)).map(e => ({ path: e.path, name: Tree.baseName(e.path) }));
    }

    // cb(rel | null): today's daily note, created (from the daily template) when missing.
    function ensureDaily(cb) {
        const now = new Date();
        const rel = Config.dailyPath(cfg, now);
        const make = text => putNote(rel, text, "new", code => {
            if (code !== 0 && code !== 3) {
                cb(null);
                return;
            }
            refreshTree(() => cb(rel));
        });
        if (notePathSet[rel]) {
            cb(rel);
            return;
        }
        if (!cfg.dailyTemplate) {
            make("");
            return;
        }
        readNote(templateRel(cfg.dailyTemplate), t => make(t === null ? "" : Templates.apply(t, { title: Tree.baseName(rel), date: now }).text));
    }

    function openDaily() {
        open();
        ensureVault(() => ensureDaily(rel => {
            if (rel)
                openNote(rel);
        }));
    }

    // Append "- HH:MM text" to today's daily note (works with the panel closed).
    function capture(text, cb) {
        const t = (text || "").replace(/\s+$/, "");
        if (!t) {
            if (cb)
                cb(false);
            return;
        }
        enqueue(done => ensureVault(() => ensureDaily(rel => {
            const finish = ok => {
                if (ok)
                    toast("Captured to " + Tree.baseName(rel));
                if (cb)
                    cb(ok);
                done();
            };
            if (!rel)
                return finish(false);
            const now = new Date();
            if (rel === noteRel) {
                if (conflict || noteLoading) {
                    toast("Resolve the conflict in " + Tree.baseName(rel) + " first", true);
                    return finish(false);
                }
                applyExternalText(Capture.appendCapture(buffer, t, now));
                saveNow(ok => {
                    if (!ok)
                        toast("Captured into the open note, but it could not be saved yet (see the banner)", true);
                    finish(true);   // the text is in the buffer either way
                });
                return;
            }
            readNote(rel, cur => {
                if (cur === null) {
                    toast("Could not read " + rel, true);
                    return finish(false);
                }
                putNote(rel, Capture.appendCapture(cur, t, now), "over", code => finish(code === 0));
            });
        }), () => {
            toast("Could not open the vault; nothing was captured", true);
            if (cb)
                cb(false);
            done();
        }));
    }

    // Save the text as its own note in the Inbox folder.
    function captureAsNote(text, cb) {
        const t = (text || "").replace(/\s+$/, "");
        if (!t) {
            if (cb)
                cb(false);
            return;
        }
        enqueue(done => ensureVault(() => {
            putUnique(cfg.inboxFolder, Capture.inboxTitle(t, new Date()), t + "\n", rel => {
                if (rel) {
                    toast("Saved " + rel);
                    refreshTree();
                } else {
                    toast("Could not save the note", true);
                }
                if (cb)
                    cb(!!rel);
                done();
            });
        }, () => {
            toast("Could not open the vault; nothing was saved", true);
            if (cb)
                cb(false);
            done();
        }));
    }

    function captureClipboard() {
        run(["wl-paste", "--no-newline"], (code, out) => {
            if (code !== 0 || !out.trim()) {
                toast("The clipboard has no text", true);
                return;
            }
            capture(out);
        });
    }

    signal insertTemplate(string text, int cursor)

    function useTemplate(tplRel) {
        readNote(tplRel, t => {
            if (t === null) {
                toast("Could not read the template", true);
                return;
            }
            const r = Templates.apply(t, { title: noteTitle, date: new Date() });
            insertTemplate(r.text, r.cursor);
        });
    }

    // New note `name` (unique) from a template, opened with the caret at {{cursor}}.
    function newFromTemplate(tplRel, name) {
        safely(() => readNote(tplRel, t => {
            if (t === null) {
                toast("Could not read the template", true);
                return;
            }
            const title = (name || "Untitled").trim() || "Untitled";
            const r = Templates.apply(t, { title: title, date: new Date() });
            putUnique(Config.newNoteDir(cfg, targetDir()), title, r.text, rel => {
                if (!rel) {
                    toast("Could not create the note", true);
                    return;
                }
                pendingCursor = r.cursor;
                refreshTree(() => openNote(rel));
            });
        }));
    }

    // Save the clipboard image next to the vault's attachments; cb(fileName | null).
    function pasteImage(cb) {
        if (!noteRel) {
            cb(null);
            return;
        }
        const name = "Pasted image " + Config.formatDate("YYYYMMDDHHmmss", new Date());
        vaultRun("paste-image", [Config.attachmentDir(cfg, noteRel), name], (code, out, err) => {
            if (code !== 0) {
                toast(lastLine(err) || "Could not save the image", true);
                cb(null);
                return;
            }
            refreshTree(() => cb(lastLine(out).split("/").pop()));
        });
    }
}
