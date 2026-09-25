import QtQuick
import "../../../js/search.js" as Search
import "../../../js/tags.js" as Tags
import "../../../js/fuzzy.js" as Fuzzy

// Panel logic, part 4: sidebar search results and tag rows.
FindLayer {
    id: ui

    property var searchCollapsed: ({})
    property string tagFilter: ""
    readonly property var searchRows: buildSearchRows(core.searchResults, core.searchQuery, searchCollapsed)
    readonly property var tagRows: buildTagRows(core.noteTags, core.tagExpanded, tagFilter, core.tagSelected)

    function buildSearchRows(results, query, collapsed) {
        const q = query.trim();
        if (q.length < 2)
            return [];
        const rows = [];
        Fuzzy.rank(noteItems(), q, 5).forEach(r => rows.push({ kind: "name", path: r.item.path, name: r.item.name, folder: r.item.folder }));
        Search.flatRows(Search.group(results), collapsed).forEach(r => rows.push(r));
        return rows;
    }

    function buildTagRows(index, expanded, filter, selected) {
        const out = [];
        Tags.rows(index, expanded, filter).forEach(r => {
            out.push({ kind: "tag", tag: r.tag, name: r.name, depth: r.depth, count: r.count, hasChildren: r.hasChildren, expanded: r.expanded, selected: r.tag === selected });
            if (r.tag === selected)
                Tags.notesFor(index, selected).forEach(p => out.push({ kind: "note", path: p, depth: r.depth + 1 }));
        });
        return out;
    }

    function openSearch() {
        core.setSidebarTab("search");
        Qt.callLater(() => {
            searchField.forceActiveFocus();
            searchField.selectAll();
        });
    }

    function toggleSearchFile(path) {
        const m = Object.assign({}, searchCollapsed);
        if (m[path])
            delete m[path];
        else
            m[path] = true;
        searchCollapsed = m;
    }
}
