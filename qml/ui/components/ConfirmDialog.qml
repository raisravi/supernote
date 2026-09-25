import QtQuick
import qs.Common
import qs.Widgets

// Modal dialog: title, message, optional text input, confirm / alt / cancel (configured by ui.ask()).
// Inputs: ui. Exposes the input field and the focus scope.
Rectangle {
    required property var ui

    visible: ui.dlgOpen
    anchors.fill: parent
    z: 100
    radius: Theme.cornerRadius
    color: Qt.rgba(0, 0, 0, 0.45)
    MouseArea {
        anchors.fill: parent
    }

    FocusScope {
        id: dlgScope
        anchors.centerIn: parent
        width: 420
        height: dlgCol.implicitHeight + 40
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                ui.dlgCancel();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                ui.dlgAccept();
                event.accepted = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outline
        }
        Column {
            id: dlgCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 14
            StyledText {
                text: ui.dlgTitle
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
            }
            StyledText {
                visible: ui.dlgMessage.length > 0
                width: parent.width
                text: ui.dlgMessage
                wrapMode: Text.WordWrap
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
            }
            DankTextField {
                id: dlgField
                visible: ui.dlgInput
                width: parent.width
                height: 44
                textColor: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                keyForwardTargets: [dlgScope]
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Rectangle {
                    width: cancelLabel.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.outline
                    StyledText {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ui.dlgCancel()
                    }
                }
                Rectangle {
                    visible: ui.dlgAlt.length > 0
                    width: altLabel.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.primary
                    StyledText {
                        id: altLabel
                        anchors.centerIn: parent
                        text: ui.dlgAlt
                        color: Theme.primary
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ui.dlgAccept2()
                    }
                }
                Rectangle {
                    width: okLabel.implicitWidth + 28
                    height: 32
                    radius: 16
                    color: ui.dlgDanger ? Theme.error : Theme.primary
                    StyledText {
                        id: okLabel
                        anchors.centerIn: parent
                        text: ui.dlgConfirm
                        color: ui.dlgDanger ? Theme.background : Theme.primaryText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ui.dlgAccept()
                    }
                }
            }
        }
    }

    readonly property var field: dlgField
    readonly property var scope: dlgScope
}
