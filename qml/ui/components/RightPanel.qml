import QtQuick
import qs.Common
import qs.Widgets

// Right panel: Outline / Backlinks / Links tabs for the open note (data comes from ui.outline, ui.backlinkRows, ui.noteLinks).
// Inputs: ui. The host anchors it below the header line.
Item {
    id: rightPanelItem
    required property var ui

    visible: ui.core.rightPanel
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: visible ? 300 : 0

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.outline
        opacity: 0.4
    }

    Row {
        id: rpTabs
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 6
        Repeater {
            model: [{ id: "outline", label: "Outline" }, { id: "backlinks", label: "Backlinks" }, { id: "links", label: "Links" }]
            Rectangle {
                required property var modelData
                readonly property bool on: ui.core.rightTab === modelData.id
                width: rpLabel.implicitWidth + 20
                height: 28
                radius: 14
                color: on ? Theme.primaryContainer : "transparent"
                border.width: 1
                border.color: on ? Theme.primary : Theme.outline
                StyledText {
                    id: rpLabel
                    anchors.centerIn: parent
                    text: parent.modelData.label + (parent.modelData.id === "backlinks" && ui.core.backlinks.length ? " " + ui.core.backlinks.length : (parent.modelData.id === "links" && ui.noteLinks.length ? " " + ui.noteLinks.length : ""))
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: ui.core.setRightTab(parent.modelData.id)
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !ui.core.noteRel
        text: "Open a note to see its outline,\nbacklinks and links."
        horizontalAlignment: Text.AlignHCenter
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
    }

    ListView {
        visible: ui.core.rightTab === "outline" && ui.core.noteRel !== ""
        anchors.top: rpTabs.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        clip: true
        model: ui.outline
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 28
            radius: 6
            color: olMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                x: 8 + (modelData.level - 1) * 14
                width: parent.width - x - 8
                text: modelData.text
                elide: Text.ElideRight
                color: modelData.level === 1 ? Theme.surfaceText : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: modelData.level <= 2 ? Font.DemiBold : Font.Normal
            }
            MouseArea {
                id: olMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: ui.jumpToOffset(modelData.offset)
            }
        }
        StyledText {
            anchors.centerIn: parent
            visible: ui.outline.length === 0
            text: "No headings in this note."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }
    }

    ListView {
        visible: ui.core.rightTab === "backlinks" && ui.core.noteRel !== ""
        anchors.top: rpTabs.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        clip: true
        model: ui.backlinkRows
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: modelData.kind === "file" ? 30 : 34
            radius: 6
            color: blMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            Row {
                visible: modelData.kind === "file"
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                spacing: 6
                DankIcon { anchors.verticalCenter: parent.verticalCenter; name: "description"; size: 16; color: Theme.primary }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 210
                    text: ui.core.noteTitleOf(modelData.path) + "  (" + modelData.count + ")"
                    elide: Text.ElideRight
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                }
            }
            StyledText {
                visible: modelData.kind === "line"
                anchors.verticalCenter: parent.verticalCenter
                x: 30
                width: parent.width - 38
                text: modelData.text
                elide: Text.ElideRight
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
            MouseArea {
                id: blMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: ui.core.openNote(modelData.path, false, "", modelData.line || 0)
            }
        }
        StyledText {
            anchors.centerIn: parent
            visible: ui.backlinkRows.length === 0
            text: "No other note links here."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }
    }

    ListView {
        visible: ui.core.rightTab === "links" && ui.core.noteRel !== ""
        anchors.top: rpTabs.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        clip: true
        model: ui.noteLinks
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 30
            radius: 6
            color: lkMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                spacing: 6
                DankIcon { anchors.verticalCenter: parent.verticalCenter; name: modelData.resolved ? "link" : "link_off"; size: 16; color: modelData.resolved ? Theme.primary : Theme.surfaceVariantText }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    text: modelData.name + (modelData.heading ? " # " + modelData.heading : "") + (modelData.count > 1 ? "  ×" + modelData.count : "")
                    elide: Text.ElideRight
                    color: modelData.resolved ? Theme.surfaceText : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                }
            }
            MouseArea {
                id: lkMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: ui.core.openLink(modelData.name, modelData.heading)
            }
        }
        StyledText {
            anchors.centerIn: parent
            visible: ui.noteLinks.length === 0
            text: "This note links to nothing yet."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
        }
    }
}
