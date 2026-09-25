import QtQuick
import qs.Common
import qs.Widgets
import "../../../js/markdown.js" as Md
import "../widgets"

// Collapsible frontmatter properties editor under the title (edit / remove / add keys). Inputs: ui. The host anchors it.
Item {
    id: propsBlock
    required property var ui

    // Values from the model arrive as list-like objects, for which Array.isArray() is false.
    function isList(v) {
        return v !== null && typeof v === "object" && v.length !== undefined;
    }

    function display(v) {
        return isList(v) ? Array.prototype.join.call(v, ", ") : String(v);
    }

    visible: ui.core.noteRel !== "" && ui.core.viewMode !== "preview"
    anchors.topMargin: 4
    height: visible ? propsHead.height + (ui.core.propsOpen ? propsList.implicitHeight + 6 : 0) : 0
    clip: true

    Item {
        id: propsHead
        width: parent.width
        height: 26
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: ui.core.propsOpen ? "expand_more" : "chevron_right"
                size: 16
                color: Theme.surfaceVariantText
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Properties" + (ui.props.length ? "  " + ui.props.length : "")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: ui.core.toggleProps()
        }
    }

    Column {
        id: propsList
        visible: ui.core.propsOpen
        anchors.top: propsHead.bottom
        width: parent.width
        spacing: 2
        Repeater {
            model: ui.props
            Rectangle {
                id: prow
                required property var modelData
                readonly property string forNote: ui.core.noteRel
                width: propsList.width
                height: 28
                radius: 6
                color: Theme.surfaceContainer
                StyledText {
                    id: pkey
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    text: modelData.key
                    elide: Text.ElideRight
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
                TextInput {
                    id: pval
                    anchors.left: pkey.right
                    anchors.right: pdel.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 6
                    clip: true
                    color: Theme.surfaceText
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    font.pixelSize: Theme.fontSizeMedium
                    text: propsBlock.display(modelData.value)
                    selectByMouse: true
                    onEditingFinished: {
                        if (prow.forNote !== ui.core.noteRel)
                            return;
                        const cur = propsBlock.display(prow.modelData.value);
                        if (text !== cur)
                            ui.commitProp(prow.modelData.key, text, propsBlock.isList(prow.modelData.value));
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            text = propsBlock.display(prow.modelData.value);
                            ui.focusEditor();
                            event.accepted = true;
                        }
                    }
                }
                IconBtn {
                    id: pdel
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    icon: "close"
                    onClicked: ui.core.applyExternalText(Md.removeProperty(ui.core.buffer, prow.modelData.key))
                }
            }
        }
        Rectangle {
            width: propsList.width
            height: 28
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: Theme.outline
            TextInput {
                id: newKey
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 110
                clip: true
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                Keys.onTabPressed: newVal.forceActiveFocus()
                StyledText {
                    visible: newKey.text.length === 0
                    text: "+ new property"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            TextInput {
                id: newVal
                anchors.left: newKey.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                visible: newKey.text.length > 0
                onAccepted: {
                    const k = newKey.text.trim();
                    if (!k || !/^[A-Za-z0-9_\- ]+$/.test(k))
                        return;
                    ui.commitProp(k, text, false);
                    newKey.text = "";
                    text = "";
                    ui.focusEditor();
                }
                StyledText {
                    visible: newVal.text.length === 0
                    text: "value, Enter to add"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
