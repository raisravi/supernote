import QtQuick
import qs.Common
import qs.Widgets

// Banner shown when the open note changed on disk while it had unsaved edits: keep mine / reload. Inputs: ui.
Rectangle {
    id: banner
    required property var ui

    visible: ui.core.conflict
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: visible ? 44 : 0
    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "This note changed on disk while you were editing."
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Rectangle {
            width: keepLabel.implicitWidth + 24
            height: 28
            radius: 14
            color: Theme.primary
            StyledText {
                id: keepLabel
                anchors.centerIn: parent
                text: "Keep my edits"
                color: Theme.primaryText
                font.pixelSize: Theme.fontSizeSmall
            }
            MouseArea {
                anchors.fill: parent
                onClicked: ui.core.resolveKeepMine()
            }
        }
        Rectangle {
            width: reloadLabel.implicitWidth + 24
            height: 28
            radius: 14
            color: "transparent"
            border.width: 1
            border.color: Theme.outline
            StyledText {
                id: reloadLabel
                anchors.centerIn: parent
                text: "Reload from disk"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
            MouseArea {
                anchors.fill: parent
                onClicked: ui.core.resolveReload()
            }
        }
    }
}
