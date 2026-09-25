import QtQuick
import qs.Common
import qs.Widgets
import "../widgets"

// Vault menu under the header: switch / remove vaults, undo last rename, open another vault. Inputs: ui.
Rectangle {
    required property var ui

    visible: ui.vaultMenuOpen
    x: 10
    y: 46
    z: 50
    width: 320
    height: vaultCol.implicitHeight + 12
    radius: 10
    color: Theme.surfaceContainerHigh
    border.width: 1
    border.color: Theme.outline
    Column {
        id: vaultCol
        x: 6
        y: 6
        width: parent.width - 12
        spacing: 2
        Repeater {
            model: ui.core.vaults
            MenuItem {
                id: vaultItem
                required property string modelData
                label: ui.core.vaultName(modelData) + (modelData === ui.core.activeVault ? "   (active)" : "")
                icon: "folder"
                onTriggered: {
                    ui.vaultMenuOpen = false;
                    if (modelData !== ui.core.activeVault)
                        ui.core.activateVault(modelData);
                }
                IconBtn {
                    visible: ui.core.vaults.length > 1
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    icon: "close"
                    onClicked: {
                        ui.vaultMenuOpen = false;
                        ui.core.removeVault(vaultItem.modelData);
                    }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.4
        }
        MenuItem {
            visible: ui.core.lastRename !== null && ui.core.lastRename !== undefined && ui.core.lastRename.vault === ui.core.activeVault
            label: ui.core.lastRename ? "Undo: " + ui.core.lastRename.from.split("/").pop().replace(/\.md$/, "") + " → " + ui.core.lastRename.to.split("/").pop().replace(/\.md$/, "") : ""
            icon: "undo"
            onTriggered: {
                ui.vaultMenuOpen = false;
                ui.core.undoRename();
            }
        }
        MenuItem {
            label: "Open another vault…"
            icon: "add"
            onTriggered: ui.addVault()
        }
    }
}
