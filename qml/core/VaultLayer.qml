import QtQuick
import "../../js/tree.js" as Tree
import "../../js/tabs.js" as Tabs
import "../../js/links.js" as Links
import "../../js/config.js" as Config
import qs.Common

// Vaults and their file tree: which vault is open, the tree entries/rows/indexes (note names, attachments),
// `.obsidian` config, note IO through the vault script, and the serial job queue that keeps read-modify-write
// operations on notes from interleaving.
CoreBase {
    id: root

    // Persisted vault list / tree preferences (see ensureState in WindowLayer).
    function loadVaultState() {
        vaults = readState("vaults", []);
        activeVault = readState("activeVault", "");
        expandedByVault = readState("expanded", {});
        sortByMtime = readState("sortByMtime", false);
        if (vaults.length === 0)
            vaults = [defaultVault];
        if (!activeVault || vaults.indexOf(activeVault) < 0)
            activeVault = vaults[0];
    }

    property var vaults: []
    property string activeVault: ""
    property var expandedByVault: ({})
    property bool sortByMtime: false
    property bool stateReady: false
    property bool vaultReady: false
    property var entries: []
    property var rows: []
    property string selectedPath: ""
    property var readyQueue: []
    property var noteIndex: ({})
    property var assetSet: ({})
    property var assetByName: ({})
    property var embedCache: ({})
    property var embedPending: ({})
    property int embedSerial: 0
    property var notePathSet: ({})
    property var obsidianCfg: ({})
    readonly property var cfg: Config.merge(Config.defaults(), obsidianCfg, pluginData)
    readonly property int editorFontSize: parseInt((pluginData || {}).editorFontSize) || 0
    property bool activating: false
    property int putSerial: 0
    property var jobQueue: []
    property bool jobBusy: false

    function expandedMap() {
        return expandedByVault[activeVault] || {};
    }

    function rebuildRows() {
        rows = Tree.buildRows(entries, expandedMap(), sortByMtime);
    }

    function setExpanded(path, on) {
        const map = clone(expandedByVault);
        const cur = map[activeVault] || {};
        if (on)
            cur[path] = true;
        else
            delete cur[path];
        map[activeVault] = cur;
        expandedByVault = map;
        writeState("expanded", map);
    }

    function toggleDir(path) {
        setExpanded(path, !expandedMap()[path]);
        rebuildRows();
    }

    function expandTo(path) {
        const list = Tree.ancestors(path);
        if (list.length === 0)
            return;
        const map = clone(expandedByVault);
        const cur = map[activeVault] || {};
        for (const a of list)
            cur[a] = true;
        map[activeVault] = cur;
        expandedByVault = map;
        writeState("expanded", map);
        rebuildRows();
    }

    function refreshTree(cb) {
        vaultRun("list", [], (code, out, err) => {
            if (code !== 0) {
                toast(lastLine(err) || "Could not read the vault", true);
                if (cb)
                    cb(false);
                return;
            }
            try {
                entries = JSON.parse(out);
            } catch (e) {
                entries = [];
            }
            rebuildRows();
            rebuildIndexes();
            embedCache = {};
            refreshTags();
            if (cb)
                cb(true);
        });
    }

    function rebuildIndexes() {
        const assets = {};
        const byName = {};
        const paths = [];
        const set = {};
        for (const e of entries) {
            if (e.type === "file") {
                paths.push(e.path);
                set[e.path] = true;
            } else if (e.type === "attachment") {
                assets[e.path] = true;
                const n = e.path.split("/").pop().toLowerCase();
                (byName[n] = byName[n] || []).push(e.path);
            }
        }
        noteIndex = Links.buildIndex(paths);
        notePathSet = set;
        assetSet = assets;
        assetByName = byName;
    }

    function resolveNote(name) {
        return Links.resolve(noteIndex, name);
    }

    function resolveAsset(name, dir) {
        const withDir = dir ? dir + "/" + name : name;
        if (assetSet[withDir])
            return withDir;
        if (assetSet[name])
            return name;
        const cands = assetByName[name.split("/").pop().toLowerCase()];
        if (!cands)
            return null;
        return cands.find(c => Tree.parentOf(c) === dir) || cands[0];
    }

    // Embedded note text for the preview; null while it is still being read (embedSerial bumps when ready).
    function getEmbed(name) {
        const rel = resolveNote(name);
        if (!rel)
            return null;
        const key = activeVault + "/" + rel;
        if (embedCache[key] !== undefined)
            return embedCache[key];
        if (!embedPending[key]) {
            embedPending[key] = true;
            run(["cat", "--", key], (code, out) => {
                delete embedPending[key];
                embedCache[key] = code === 0 ? out : "";
                embedSerial++;
            });
        }
        return null;
    }

    function afterReady(cb) {
        if (vaultReady)
            cb();
        else
            readyQueue = readyQueue.concat([cb]);
    }

    function activateVault(path, cb) {
        const abs = expandPath(path);
        safely(() => {
            saveViewToTab();
            persistTabs();
            closeNoteNow();
            activeVault = abs;
            writeState("activeVault", abs);
            if (vaults.indexOf(abs) < 0) {
                vaults = vaults.concat([abs]);
                writeState("vaults", vaults);
            }
            entries = [];
            rows = [];
            tabState = Tabs.init();
            currentView = null;
            tagCache = {};
            noteTags = {};
            searchResults = [];
            tagSerial++;
            searchSerial++;
            movePrompt = null;
            vaultReady = false;
            activating = true;
            obsidianCfg = {};
            run([vaultScript, "init", abs], (code, out, err) => {
                if (code !== 0) {
                    activating = false;
                    toast(lastLine(err) || "Could not open the vault", true);
                    failQueued();
                    if (cb)
                        cb(false);
                    return;
                }
                run([vaultScript, "obsidian-config", abs], (c3, o3) => {
                    try {
                        obsidianCfg = c3 === 0 ? JSON.parse(o3) : {};
                    } catch (e) {
                        obsidianCfg = {};
                    }
                    refreshTree(ok => {
                        activating = false;
                        vaultReady = ok;
                        if (ok) {
                            tabState = Tabs.prune(Tabs.normalize(tabsByVault[abs]), entries.filter(e => e.type === "file").map(e => e.path));
                            loadActive();
                        }
                        const queued = readyQueue;
                        readyQueue = [];
                        queued.forEach(f => {
                            if (ok)
                                f();
                            else if (f.onFail)
                                f.onFail();
                        });
                        if (cb)
                            cb(ok);
                    });
                });
            });
        }, () => {
            if (cb)
                cb(false);
        });
    }

    function failQueued() {
        const queued = readyQueue;
        readyQueue = [];
        queued.forEach(f => {
            if (f.onFail)
                f.onFail();
        });
    }

    function removeVault(path) {
        const next = vaults.filter(v => v !== path);
        if (next.length === 0)
            return;
        vaults = next;
        writeState("vaults", next);
        for (const key of ["tabsByVault", "recentByVault", "expandedByVault", "pinsByVault"]) {
            const m = clone(root[key]);
            delete m[path];
            root[key] = m;
        }
        writeState("tabs", tabsByVault);
        writeState("recent", recentByVault);
        writeState("expanded", expandedByVault);
        writeState("pins", pinsByVault);
        if (activeVault === path)
            activateVault(next[0]);
    }

    function toggleSort() {
        sortByMtime = !sortByMtime;
        writeState("sortByMtime", sortByMtime);
        rebuildRows();
    }

    function entryType(path) {
        const e = entries.find(x => x.path === path);
        return e ? e.type : "";
    }

    function targetDir() {
        if (!selectedPath)
            return "";
        return entryType(selectedPath) === "dir" ? selectedPath : Tree.parentOf(selectedPath);
    }

    // cb() when the vault is ready; onFail() when it cannot be opened (so job queues never wedge).
    function ensureVault(cb, onFail) {
        afterState(() => {
            ensureState();
            if (vaultReady) {
                cb();
                return;
            }
            const waiter = () => cb();
            waiter.onFail = onFail;
            readyQueue = readyQueue.concat([waiter]);
            if (!activating)
                activateVault(activeVault);
        });
    }

    // Jobs run one at a time (read-modify-write on notes must not interleave). fn(done) calls done() when finished.
    function enqueue(fn) {
        jobQueue = jobQueue.concat([fn]);
        if (!jobBusy)
            nextJob();
    }

    function nextJob() {
        if (jobQueue.length === 0) {
            jobBusy = false;
            return;
        }
        jobBusy = true;
        const fn = jobQueue[0];
        jobQueue = jobQueue.slice(1);
        fn(nextJob);
    }

    function readNote(rel, cb) {
        vaultRun("read", [rel], (code, out) => cb(code === 0 ? out : null));
    }

    // Write a note through the vault script. mode "new" refuses to overwrite (cb(3)). cb(exitCode).
    function putNote(rel, text, mode, cb) {
        const tmp = Paths.strip(Paths.state) + "/plugins/supernote.put" + (++putSerial) + ".tmp";
        writeFile(tmp, text, ok => {
            if (!ok) {
                cb(1);
                return;
            }
            vaultRun("put", mode === "new" ? [rel, tmp, "new"] : [rel, tmp], (code, out, err) => {
                run(["rm", "-f", tmp], () => {});
                if (code !== 0 && code !== 3)
                    toast(lastLine(err) || "Could not write " + rel, true);
                cb(code);
            });
        });
    }

    // First free "<dir>/<title>.md" ("<title> 2", ...) created with `text`. cb(rel | null).
    function putUnique(dir, title, text, cb) {
        const attempt = n => {
            if (n > 50) {
                cb(null);
                return;
            }
            const rel = (dir ? dir + "/" : "") + title + (n > 1 ? " " + n : "") + ".md";
            putNote(rel, text, "new", code => {
                if (code === 0)
                    cb(rel);
                else if (code === 3)
                    attempt(n + 1);
                else
                    cb(null);
            });
        };
        attempt(1);
    }
}
