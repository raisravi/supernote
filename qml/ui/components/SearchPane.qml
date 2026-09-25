import QtQuick
import qs.Common
import qs.Widgets
import "../../../js/search.js" as Search

// Sidebar search pane: query field, results grouped by note (ui.searchRows). Inputs: ui. Exposes the query field (`field`).
FocusScope {
    id: searchScope
    required property var ui

    visible: ui.core.sidebarTab === "search"
    property int cur: -1
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            cur = Math.min(cur + 1, ui.searchRows.length - 1);
        } else if (event.key === Qt.Key_Up) {
            cur = Math.max(cur - 1, 0);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const r = ui.searchRows[Math.max(cur, 0)];
            if (r)
                searchScope.activate(r);
        } else if (event.key === Qt.Key_Escape) {
            if (searchField.text.length > 0) {
                searchField.text = "";
                ui.core.search("");
            } else {
                ui.focusEditor();
            }
        } else {
            return;
        }
        if (cur >= 0)
            searchList.positionViewAtIndex(cur, ListView.Contain);
        event.accepted = true;
    }
    function activate(r) {
        if (r.kind === "file")
            ui.toggleSearchFile(r.path);
        else
            ui.core.openNote(r.path, false, "", r.kind === "match" ? r.line : 0);
    }
    DankTextField {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        leftIconName: "search"
        leftIconSize: 16
        textColor: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
        placeholderText: "Search all notes…"
        keyForwardTargets: [searchScope]
        onTextEdited: searchTimer.restart()
    }
    Timer {
        id: searchTimer
        interval: 250
        onTriggered: ui.core.search(searchField.text)
    }
    ListView {
        id: searchList
        anchors.top: searchField.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 1
        model: ui.searchRows
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            id: srow
            required property var modelData
            required property int index
            width: ListView.view.width
            height: modelData.kind === "match" ? 24 : 28
            radius: 6
            color: index === searchScope.cur ? Theme.primaryContainer : (srMouse.containsMouse ? Theme.surfaceContainer : "transparent")
            Row {
                visible: modelData.kind !== "match"
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.kind === "file" ? (modelData.collapsed ? "chevron_right" : "expand_more") : "description"
                    size: 16
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: srow.width - 60
                    text: modelData.kind === "file" ? ui.core.noteTitleOf(modelData.path) + "  (" + modelData.count + ")" : modelData.name + (modelData.folder ? "   " + modelData.folder : "")
                    elide: Text.ElideRight
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: modelData.kind === "file" ? Font.DemiBold : Font.Normal
                }
            }
            StyledText {
                visible: modelData.kind === "match"
                anchors.verticalCenter: parent.verticalCenter
                x: 26
                width: parent.width - 34
                textFormat: Text.StyledText
                text: modelData.kind === "match" ? '<font color="' + Theme.surfaceVariantText + '">' + modelData.line + '  </font>' + Search.snippetHtml(modelData.text, ui.core.searchQuery.trim(), Theme.primary, 90) : ""
                elide: Text.ElideRight
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
            MouseArea {
                id: srMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    searchScope.cur = index;
                    searchScope.activate(modelData);
                }
            }
        }
    }
    StyledText {
        anchors.centerIn: searchList
        width: searchList.width - 24
        visible: ui.searchRows.length === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: ui.core.searching ? "Searching…" : (ui.core.searchQuery.trim().length < 2 ? "Type at least two characters.\nCtrl+Shift+F jumps here." : "No matches.")
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
    }

    readonly property var field: searchField
}
