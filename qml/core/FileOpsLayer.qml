import QtQuick
import "../../js/tree.js" as Tree
import "../../js/tabs.js" as Tabs
import "../../js/links.js" as Links
import "../../js/config.js" as Config
import qs.Common

// File operations: create, rename/move (link-safe, with confirm + undo), folders and trash. Everything that
// remembers a path (tabs, recents, pins, expanded folders) follows a rename via `remapAll`.
OrganizeLayer {
    id: root

    function loadFileOpsState() {
        lastRename = readState("lastRename", null);
    }

    property var movePrompt: null
    property bool moveBusy: false
    property var lastRename: null
    readonly property string planFile: Paths.strip(Paths.state) + "/plugins/supernote.plan.json"

    function newNote(dirRel) {
        const dir = dirRel === undefined ? Config.newNoteDir(cfg, targetDir()) : dirRel;
        safely(() => {
            vaultRun("create", [dir], (code, out, err) => {
                if (code !== 0) {
                    toast(lastLine(err) || "Could not create the note", true);
                    return;
                }
                const rel = lastLine(out);
                if (dir)
                    setExpanded(dir, true);
                refreshTree(() => {
                    focusTarget = "title";
                    doOpen(rel);
                });
            });
        });
    }

    // Create a note with a given name in the vault root (quick switcher "Create ..." row) and open it.
    function createNamed(name) {
        safely(() => {
            vaultRun("create", ["", name], (code, out, err) => {
                if (code !== 0) {
                    toast(lastLine(err) || "Could not create \"" + name + "\"", true);
                    return;
                }
                const rel = lastLine(out);
                refreshTree(() => openNote(rel));
            });
        });
    }

    function newFolder(dirRel, name, done) {
        vaultRun("mkdir", [dirRel, name], (code, out, err) => {
            if (code !== 0) {
                toast(lastLine(err) || "Could not create the folder", true);
                if (done)
                    done(false);
                return;
            }
            const rel = lastLine(out);
            if (dirRel)
                setExpanded(dirRel, true);
            setExpanded(rel, true);
            selectedPath = rel;
            refreshTree(() => {
                if (done)
                    done(true);
            });
        });
    }

    // Everything that remembers a path follows a rename / move (and its undo).
    function remapAll(rel, to) {
        noteRel = Tree.remapPath(noteRel, rel, to);
        selectedPath = Tree.remapPath(selectedPath, rel, to);
        const map = clone(expandedByVault);
        const cur = map[activeVault] || {};
        const moved = {};
        for (const k in cur)
            moved[Tree.remapPath(k, rel, to)] = true;
        map[activeVault] = moved;
        expandedByVault = map;
        writeState("expanded", map);
        tabState = Tabs.remap(tabState, rel, to);
        persistTabs();
        const rec = clone(recentByVault);
        rec[activeVault] = (rec[activeVault] || []).map(r => Tree.remapPath(r, rel, to));
        recentByVault = rec;
        writeState("recent", rec);
        const pn = clone(pinsByVault);
        pn[activeVault] = (pn[activeVault] || []).map(r => Tree.remapPath(r, rel, to));
        pinsByVault = pn;
        writeState("pins", pn);
    }

    // Work out which notes would need their links rewritten: cb({from, to, writes, links, notes, unread})
    // or cb(null) when that could not be worked out (never assume "no links" on a failure).
    function planMove(rel, newRel, cb) {
        const moves = {};
        if (entryType(rel) === "dir") {
            for (const e of entries)
                if (e.type === "file" && e.path.indexOf(rel + "/") === 0)
                    moves[e.path] = Tree.remapPath(e.path, rel, newRel);
        } else {
            moves[rel] = newRel;
        }
        const plan = { from: rel, to: newRel, writes: [], links: 0, notes: 0, unread: 0 };
        const terms = Links.moveTerms(moves);
        if (terms.length === 0) {
            cb(plan);
            return;
        }
        const vault = activeVault;
        vaultRun("candidates", terms, (code, out) => {
            let files = [];
            try {
                files = code === 0 ? JSON.parse(out) : null;
            } catch (e) {
                files = null;
            }
            if (vault !== activeVault || !files) {
                toast("Could not check which notes link here; nothing was renamed", true);
                cb(null);
                return;
            }
            const paths = entries.filter(e => e.type === "file").map(e => e.path);
            const oldMap = Links.buildIndex(paths);
            const newPaths = paths.map(p => moves[p] || p);
            const step = i => {
                if (vault !== activeVault) {
                    cb(null);
                    return;
                }
                if (i >= files.length) {
                    plan.notes = plan.writes.length;
                    cb(plan);
                    return;
                }
                const chunk = files.slice(i, i + 200);
                vaultRun("readmany", chunk, (c2, o2) => {
                    let texts = null;
                    try {
                        texts = c2 === 0 ? JSON.parse(o2) : null;
                    } catch (e) {
                        texts = null;
                    }
                    if (!texts) {
                        toast("Could not read the linking notes; nothing was renamed", true);
                        cb(null);
                        return;
                    }
                    plan.unread += chunk.filter(f => !(f in texts)).length;
                    for (const path in texts) {
                        const r = Links.rewrite(texts[path].t, oldMap, moves, newPaths);
                        if (r.count > 0 && r.text !== texts[path].t) {
                            plan.writes.push({ path: path, text: r.text, base: texts[path].h });
                            plan.links += r.count;
                        }
                    }
                    step(i + 200);
                });
            };
            step(0);
        });
    }

    // Rename/move `rel` to `newRel`; asks first when other notes link to it.
    function moveTo(rel, newRel, done) {
        if (newRel === rel) {
            if (done)
                done(true, rel);
            return;
        }
        if (movePrompt || moveBusy) {
            toast("Finish the pending rename first", true);
            if (done)
                done(false);
            return;
        }
        moveBusy = true;
        safely(() => {
            planMove(rel, newRel, plan => {
                if (!plan) {
                    moveBusy = false;
                    if (done)
                        done(false);
                    return;
                }
                if (plan.links === 0 && plan.unread === 0) {
                    applyMove(plan, false, done);
                    return;
                }
                moveBusy = false;
                movePrompt = { plan: plan, done: done };
            });
        }, () => {
            moveBusy = false;
            if (done)
                done(false);
        });
    }

    // Answer the prompt: "update" (rewrite links), "only" (move, leave links), "cancel".
    function answerMove(mode) {
        const p = movePrompt;
        movePrompt = null;
        if (!p)
            return;
        if (mode === "cancel") {
            if (p.done)
                p.done(false);
            return;
        }
        moveBusy = true;
        applyMove(p.plan, mode === "update", p.done);
    }

    function applyMove(plan, withLinks, done) {
        const payload = { from: plan.from, to: plan.to, writes: withLinks ? plan.writes : [] };
        const vault = activeVault;
        writeFile(planFile, JSON.stringify(payload), ok => {
            if (!ok) {
                moveBusy = false;
                toast("Could not prepare the rename", true);
                if (done)
                    done(false);
                return;
            }
            vaultRun("apply", [planFile], (code, out, err) => {
                moveBusy = false;
                if (code !== 0 || vault !== activeVault) {
                    toast(lastLine(err) || "Could not rename", true);
                    if (done)
                        done(false);
                    if (code === 0)
                        refreshTree();
                    return;
                }
                const touched = payload.writes.map(w => Tree.remapPath(w.path, plan.from, plan.to));
                remapAll(plan.from, plan.to);
                lastRename = { vault: activeVault, dir: lastLine(out), from: plan.from, to: plan.to, links: withLinks ? plan.links : 0, notes: payload.writes.length };
                writeState("lastRename", lastRename);
                if (payload.writes.length)
                    toast("Updated " + plan.links + " link" + (plan.links === 1 ? "" : "s") + " in " + payload.writes.length + " note" + (payload.writes.length === 1 ? "" : "s") + ". Undo is in the vault menu.");
                refreshTree(() => {
                    reloadIfClean(touched.indexOf(noteRel) >= 0);   // its text changed on disk
                    if (done)
                        done(true, plan.to);
                });
            });
        });
    }

    function undoRename() {
        const lr = lastRename;
        if (!lr || lr.vault !== activeVault) {
            toast("Nothing to undo", true);
            return;
        }
        safely(() => {
            vaultRun("undo", [lr.dir], (code, out, err) => {
                if (code !== 0 || lr.vault !== activeVault) {
                    toast(lastLine(err) || "Could not undo", true);
                    return;
                }
                let r = { restored: 0, skipped: 0 };
                try {
                    r = JSON.parse(lastLine(out));
                } catch (e) {}
                remapAll(lr.to, lr.from);
                lastRename = null;
                writeState("lastRename", null);
                toast("Undone: " + lr.to.split("/").pop().replace(/\.md$/, "") + " is back to " + lr.from.split("/").pop().replace(/\.md$/, "") + (r.skipped ? " (" + r.skipped + " note" + (r.skipped === 1 ? "" : "s") + " edited since were left alone)" : ""));
                refreshTree(() => reloadIfClean(true));
            });
        });
    }

    function renameEntry(rel, newName, done) {
        const name = (newName || "").replace(/\.md$/i, "");
        if (/[\/\\]/.test(name)) {
            toast("A name cannot contain / or \\ (use Move to… to change folder)", true);
            if (done)
                done(false);
            return;
        }
        const isDir = entryType(rel) === "dir";
        const dir = Tree.parentOf(rel);
        moveTo(rel, (dir ? dir + "/" : "") + name + (isDir ? "" : ".md"), done);
    }

    // Move a note/folder into another folder ("" = vault root).
    function moveEntry(rel, destDir, done) {
        const base = rel.split("/").pop();
        if (destDir === rel || destDir.indexOf(rel + "/") === 0) {
            toast("Cannot move a folder into itself", true);
            if (done)
                done(false);
            return;
        }
        moveTo(rel, (destDir ? destDir + "/" : "") + base, done);
    }

    function trashEntry(rel, done) {
        safely(() => {
            vaultRun("trash", [rel], (code, out, err) => {
                if (code !== 0) {
                    toast(lastLine(err) || "Could not move to trash", true);
                    if (done)
                        done(false);
                    return;
                }
                const lost = noteRel === rel || noteRel.indexOf(rel + "/") === 0;
                if (lost)
                    closeNoteNow();
                if (selectedPath === rel || selectedPath.indexOf(rel + "/") === 0)
                    selectedPath = "";
                tabState = Tabs.removePath(tabState, rel);
                persistTabs();
                const rec = clone(recentByVault);
                rec[activeVault] = (rec[activeVault] || []).filter(r => r !== rel && r.indexOf(rel + "/") !== 0);
                recentByVault = rec;
                writeState("recent", rec);
                const pn = clone(pinsByVault);
                pn[activeVault] = (pn[activeVault] || []).filter(r => r !== rel && r.indexOf(rel + "/") !== 0);
                pinsByVault = pn;
                writeState("pins", pn);
                refreshTree(() => {
                    if (lost)
                        loadActive();
                    if (done)
                        done(true);
                });
            });
        }, () => {
            if (done)
                done(false);
        });
    }
}
