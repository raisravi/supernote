import QtQuick
import qs.Common
import qs.Widgets

// Keyboard shortcut cheat sheet overlay (Ctrl+/). Inputs: ui (cheatOpen, cheatRows).
Rectangle {
    required property var ui

    visible: ui.cheatOpen
    anchors.fill: parent
    z: 120
    radius: Theme.cornerRadius
    color: Qt.rgba(0, 0, 0, 0.5)
    MouseArea {
        anchors.fill: parent
        onClicked: ui.cheatOpen = false
    }
    Rectangle {
        anchors.centerIn: parent
        width: 620
        height: Math.min(parent.height - 80, 640)
        radius: 12
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outline
        MouseArea {
            anchors.fill: parent
        }
        StyledText {
            id: cheatTitle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 18
            text: "Keyboard shortcuts"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
        }
        ListView {
            anchors.top: cheatTitle.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 18
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ui.cheatRows
            delegate: Item {
                required property var modelData
                width: ListView.view.width
                height: modelData.header ? 34 : 26
                StyledText {
                    visible: !!modelData.header
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: modelData.header ? modelData.header.toUpperCase() : ""
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                }
                StyledText {
                    visible: !modelData.header
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title || ""
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }
                StyledText {
                    visible: !modelData.header
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.keys || ""
                    color: Theme.surfaceVariantText
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
