import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

// Rendered markdown preview (rich text) with the frontmatter properties block. Inputs: ui (previewHtml, previewProps).
// Exposes its flickable for scrolling.
Flickable {
    id: previewFlick
    required property var ui

    visible: ui.core.viewMode !== "edit"
    x: ui.core.viewMode === "split" ? parent.width / 2 + 1 : 0
    width: ui.core.viewMode === "split" ? parent.width / 2 - 1 : parent.width
    height: parent.height
    clip: true
    contentWidth: width
    contentHeight: previewCol.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    Column {
        id: previewCol
        x: 28
        y: 12
        width: previewFlick.width - 56
        spacing: 12

        Rectangle {
            visible: ui.previewProps.length > 0
            width: parent.width
            height: propsCol.implicitHeight + 16
            radius: 8
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outline
            Column {
                id: propsCol
                x: 12
                y: 8
                width: parent.width - 24
                spacing: 4
                Repeater {
                    model: ui.previewProps
                    Row {
                        required property var modelData
                        spacing: 10
                        StyledText {
                            width: 110
                            text: modelData.key
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                        StyledText {
                            width: propsCol.width - 120
                            text: modelData.text
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            textFormat: Text.RichText
            text: ui.previewHtml
            wrapMode: Text.Wrap
            color: Theme.surfaceText
            linkColor: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 16
            onLinkActivated: link => ui.handleLink(link)
        }
    }

    readonly property var flickable: previewFlick
}
