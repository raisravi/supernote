import QtQuick
import qs.Common
import qs.Widgets
import "../widgets"

// Find / replace bar (Ctrl+F / Ctrl+H). Inputs: ui (find* state). Exposes the two text fields. The host anchors it.
Rectangle {
    id: findBar
    required property var ui

    visible: ui.findOpen && ui.core.viewMode !== "preview"
    anchors.topMargin: visible ? 6 : 0
    anchors.left: parent.left
    anchors.leftMargin: 20
    anchors.right: parent.right
    anchors.rightMargin: 20
    height: visible ? (ui.replaceOpen ? 76 : 40) : 0
    radius: 8
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outline

    Column {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4
        Row {
            spacing: 6
            height: 32
            DankTextField {
                id: findField
                width: 300
                height: 32
                leftIconName: "search"
                leftIconSize: 16
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                placeholderText: "Find"
                keyForwardTargets: [ui.keys]
                onTextEdited: ui.findTimer.restart()
                onAccepted: ui.findStep(1)
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                text: ui.matches.length === 0 ? (findField.text ? "No matches" : "") : (ui.matchIndex + 1) + " / " + ui.matches.length
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
            IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "keyboard_arrow_up"; onClicked: ui.findStep(-1) }
            IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "keyboard_arrow_down"; onClicked: ui.findStep(1) }
            Rectangle {
                width: 28
                height: 28
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: ui.findCase ? Theme.primaryContainer : "transparent"
                StyledText { anchors.centerIn: parent; text: "Aa"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                MouseArea { anchors.fill: parent; onClicked: { ui.findCase = !ui.findCase; ui.recomputeMatches(); } }
            }
            Rectangle {
                width: 28
                height: 28
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: ui.findRegex ? Theme.primaryContainer : "transparent"
                StyledText { anchors.centerIn: parent; text: ".*"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                MouseArea { anchors.fill: parent; onClicked: { ui.findRegex = !ui.findRegex; ui.recomputeMatches(); } }
            }
            IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "find_replace"; active: ui.replaceOpen; onClicked: ui.replaceOpen = !ui.replaceOpen }
            IconBtn { width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter; icon: "close"; onClicked: ui.closeFind() }
        }
        Row {
            visible: ui.replaceOpen
            spacing: 6
            height: 32
            DankTextField {
                id: replaceField
                width: 300
                height: 32
                leftIconName: "edit"
                leftIconSize: 16
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                placeholderText: "Replace with"
                keyForwardTargets: [ui.keys]
                onAccepted: ui.replaceCurrent()
            }
            Rectangle {
                width: replLabel.implicitWidth + 20
                height: 28
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1
                border.color: Theme.outline
                StyledText { id: replLabel; anchors.centerIn: parent; text: "Replace"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                MouseArea { anchors.fill: parent; onClicked: ui.replaceCurrent() }
            }
            Rectangle {
                width: replAllLabel.implicitWidth + 20
                height: 28
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1
                border.color: Theme.outline
                StyledText { id: replAllLabel; anchors.centerIn: parent; text: "Replace all"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                MouseArea { anchors.fill: parent; onClicked: ui.replaceEverything() }
            }
        }
    }

    readonly property var field: findField
    readonly property var replaceInput: replaceField
}
