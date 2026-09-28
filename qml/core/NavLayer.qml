import QtQuick
import "../../js/tree.js" as Tree
import "../../js/tabs.js" as Tabs

// Navigation: tabs with per-tab history, recent notes, wikilink opening, backlinks and the right panel.
// `doOpen` is the only place a note is loaded into the buffer.
NoteLayer {
    id: root

    function loadNavState() {
        tabsByVault = readState("tabs", {});
        recentByVault = readState("recent", {});
        rightPanel = readState("rightPanel", false);
        rightTab = readState("rightTab", "outline");
    }

    property var tabState: Tabs.init()
    property var tabsByVault: ({})
    property var recentByVault: ({})
    property var currentView: null
    property string pendingHeading: ""
    property var backlinks: []
    property bool rightPanel: false
    property string rightTab: "outline"
    readonly property var recent: recentByVault[activeVault] || []
    property string pendingLine: ""

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

    // Same as openLink, but usable when the panel might be closed and the vault not yet loaded (e.g. a [[link]]
    // clicked in the quick-capture box, a separate window): shows the panel and waits for the vault first.
    function followLink(name, heading) {
        open();
        afterReady(() => openLink(name, heading));
    }

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

    signal jumpOffset(int offset)
    property int pendingCursor: -1

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
}
