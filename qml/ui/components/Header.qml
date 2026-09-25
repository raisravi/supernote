import QtQuick
import qs.Common
import qs.Widgets
import "../widgets"

// Panel header: vault menu button, new note / daily / folder / sort / refresh / pin / right panel / sidebar /
// expand-to-window / close buttons.
// Inputs: ui (panel state + actions).
Item {
    id: header
    required property var ui

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 48

    Rectangle {
        id: vaultBtn
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 32
        width: vaultRow.implicitWidth + 20
        radius: 8
        color: vaultMouse.containsMouse || ui.vaultMenuOpen ? Theme.surfaceContainerHigh : "transparent"
        Row {
            id: vaultRow
            anchors.centerIn: parent
            spacing: 6
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "folder_open"
                size: 18
                color: Theme.primary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, ui.keys.inWindow ? 260 : 110)
                elide: Text.ElideRight
                text: ui.core.vaultName(ui.core.activeVault) || "Vault"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
            }
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"
                size: 18
                color: Theme.surfaceVariantText
            }
        }
        MouseArea {
            id: vaultMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ui.vaultMenuOpen = !ui.vaultMenuOpen
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        IconBtn {
            icon: "note_add"
            onClicked: ui.core.newNote()
        }
        IconBtn {
            icon: "today"
            onClicked: ui.core.openDaily()
        }
        IconBtn {
            visible: ui.core.showSidebar
            icon: "create_new_folder"
            onClicked: ui.askNewFolder(ui.core.targetDir())
        }
        IconBtn {
            visible: ui.core.showSidebar
            icon: "schedule"
            active: ui.core.sortByMtime
            onClicked: ui.core.toggleSort()
        }
        IconBtn {
            visible: ui.core.showSidebar
            icon: "refresh"
            onClicked: ui.core.refreshTree()
        }
        IconBtn {
            visible: ui.core.noteRel !== ""
            icon: "push_pin"
            active: ui.core.pins.indexOf(ui.core.noteRel) >= 0
            onClicked: ui.core.togglePin(ui.core.noteRel)
        }
        IconBtn {
            icon: "right_panel_open"
            active: ui.core.rightPanel
            onClicked: ui.core.setRightPanel(!ui.core.rightPanel)
        }
        IconBtn {
            icon: "left_panel_open"
            active: ui.core.showSidebar
            onClicked: ui.core.toggleSidebar()
        }
        IconBtn {
            icon: ui.keys.inWindow ? "close_fullscreen" : "open_in_new"
            onClicked: ui.keys.inWindow ? ui.core.dockAgain() : ui.core.expandToWindow()
        }
        IconBtn {
            icon: "close"
            onClicked: ui.core.close()
        }
    }
}
