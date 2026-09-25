import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

// The editor: a scrolling monospace TextArea with a colored RichText underlay for syntax highlighting.
// Inputs: ui. Exposes the text area, its flickable and the underlay.
Flickable {
    id: flick
    required property var ui

    visible: ui.core.viewMode !== "preview"
    x: 0
    width: ui.core.viewMode === "split" ? parent.width / 2 : parent.width
    height: parent.height
    clip: true
    contentWidth: width
    contentHeight: editor.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    onContentYChanged: ui.core.currentView = { cursor: editor.cursorPosition, scroll: contentY }
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    // colored copy of the text, drawn behind the (transparent) editor
    Text {
        id: underlay
        visible: ui.coloringOk && ui.hlHtml.length > 0
        x: editor.leftPadding
        y: editor.topPadding
        width: editor.width - editor.leftPadding - editor.rightPadding
        z: -1
        textFormat: Text.RichText
        wrapMode: Text.Wrap
        font: editor.font
        color: Theme.surfaceText
        text: ui.hlHtml
    }

    TextArea.flickable: TextArea {
        id: editor
        wrapMode: TextEdit.Wrap
        font.family: Theme.monoFontFamily
        font.pixelSize: ui.core.editorFontSize > 0 ? ui.core.editorFontSize : 15
        font.letterSpacing: 0
        color: ui.coloringOk && ui.hlHtml.length > 0 ? "transparent" : Theme.surfaceText
        selectedTextColor: ui.coloringOk && ui.hlHtml.length > 0 ? "transparent" : Theme.primaryText
        selectionColor: ui.coloringOk && ui.hlHtml.length > 0 ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Theme.primary
        selectByMouse: true
        persistentSelection: true
        textFormat: TextEdit.PlainText
        tabStopDistance: 32
        leftPadding: 28
        rightPadding: 28
        topPadding: 10
        bottomPadding: 40
        background: null
        placeholderText: "Start writing…"
        placeholderTextColor: Theme.surfaceVariantText
        cursorDelegate: Rectangle {
            width: 2
            color: Theme.primary
            visible: editor.activeFocus
        }
        Keys.onPressed: event => ui.editorKey(event)
        onTextChanged: {
            if (!ui.syncing) {
                ui.core.onEdited(text);
                if (ui.findOpen)
                    findTimer.restart();
            }
            ui.refreshHighlight();
            ui.updateAutocomplete();
        }
        onCursorPositionChanged: {
            ui.updateCursorInfo();
            ui.core.currentView = { cursor: cursorPosition, scroll: flick.contentY };
            ui.updateAutocomplete();
        }
        onFocusChanged: if (!focus)
            ui.acOpen = false
        onCursorRectangleChanged: {
            if (cursorRectangle.y < flick.contentY)
                flick.contentY = cursorRectangle.y;
            else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height - 40)
                flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height + 40;
        }
    }

    readonly property var textArea: editor
    readonly property var flickable: flick
    readonly property var underlayItem: underlay
}
