import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../../js/mdkeys.js" as MdKeys
import "../../js/markdown.js" as Md

// SuperNote quick capture: a small markdown box. Enter is a new line (lists continue like in the editor);
// Ctrl+Enter appends to today's daily note, Ctrl+Shift+Enter saves an Inbox note, Esc cancels.
// Own layer-shell window so it opens instantly without the main panel.
Item {
    id: box

    required property var core
    property bool busy: false

    function close() {
        core.captureVisible = false;
    }

    // Ctrl+click a [[link]] in the draft: open (or create) it in the main panel. The capture box is left open
    // with the draft intact - following a link is a quick peek, not a reason to lose what you were writing.
    function followLinkAt(offset) {
        const link = Md.linkAt(field.text, offset);
        if (!link)
            return;
        core.followLink(link.name, link.heading);
    }

    function submit(asNote) {
        const t = field.text.trim();
        if (!t || busy) {
            if (!t)
                close();
            return;
        }
        busy = true;
        const done = ok => {
            busy = false;
            if (ok)
                close();
        };
        if (asNote)
            core.captureAsNote(t, done);
        else
            core.capture(t, done);
    }

    PanelWindow {
        id: win
        visible: box.core.captureVisible
        color: "transparent"

        WlrLayershell.namespace: "dms:plugins:supernote-capture"
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
                    win.screen = s;
                field.text = "";
                box.busy = false;
                Qt.callLater(() => field.forceActiveFocus());
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.55)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: box.close()
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.28
            width: Math.min(parent.width - 40, 600)
            height: 60 + Math.max(90, Math.min(field.contentHeight + 24, 300)) + 34
            radius: 14
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outline

            MouseArea {
                anchors.fill: parent
            }

            Row {
                id: head
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 8
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bolt"
                    size: 20
                    color: Theme.primary
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Quick capture"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: box.busy ? "saving…" : "→ today's daily note"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Flickable {
                id: flick
                anchors.top: head.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: hint.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 6
                clip: true
                contentHeight: field.contentHeight + 16
                boundsBehavior: Flickable.StopAtBounds

                TextArea.flickable: TextArea {
                    id: field
                    wrapMode: TextEdit.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    selectByMouse: true
                    placeholderText: "What's on your mind? (markdown works)"
                    placeholderTextColor: Theme.surfaceVariantText
                    background: null
                    readOnly: box.busy
                    // Ctrl+click follows a [[wikilink]] (a plain click still just places the caret)
                    TapHandler {
                        acceptedModifiers: Qt.ControlModifier
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: eventPoint => box.followLinkAt(field.positionAt(eventPoint.position.x, eventPoint.position.y))
                    }
                    Keys.onPressed: event => {
                        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                        const alt = (event.modifiers & Qt.AltModifier) !== 0;
                        if (event.key === Qt.Key_Escape) {
                            box.close();
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && ctrl) {
                            box.submit(shift);
                            event.accepted = true;
                        } else if (!box.busy) {
                            const ed = MdKeys.handle(field.text, field.selectionStart, field.selectionEnd, { key: event.key, ctrl: ctrl, shift: shift, alt: alt, text: event.text });
                            if (ed) {
                                MdKeys.applyEdit(field, ed);
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && !ctrl && !alt) {
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            StyledText {
                id: hint
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 14
                text: "Enter new line  ·  Ctrl+Enter add to daily  ·  Ctrl+Shift+Enter save as note  ·  Esc cancel"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
