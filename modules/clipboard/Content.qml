pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// The clipboard-history overlay itself: a horizontally scrolling "film
// strip" of captured entries (see Frame.qml), sprocket-hole perforations
// along the top and bottom evoking an actual strip of film, with a remove
// button per frame (Frame.qml) and a "Clear all" button here.
StyledRect {
    id: root

    required property ScreenState screenState

    readonly property var entries: ClipboardHistory.entries
    readonly property bool isEmpty: entries.length === 0

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large

    implicitWidth: Math.min(inner.implicitWidth, 900) + inner.anchors.margins * 2
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.largeIncreased

        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "content_paste"
                color: Colours.palette.m3primary
                font: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Clipboard History")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.small
            }

            IconTextButton {
                visible: !root.isEmpty
                type: IconTextButton.Text
                icon: "delete_sweep"
                text: qsTr("Clear all")
                onClicked: ClipboardHistory.removeAll()
            }

            IconButton {
                isRound: true
                type: IconButton.Text
                icon: "close"
                onClicked: root.screenState.clipboardHistory = false
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.screenState.clipboardHistory && ClipboardHistory.denied
            text: qsTr("This shell was denied access to the clipboard history - allow it from the compositor's permission prompt, then reopen the compositor to try again.")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.isEmpty && !ClipboardHistory.denied
            text: qsTr("Nothing copied yet.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !root.isEmpty
            spacing: Tokens.spacing.extraSmall

            Perforation {
                Layout.fillWidth: true
            }

            StyledFlickable {
                id: flick

                Layout.fillWidth: true
                implicitHeight: row.implicitHeight
                contentWidth: row.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: row

                    spacing: Tokens.spacing.small

                    Repeater {
                        model: root.entries

                        Frame {
                            onRestored: root.screenState.clipboardHistory = false
                        }
                    }
                }
            }

            Perforation {
                Layout.fillWidth: true
            }
        }
    }

    // A row of small evenly-spaced circles, the film-strip sprocket holes.
    component Perforation: Item {
        implicitHeight: 6

        Row {
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: Math.max(0, Math.floor(parent.parent.width / 16))

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Colours.palette.m3outlineVariant
                }
            }
        }
    }
}
