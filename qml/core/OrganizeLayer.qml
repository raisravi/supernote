import QtQuick
import "../../js/tree.js" as Tree
import "../../js/markdown.js" as Md

// Organization: pinned/recent sections, sidebar tab, full-text search and the vault tag index.
NavLayer {
    id: root

    function loadOrganizeState() {
        pinsByVault = readState("pins", {});
        sections = readState("sections", { pins: true, recent: true });
        sidebarTab = readState("sidebarTab", "files");
        tagExpanded = readState("tagExpanded", {});
        tagSelected = readState("tagSelected", "");
        tagsWanted = sidebarTab === "tags";
    }

    property var pinsByVault: ({})
    readonly property var pins: pinsByVault[activeVault] || []
    property var sections: ({ pins: true, recent: true })
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
    signal searchRequest(string query)

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
}
