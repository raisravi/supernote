import QtQuick
import Quickshell
import Quickshell.Io
import "js/tree.js" as Tree
import "js/markdown.js" as Md
import "js/tabs.js" as Tabs
import "js/links.js" as Links
import "js/tags.js" as Tags
import "js/config.js" as Config
import "js/templates.js" as Templates
import "js/capture.js" as Capture
import "js/render.js" as Render
import qs.Common
import qs.Services
import qs.Modules.Plugins

// SuperNote core: vault/tree state, note load/save/conflict handling, rename/create/trash,
// IPC. The UI lives in SuperNotePanel.qml, loaded through a cache-busting URL so editing it
// only needs `dms ipc call plugins reload supernote` (QML caches sibling files by URL).
PluginComponent {
    id: root

    readonly property string pluginKey: "supernote"
    readonly property string home: Quickshell.env("HOME")
    // the plugin folder wherever it lives (a symlink into a git checkout works too)
    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
    readonly property string vaultScript: pluginDir + "/scripts/supernote-vault.sh"
    readonly property string defaultVault: home + "/Documents/notes"

    // --- panel / persisted state ---------------------------------------------------
    property bool panelVisible: false
    property bool uiActive: false
    property var vaults: []
    property string activeVault: ""
    property var expandedByVault: ({})
    property bool sortByMtime: false
    property bool stateReady: false
    property bool vaultReady: false

    // --- tree ------------------------------------------------------------------------
    property var entries: []
    property var rows: []
    property string selectedPath: ""

    // --- current note ------------------------------------------------------------------
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
    property var readyQueue: []
    property string viewMode: "edit"
    property bool showToolbar: true
    property int editorSetSerial: 0
    property var noteIndex: ({})
    property var assetSet: ({})
    property var assetByName: ({})
    property var embedCache: ({})
    property var embedPending: ({})
    property int embedSerial: 0
    property var tabState: Tabs.init()
    property var tabsByVault: ({})
    property var recentByVault: ({})
    property var currentView: null
    property string pendingHeading: ""
    property var backlinks: []
    property bool rightPanel: false
    property string rightTab: "outline"
    readonly property var recent: recentByVault[activeVault] || []

    // --- organization (M4) -----------------------------------------------------------------
    property var pinsByVault: ({})
    readonly property var pins: pinsByVault[activeVault] || []
    property var sections: ({ pins: true, recent: true })
    property var notePathSet: ({})
    readonly property var sideList: Tree.sideRows(rows, pins, recent, sections, notePathSet)
    property string sidebarTab: "files"
    property string searchQuery: ""
    property var searchResults: []
    property bool searching: false
    property int searchSerial: 0
    property bool tagsWanted: false
    property var noteTags: ({})
    property var tagCache: ({})
    property int tagSerial: 0
    property var tagExpanded: ({})
    property string tagSelected: ""
    property string pendingLine: ""
    property var movePrompt: null
    property bool moveBusy: false

    // --- capture & polish (M5) -----------------------------------------------------------------
    property var obsidianCfg: ({})
    readonly property var cfg: Config.merge(Config.defaults(), obsidianCfg, pluginData)
    readonly property int editorFontSize: parseInt((pluginData || {}).editorFontSize) || 0
    property bool captureVisible: false

    // --- math + Mermaid pictures (M6) ------------------------------------------------------------
    readonly property string renderScript: pluginDir + "/scripts/supernote-render.sh"
    readonly property string renderDir: home + "/.cache/supernote/render"
    property var renderCache: ({})       // key -> {state: pending|ok|error, url, px, err}; mutated in place
    property var renderQueue: []
    property var renderRunning: ({ math: 0, mermaid: 0 })
    property var renderWarned: ({})
    property int renderSerial: 0         // bumps when a picture becomes available (preview re-renders)
    property int renderJobs: 0
    property int renderEpoch: 0          // bumped by each preview pass: queued jobs from older passes are dropped
    property int renderPassCount: 0

    // --- docked panel / window (follow-up) ---------------------------------------------------------
    property string windowMode: "dock"          // "dock" (right side) | "window" (real floating window); reset on open
    property bool showSidebarDock: false
    property bool showSidebarWindow: true
    readonly property bool showSidebar: windowMode === "window" ? showSidebarWindow : showSidebarDock
    property bool activating: false
    property int putSerial: 0
    property var jobQueue: []
    property bool jobBusy: false
    property var lastRename: null
    readonly property string planFile: Paths.strip(Paths.state) + "/plugins/supernote.plan.json"

    readonly property string noteTitle: noteRel ? Tree.baseName(noteRel) : ""

    // --- helpers -----------------------------------------------------------------------
    function clone(x) {
        return JSON.parse(JSON.stringify(x));
    }

    // Own state file (DMS's PluginService state writer breaks after a plugin reload).
    readonly property string stateFile: Paths.strip(Paths.state) + "/plugins/supernote.state.json"
    property var stateData: ({})
    property bool stateLoaded: false
    property var stateQueue: []

    function loadState() {
        run(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat \"$1\" 2>/dev/null || true", "sh", stateFile], (code, out) => {
            try {
                stateData = JSON.parse(out);
            } catch (e) {
                stateData = {};
            }
            stateLoaded = true;
            const queued = stateQueue;
            stateQueue = [];
            queued.forEach(f => f());
        });
    }

    function afterState(cb) {
        if (stateLoaded)
            cb();
        else
            stateQueue = stateQueue.concat([cb]);
    }

    function readState(key, def) {
        const v = stateData[key];
        return v === undefined || v === null ? def : clone(v);
    }

    function writeState(key, value) {
        stateData[key] = value;
        stateTimer.restart();
    }

    Timer {
        id: stateTimer
        interval: 400
        onTriggered: root.flushState()
    }

    function flushState() {
        writerComp.createObject(root, {
            path: stateFile,
            content: JSON.stringify(stateData, null, 2),
            done: ok => {
                if (!ok)
                    console.warn("SuperNote: could not write", stateFile);
            }
        });
    }

    function toast(msg, isError) {
        if (isError)
            ToastService.showError(msg);
        else
            ToastService.showInfo(msg);
    }

    function lastLine(text) {
        const lines = (text || "").trim().split("\n");
        return lines[lines.length - 1];
    }

    function vaultName(path) {
        const parts = (path || "").split("/").filter(p => p.length > 0);
        return parts.length ? parts[parts.length - 1] : "";
    }

    function noteTitleOf(path) {
        return Tree.baseName(path);
    }

    function parentOf(path) {
        return Tree.parentOf(path);
    }

    function expandPath(p) {
        return p.startsWith("~/") ? home + p.slice(1) : p;
    }

    // Run a command; done(exitCode, stdout, stderr) fires once everything has been read.
    Component {
        id: procComp
        Process {
            id: p
            property var done: null
            property string out: ""
            property string err: ""
            property int code: -1
            property int pending: 3
            function tick() {
                pending--;
                if (pending === 0) {
                    if (done)
                        done(code, out, err);
                    p.destroy();
                }
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    p.out = text;
                    p.tick();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    p.err = text;
                    p.tick();
                }
            }
            onExited: exitCode => {
                p.code = exitCode;
                p.tick();
            }
        }
    }

    function run(args, done) {
        procComp.createObject(root, { command: args, done: done, running: true });
    }

    function vaultRun(op, args, done) {
        run([vaultScript, op, activeVault].concat(args), done);
    }

    // Atomic write, same mechanism DMS's own notepad uses.
    Component {
        id: writerComp
        FileView {
            property string content: ""
            property var done: null
            blockWrites: false
            atomicWrites: true
            Component.onCompleted: setText(content)
            onSaved: {
                if (done)
                    done(true);
                destroy();
            }
            onSaveFailed: {
                if (done)
                    done(false);
                destroy();
            }
        }
    }

    // --- state / vault lifecycle -------------------------------------------------------
    function ensureState() {
        if (stateReady)
            return;
        vaults = readState("vaults", []);
        activeVault = readState("activeVault", "");
        expandedByVault = readState("expanded", {});
        sortByMtime = readState("sortByMtime", false);
        viewMode = readState("viewMode", "edit");
        tabsByVault = readState("tabs", {});
        recentByVault = readState("recent", {});
        rightPanel = readState("rightPanel", false);
        rightTab = readState("rightTab", "outline");
        showToolbar = readState("showToolbar", true);
        propsOpen = readState("propsOpen", false);
        showSidebarDock = readState("sidebarDock", false);
        showSidebarWindow = readState("sidebarWindow", true);
        pinsByVault = readState("pins", {});
        sections = readState("sections", { pins: true, recent: true });
        sidebarTab = readState("sidebarTab", "files");
        tagExpanded = readState("tagExpanded", {});
        tagSelected = readState("tagSelected", "");
        lastRename = readState("lastRename", null);
        tagsWanted = sidebarTab === "tags";
        if (vaults.length === 0)
            vaults = [defaultVault];
        if (!activeVault || vaults.indexOf(activeVault) < 0)
            activeVault = vaults[0];
        stateReady = true;
    }

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

    // --- open / close ---------------------------------------------------------------------
    function open() {
        if (!stateLoaded) {
            afterState(() => open());
            return;
        }
        ensureState();
        if (!panelVisible)
            windowMode = "dock";
        uiActive = true;
        panelVisible = true;
        if (!vaultReady) {
            activateVault(activeVault);
            return;
        }
        refreshTree();
        checkExternalChange();
    }

    function close() {
        flushSave(() => {
            panelVisible = false;
        });
        // Even if a conflict blocks the save, still hide; the buffer stays in memory.
        panelVisible = false;
    }

    function toggle() {
        if (panelVisible)
            close();
        else
            open();
    }


    // --- view / editing actions ------------------------------------------------------------
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

    function setSidebar(on) {
        if (windowMode === "window") {
            showSidebarWindow = on;
            writeState("sidebarWindow", on);
        } else {
            showSidebarDock = on;
            writeState("sidebarDock", on);
        }
    }

    function toggleSidebar() {
        setSidebar(!showSidebar);
    }

    function expandToWindow() {
        windowMode = "window";
    }

    function dockAgain() {
        windowMode = "dock";
    }

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

    // Clicking a wikilink: open the note, or create it in the vault root when missing.
    function openLink(name, heading) {
        const rel = resolveNote(name);
        if (rel) {
            if (rel === noteRel && !conflict) {
                if (heading)
                    jumpHeading(heading);
                return;
            }
            openNote(rel, false, heading);
            return;
        }
        // Missing: create it in the root, reduced to its basename (Obsidian puts new links there).
        const base = (name || "").split("/").pop().replace(/\.md$/i, "").trim();
        if (!base)
            return;
        safely(() => {
            vaultRun("create", ["", base], (code, out, err) => {
                if (code !== 0) {
                    toast(lastLine(err) || "Could not create \"" + base + "\"", true);
                    return;
                }
                const created = lastLine(out);
                refreshTree(() => openNote(created, false, heading));
            });
        });
    }

    // --- note load / save -----------------------------------------------------------------
    function closeNoteNow() {
        openSerial++;
        noteRel = "";
        buffer = "";
        dirty = false;
        conflict = false;
        baselineMtime = 0;
        loadSerial++;
    }

    // --- tabs & navigation ----------------------------------------------------------------
    function persistTabs() {
        if (!vaultReady)
            return;
        const m = clone(tabsByVault);
        m[activeVault] = tabState;
        tabsByVault = m;
        writeState("tabs", m);
    }

    function saveViewToTab() {
        if (currentView && noteRel && !noteLoading)
            tabState = Tabs.setView(tabState, currentView);
    }

    function activeTabView() {
        return Tabs.activeView(tabState);
    }

    // Load whatever the active tab points at.
    function loadActive() {
        const rel = Tabs.activeRel(tabState);
        if (!rel) {
            if (dirty) {
                safely(closeNoteNow);
                return;
            }
            closeNoteNow();
            return;
        }
        if (rel === noteRel && !conflict) {
            selectedPath = rel;
            return;
        }
        doOpen(rel);
    }

    // Save the current note, apply a tab-state transition, then load the (new) active tab.
    function navigate(transition) {
        safely(() => {
            saveViewToTab();
            tabState = transition(tabState);
            persistTabs();
            loadActive();
        });
    }

    function openNote(rel, newTab, heading, line) {
        if (!rel)
            return;
        if (rel === noteRel && !conflict && !newTab) {
            selectedPath = rel;
            if (line)
                jumpLine(line);
            return;
        }
        pendingHeading = heading || "";
        pendingLine = line ? String(line) : "";
        navigate(st => Tabs.open(st, rel, !!newTab));
    }

    function newTab() {
        navigate(st => Tabs.addEmpty(st));
    }

    function activateTab(i) {
        navigate(st => Tabs.activate(st, i));
    }

    function closeTab(i) {
        navigate(st => Tabs.close(st, i));
    }

    function cycleTab(dir) {
        navigate(st => Tabs.cycle(st, dir));
    }

    function goBack() {
        navigate(st => Tabs.back(st));
    }

    function goForward() {
        navigate(st => Tabs.forward(st));
    }

    function pushRecent(rel) {
        const m = clone(recentByVault);
        m[activeVault] = [rel].concat((m[activeVault] || []).filter(r => r !== rel)).slice(0, 30);
        recentByVault = m;
        writeState("recent", m);
    }

    signal jumpHeading(string heading)
    signal jumpLine(int line)

    function refreshBacklinks() {
        if (!noteRel) {
            backlinks = [];
            return;
        }
        const rel = noteRel;
        vaultRun("backlinks", [rel], (code, out) => {
            if (rel !== noteRel)
                return;
            try {
                backlinks = code === 0 ? JSON.parse(out) : [];
            } catch (e) {
                backlinks = [];
            }
        });
    }

    function setRightPanel(open) {
        rightPanel = open;
        writeState("rightPanel", open);
        if (open)
            refreshBacklinks();
    }

    function setRightTab(tab) {
        rightTab = tab;
        writeState("rightTab", tab);
        if (tab === "backlinks")
            refreshBacklinks();
    }

    function doOpen(rel) {
        const serial = ++openSerial;
        noteLoading = true;
        run(["cat", "--", activeVault + "/" + rel], (code, out, err) => {
            if (serial !== openSerial)
                return;
            noteLoading = false;
            if (code !== 0) {
                toast("Could not open " + rel, true);
                pendingHeading = "";
                pendingLine = "";
                pendingCursor = -1;
                tabState = Tabs.removePath(tabState, rel);
                persistTabs();
                loadActive();
                return;
            }
            noteRel = rel;
            buffer = out;
            dirty = false;
            conflict = false;
            currentView = null;
            loadSerial++;
            selectedPath = rel;
            expandTo(rel);
            pushRecent(rel);
            refreshMtime();
            if (rightPanel)
                refreshBacklinks();
            focusSerial++;
            focusTarget = "editor";
            if (pendingHeading) {
                const h = pendingHeading;
                pendingHeading = "";
                jumpHeading(h);
            }
            if (pendingCursor >= 0) {
                const off = pendingCursor;
                pendingCursor = -1;
                jumpOffset(off);
            }
            if (pendingLine) {
                const ln = parseInt(pendingLine);
                pendingLine = "";
                jumpLine(ln);
            }
        });
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
            if (text === "") {
                // FileView.setText("") never reports "saved": empty a note (atomically) by hand
                const path = activeVault + "/" + rel;
                run(["sh", "-c", ": > \"$1.sntmp\" && mv -f \"$1.sntmp\" \"$1\"", "sh", path], code => saved(code === 0));
                return;
            }
            writerComp.createObject(root, {
                path: activeVault + "/" + rel,
                content: text,
                done: saved
            });
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

    // --- create / rename / trash -------------------------------------------------------------
    function entryType(path) {
        const e = entries.find(x => x.path === path);
        return e ? e.type : "";
    }

    function targetDir() {
        if (!selectedPath)
            return "";
        return entryType(selectedPath) === "dir" ? selectedPath : Tree.parentOf(selectedPath);
    }

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

    // --- link-safe rename / move -----------------------------------------------------------------
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
        writerComp.createObject(root, {
            path: planFile,
            content: JSON.stringify(payload),
            done: ok => {
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
            }
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

    // The open note changed on disk: reload it, or flag a conflict when typing raced the operation.
    function reloadIfClean(changed) {
        if (!noteRel || !changed)
            return;
        if (dirty)
            conflict = true;
        else
            doOpen(noteRel);
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

    // --- math / Mermaid --------------------------------------------------------------------------------
    // The preview asks for a picture: {url, w} when it is ready (w = display width), else null and a render is
    // queued (renderSerial bumps when it lands). Pictures are cached on disk by content + colors.
    function beginRenderPass() {
        renderEpoch++;
        renderPassCount = 0;
    }

    function diagram(kind, src, display, maxWidth) {
        if (src.length > 20000)
            return null;   // too long to render (the script refuses it as well)
        const s = Theme.surface;
        const f = Theme.surfaceText;
        const style = { display: !!display, fg: Render.hex(f.r, f.g, f.b), dark: Render.isDark(s.r, s.g, s.b) };
        const key = Render.key(kind, src, style);
        const e = renderCache[key];
        if (e && e.state === "ok")
            return { url: e.url, w: Render.shownWidth(e.px, maxWidth || 0) };
        // failures are retried after a while (tools installed, network back); pending ones are already queued
        if (e && e.state === "pending") {
            renderQueue.forEach(j => {
                if (j.key === key)
                    j.epoch = renderEpoch;   // still on screen: keep it queued through the new pass
            });
            return null;
        }
        if (e && Date.now() - e.at < 60000)
            return null;
        if (renderPassCount >= 40)
            return null;   // a note with hundreds of formulas fills in over several passes
        renderPassCount++;
        renderCache[key] = { state: "pending" };
        renderQueue = renderQueue.concat([{ key: key, kind: kind, src: src, style: style, epoch: renderEpoch }]);
        pumpRender();
        return null;
    }

    function pumpRender() {
        const limit = { math: 2, mermaid: 1 };
        // jobs for text that is no longer in the preview (typed over since) are dropped, not rendered
        const stale = renderQueue.filter(j => j.epoch !== renderEpoch);
        stale.forEach(j => delete renderCache[j.key]);
        let queue = renderQueue.filter(j => j.epoch === renderEpoch);
        const started = { math: renderRunning.math, mermaid: renderRunning.mermaid };
        const rest = [];
        queue.forEach(job => {
            if (started[job.kind] < limit[job.kind]) {
                started[job.kind]++;
                runRender(job);
            } else {
                rest.push(job);
            }
        });
        renderQueue = rest;
    }

    function runRender(job) {
        renderRunning[job.kind]++;
        const srcFile = Paths.strip(Paths.state) + "/plugins/supernote.render" + (++renderJobs) + ".src";
        const out = renderDir + "/" + job.key + ".png";
        const finish = (ok, px, err) => {
            renderRunning[job.kind]--;
            renderCache[job.key] = ok ? { state: "ok", url: "file://" + out, px: px } : { state: "error", err: err, at: Date.now() };
            if (ok) {
                renderWarned[job.kind] = false;   // a later failure is worth a new heads-up
            } else if (!renderWarned[job.kind]) {
                renderWarned[job.kind] = true;
                toast("Could not render " + job.kind + ": " + err, true);
            }
            run(["rm", "-f", srcFile], () => {});
            if (ok)
                renderSerial++;
            pumpRender();
        };
        writerComp.createObject(root, {
            path: srcFile,
            content: job.src,
            done: wrote => {
                if (!wrote) {
                    finish(false, 0, "could not write the source");
                    return;
                }
                const arg = job.kind === "math" ? (job.style.display ? "1" : "0") : (job.style.dark ? "1" : "0");
                run([renderScript, job.kind, srcFile, out, job.style.fg, arg], (code, stdout, stderr) => {
                    const dims = Render.parseDims(stdout);
                    if (code === 0 && dims)
                        finish(true, dims.w, "");
                    else
                        finish(false, 0, lastLine(stderr).replace(/^error:\s*/, "") || "render failed");
                });
            }
        });
    }

    // --- vault-ready helper, note IO, serial jobs -----------------------------------------------------
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
        const send = () => vaultRun("put", mode === "new" ? [rel, tmp, "new"] : [rel, tmp], (code, out, err) => {
            run(["rm", "-f", tmp], () => {});
            if (code !== 0 && code !== 3)
                toast(lastLine(err) || "Could not write " + rel, true);
            cb(code);
        });
        if (text === "") {
            // FileView.setText("") never reports "saved", so make the empty file directly
            run(["sh", "-c", ": > \"$1\"", "sh", tmp], code => code === 0 ? send() : cb(1));
            return;
        }
        writerComp.createObject(root, {
            path: tmp,
            content: text,
            done: ok => {
                if (!ok) {
                    cb(1);
                    return;
                }
                send();
            }
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

    function templateRel(name) {
        return /\.md$/i.test(name) ? name : name + ".md";
    }

    function templates() {
        const dir = cfg.templatesFolder;
        return entries.filter(e => e.type === "file" && (dir ? e.path.indexOf(dir + "/") === 0 : true)).map(e => ({ path: e.path, name: Tree.baseName(e.path) }));
    }

    // --- daily notes / capture ------------------------------------------------------------------------
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

    // --- templates ---------------------------------------------------------------------------------------
    signal insertTemplate(string text, int cursor)
    signal searchRequest(string query)
    signal jumpOffset(int offset)
    property int pendingCursor: -1

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

    // --- clipboard image -----------------------------------------------------------------------------------
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

    // --- pins / sidebar sections -------------------------------------------------------------
    function togglePin(rel) {
        const pn = clone(pinsByVault);
        const list = pn[activeVault] || [];
        pn[activeVault] = list.indexOf(rel) >= 0 ? list.filter(r => r !== rel) : list.concat([rel]);
        pinsByVault = pn;
        writeState("pins", pn);
    }

    function toggleSection(key) {
        const m = clone(sections);
        m[key] = !m[key];
        sections = m;
        writeState("sections", m);
    }

    // --- search / tags ---------------------------------------------------------------------------
    function setSidebarTab(tab) {
        if (!showSidebar)
            setSidebar(true);   // search / tags / files live in the sidebar
        sidebarTab = tab;
        writeState("sidebarTab", tab);
        if (tab === "tags") {
            tagsWanted = true;
            refreshTags();
        }
    }

    function search(q) {
        searchQuery = q;
        const serial = ++searchSerial;
        if (q.trim().length < 2) {
            searchResults = [];
            searching = false;
            return;
        }
        searching = true;
        vaultRun("search", [q.trim()], (code, out) => {
            if (serial !== searchSerial)
                return;
            searching = false;
            try {
                searchResults = code === 0 ? JSON.parse(out) : [];
            } catch (e) {
                searchResults = [];
            }
        });
    }

    // Vault-wide tag index, read lazily and incrementally (only notes whose mtime changed).
    function refreshTags() {
        if (!tagsWanted || !vaultReady)
            return;
        const serial = ++tagSerial;
        const files = entries.filter(e => e.type === "file");
        const mtimeOf = {};
        files.forEach(e => mtimeOf[e.path] = e.mtime);
        const stale = files.filter(e => !tagCache[e.path] || tagCache[e.path].mtime !== e.mtime).map(e => e.path);
        const finish = () => {
            const idx = {};
            const cache = {};
            files.forEach(e => {
                const c = tagCache[e.path];
                if (c) {
                    cache[e.path] = c;
                    idx[e.path] = c.tags;
                }
            });
            tagCache = cache;
            noteTags = idx;
        };
        const next = i => {
            if (serial !== tagSerial)
                return;
            if (i >= stale.length) {
                finish();
                return;
            }
            vaultRun("readmany", stale.slice(i, i + 60), (code, out) => {
                if (serial !== tagSerial)
                    return;
                let texts = {};
                try {
                    texts = code === 0 ? JSON.parse(out) : {};
                } catch (e) {
                    texts = {};
                }
                const cache = tagCache;
                for (const path in texts)
                    cache[path] = { mtime: mtimeOf[path], tags: Md.extractTags(texts[path].t) };
                next(i + 60);
            });
        };
        next(0);
    }

    function toggleTag(tag) {
        const m = clone(tagExpanded);
        if (m[tag])
            delete m[tag];
        else
            m[tag] = true;
        tagExpanded = m;
        writeState("tagExpanded", m);
    }

    function selectTag(tag) {
        tagSelected = tag;
        writeState("tagSelected", tag);
    }

    // Preview tag click / command: show the tag's notes in the sidebar.
    function showTag(tag) {
        const parts = tag.split("/");
        const m = clone(tagExpanded);
        for (let k = 1; k < parts.length; k++)
            m[parts.slice(0, k).join("/").toLowerCase()] = true;
        tagExpanded = m;
        writeState("tagExpanded", m);
        selectTag(tag.toLowerCase());
        setSidebarTab("tags");
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

    function openByName(name) {
        const q = (name || "").replace(/\.md$/i, "").toLowerCase();
        const find = () => entries.find(e => e.type === "file" && (e.path.toLowerCase() === q + ".md" || Tree.baseName(e.path).toLowerCase() === q));
        open();
        if (vaultReady) {
            const hit = find();
            if (!hit)
                return false;
            openNote(hit.path);
            return true;
        }
        afterReady(() => {
            const hit = find();
            if (hit)
                openNote(hit.path);
        });
        return true;
    }

    IpcHandler {
        target: "supernote"
        function toggle(): string {
            root.toggle();
            return root.panelVisible ? "opened" : "closed";
        }
        function open(): string {
            root.open();
            return "opened";
        }
        function close(): string {
            root.close();
            return "closed";
        }
        function newNote(): string {
            root.open();
            root.afterReady(() => root.newNote());
            return "creating";
        }
        function expand(): string {
            root.open();
            root.expandToWindow();
            return "window";
        }
        function dock(): string {
            root.dockAgain();
            return "docked";
        }
        function sidebar(): string {
            root.toggleSidebar();
            return root.showSidebar ? "sidebar shown" : "sidebar hidden";
        }
        function daily(): string {
            root.openDaily();
            return "opening today's note";
        }
        function quick(): string {
            root.afterState(() => {
                root.ensureState();
                root.captureVisible = !root.captureVisible;
            });
            return "capture box toggled";
        }
        function capture(text: string): string {
            root.capture(text);
            return "capturing";
        }
        function clip(): string {
            root.captureClipboard();
            return "capturing clipboard";
        }
        function search(query: string): string {
            root.open();
            root.afterReady(() => {
                root.setSidebarTab("search");
                root.searchRequest(query);
            });
            return "searching";
        }
        function openNote(name: string): string {
            return root.openByName(name) ? "opened" : "not found: " + name;
        }
        function removeVault(path: string): string {
            root.afterState(() => {
                root.ensureState();
                root.removeVault(root.expandPath(path));
            });
            return "removing: " + root.expandPath(path);
        }
        function vault(path: string): string {
            root.afterState(() => {
                root.ensureState();
                root.activateVault(path);
            });
            return "vault: " + root.expandPath(path);
        }
        function viewMode(mode: string): string {
            root.setViewMode(mode);
            return "viewMode: " + root.viewMode;
        }
        function status(): string {
            return JSON.stringify({
                visible: root.panelVisible,
                vault: root.activeVault,
                vaults: root.vaults,
                note: root.noteRel,
                dirty: root.dirty,
                conflict: root.conflict,
                entries: root.entries.length,
                rows: root.rows.length,
                bufferLength: root.buffer.length,
                viewMode: root.viewMode
            });
        }
    }

    Loader {
        id: ui
        active: root.uiActive
        onActiveChanged: {
            if (active)
                setSource("file://" + root.pluginDir + "/qml/ui/SuperNotePanel.qml?v=" + Date.now(), { core: root });
        }
    }

    Loader {
        id: captureUi
        active: root.captureVisible
        onActiveChanged: {
            if (active)
                setSource("file://" + root.pluginDir + "/qml/ui/CaptureBox.qml?v=" + Date.now(), { core: root });
        }
    }

    Component.onCompleted: {
        console.info("SuperNote: daemon loaded — use 'dms ipc call supernote toggle'");
        loadState();
        run([renderScript, "prune"], () => {});
    }
}
