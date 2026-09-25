import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "logic"
import "components"

// SuperNote panel: the window host and the layout of the panel components. It is docked on the right side of the screen
// (a layer-shell overlay) or, after "expand", a real floating window; the same `keys` item is re-parented between the two.
// Logic lives in the layer chain below this type (PanelBase ... SyncLayer); the visual parts are components in this folder.
SyncLayer {
    id: ui

    // items inside the components that the panel logic (and the layers above) refer to by name
    readonly property var editor: editorArea.editor
    readonly property var underlay: editorArea.underlay
    readonly property var flick: editorArea.flick
    readonly property var previewFlick: editorArea.previewFlick
    readonly property var titleInput: editorArea.titleField
    readonly property var findField: editorArea.findField
    readonly property var replaceField: editorArea.replaceField
    readonly property var tree: sidebar.tree
    readonly property var searchField: sidebar.searchField
    readonly property var switcherField: switcher.field
    readonly property var dlgField: dialog.field
    readonly property var dlgScope: dialog.scope
    readonly property var keys: keysScope
    readonly property var panelBg: panelBackground

    // Sizes of the main areas, for the IPC status and the UI smoke tests (tests/ui).
    function layoutInfo() {
        return {
            mode: core.windowMode,
            visible: overlay.visible || floatWin.visible,
            width: Math.round(keysScope.width),
            height: Math.round(keysScope.height),
            sidebarWidth: Math.round(sidebar.width),
            editorWidth: Math.round(editorArea.width),
            rightPanelWidth: Math.round(rightPanelItem.width),
            editorVisible: editor.visible,
            previewVisible: previewFlick.visible
        };
    }

    // "Expand": the same panel content (keysScope) is re-parented into a real, compositor-managed window.
    DankFloatingWindow {
        id: floatWin
        title: "SuperNote"
        implicitWidth: 1180
        implicitHeight: 780
        visible: ui.core.panelVisible && ui.core.windowMode === "window"
        onVisibleChanged: {
            if (visible)
                Qt.callLater(ui.focusEditor);
            else if (ui.core.windowMode === "window" && ui.core.panelVisible)
                ui.core.close();   // closed by the compositor
        }
        Item {
            id: winHost
            anchors.fill: parent
        }
    }

    PanelWindow {
        id: overlay
        visible: ui.core.panelVisible && !ui.browsing && ui.core.windowMode !== "window"
        color: "transparent"

        WlrLayershell.namespace: "dms:plugins:supernote"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible) {
                const s = CompositorService.getFocusedScreen();
                if (s)
                    overlay.screen = s;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ui.core.close()
        }

        FocusScope {
            id: keysScope
            readonly property bool inWindow: ui.core.windowMode === "window"
            // docked: right edge of the screen, below the bar; window: fills the floating window
            parent: inWindow ? winHost : overlay.contentItem
            x: inWindow ? 0 : parent.width - width - 12
            y: inWindow ? 0 : 52
            width: inWindow ? parent.width : Math.min(500, parent.width - 24)
            height: inWindow ? parent.height : parent.height - 52 - 12
            focus: ui.core.panelVisible

            Keys.onPressed: event => ui.handleKey(event)

            Rectangle {
                id: panelBackground
                anchors.fill: parent
                radius: keysScope.inWindow ? 0 : Theme.cornerRadius
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        ui.ctx = null;
                        ui.vaultMenuOpen = false;
                    }
                }

                Header {
                    id: header
                    ui: ui
                }

                Rectangle {
                    id: headerLine
                    anchors.top: header.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.outline
                    opacity: 0.4
                }

                Sidebar {
                    id: sidebar
                    ui: ui
                    anchors.top: headerLine.bottom
                    anchors.left: parent.left
                }

                Rectangle {
                    id: sidebarLine
                    anchors.top: headerLine.bottom
                    anchors.left: sidebar.right
                    anchors.bottom: parent.bottom
                    width: ui.core.showSidebar ? 1 : 0
                    color: Theme.outline
                    opacity: 0.4
                }


                EditorArea {
                    id: editorArea
                    ui: ui
                    anchors.top: headerLine.bottom
                    anchors.left: sidebarLine.right
                    anchors.right: rightPanelItem.left
                    anchors.bottom: parent.bottom
                }

                RightPanel {
                    id: rightPanelItem
                    ui: ui
                    anchors.top: headerLine.bottom
                }

                AutocompletePopup {
                    ui: ui
                }

                CheatSheet {
                    ui: ui
                }

                Switcher {
                    id: switcher
                    ui: ui
                }

                VaultMenu {
                    ui: ui
                }

                ContextMenu {
                    ui: ui
                }

                ConfirmDialog {
                    id: dialog
                    ui: ui
                }
            }
        }
    }
}
