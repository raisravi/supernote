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

    // Width of the docked panel (drag handle / Alt+ / Alt- in the panel; irrelevant in window mode, where the
    // compositor's own window resize applies). The UI clamps this again to the screen width when laying out.
    readonly property int minDockWidth: 360
    readonly property int maxDockWidth: 1400
    readonly property int dockWidthStep: 40
    readonly property int defaultDockWidth: 500
    property int dockWidth: 500

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

    function setDockWidth(w) {
        const clamped = Math.round(Math.max(minDockWidth, Math.min(maxDockWidth, w)));
        if (clamped === dockWidth)
            return;
        dockWidth = clamped;
        writeState("dockWidth", clamped);
    }

    function loadWindowState() {
        showSidebarDock = readState("sidebarDock", false);
        showSidebarWindow = readState("sidebarWindow", true);
        dockWidth = readState("dockWidth", defaultDockWidth);
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
