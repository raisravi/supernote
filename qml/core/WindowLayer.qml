import QtQuick

// Panel visibility (docked on the right or a real window), sidebar visibility and the one-time state load.
CaptureLayer {
    id: root

    property bool panelVisible: false
    property bool uiActive: false
    property string windowMode: "dock"          // "dock" (right side) | "window" (real floating window); reset on open
    property bool showSidebarDock: false
    property bool showSidebarWindow: true
    readonly property bool showSidebar: windowMode === "window" ? showSidebarWindow : showSidebarDock

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

    function loadWindowState() {
        showSidebarDock = readState("sidebarDock", false);
        showSidebarWindow = readState("sidebarWindow", true);
    }

    // Read every persisted setting once, on first use (each layer owns its own keys).
    function ensureState() {
        if (stateReady)
            return;
        loadVaultState();
        loadNoteState();
        loadNavState();
        loadOrganizeState();
        loadFileOpsState();
        loadWindowState();
        stateReady = true;
    }
}
