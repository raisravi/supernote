import QtQuick
import Quickshell.Io
import "qml/core"

// SuperNote entry point (plugin.json "component"). The controller itself is the layer chain in qml/core
// (CoreBase ... WindowLayer); this file adds what only the daemon needs: the IPC surface, the math/Mermaid
// service and the loaders for the panel and the quick-capture box.
//
// The panel and capture box are loaded through cache-busting URLs, so `dms ipc call plugins reload supernote`
// re-reads them; every other QML/JS file is cached by URL and needs `dms restart` (see docs/DEVELOPMENT.md).
WindowLayer {
    id: root

    // math / Mermaid pictures for the preview (independent of everything else)
    readonly property RenderService render: RenderService {
        core: root
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
        render.prune();
    }
}
