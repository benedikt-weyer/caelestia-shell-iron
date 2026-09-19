pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property bool running: NixBackend.running
    readonly property bool failed: !root.running && NixBackend.phase === NixBackend.phaseFailed
    readonly property string lastUpdatedText: {
        if (!NixBackend.flakeHasGitHistory)
            return qsTr("No git history found for this flake");
        const date = new Date(NixBackend.flakeLastModified);
        if (isNaN(date.getTime()))
            return qsTr("Last updated: unknown");
        return qsTr("Last updated %1").arg(date.toLocaleString(Qt.locale(), Locale.ShortFormat));
    }

    implicitWidth: layout.implicitWidth > 800 ? layout.implicitWidth : 840
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Column {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: qsTr("System flake")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: root.lastUpdatedText
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.medium
                onClicked: NixBackend.refreshFlakeStatus()
            }
        }

        RowLayout {
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            IconTextButton {
                Layout.fillWidth: true
                icon: "cloud_download"
                text: qsTr("Update flake")
                type: IconTextButton.Tonal
                disabled: root.running
                onClicked: NixBackend.updateFlake()
            }

            IconTextButton {
                Layout.fillWidth: true
                icon: "sync"
                text: qsTr("Rebuild: switch")
                type: IconTextButton.Tonal
                disabled: root.running
                onClicked: NixBackend.rebuild(NixBackend.modeSwitch)
            }

            IconTextButton {
                Layout.fillWidth: true
                icon: "restart_alt"
                text: qsTr("Rebuild: boot")
                type: IconTextButton.Tonal
                disabled: root.running
                onClicked: NixBackend.rebuild(NixBackend.modeBoot)
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            implicitHeight: statusColumn.implicitHeight + Tokens.padding.medium * 2

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: statusColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        visible: !root.running
                        text: root.failed ? "error" : "check_circle"
                        color: root.failed ? Colours.palette.m3error : Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.medium
                    }

                    LoadingIndicator {
                        visible: root.running
                        animated: true
                        implicitWidth: 20
                        implicitHeight: 20
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const label = NixBackend.phaseLabel(NixBackend.phase);
                            return NixBackend.statusMessage ? `${label}: ${NixBackend.statusMessage}` : label;
                        }
                        color: root.failed ? Colours.palette.m3error : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    IconButton {
                        visible: root.failed
                        icon: copyTimer.running ? "inventory" : "content_copy"
                        type: IconButton.Text
                        isRound: true
                        font: Tokens.font.icon.medium
                        onClicked: {
                            Quickshell.clipboardText = NixBackend.errorText();
                            copyTimer.restart();
                        }

                        Timer {
                            id: copyTimer

                            interval: 2000
                        }
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    indeterminate: root.running && NixBackend.fractionDone < 0
                    value: NixBackend.fractionDone >= 0 ? NixBackend.fractionDone : 0
                    fgColour: root.failed ? Colours.palette.m3error : Colours.palette.m3primary
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            Layout.bottomMargin: Tokens.padding.large
            Layout.preferredHeight: 260

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            VerticalFadeListView {
                id: logView

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium

                clip: true
                spacing: Tokens.spacing.extraSmall / 2
                model: NixBackend.log

                onCountChanged: positionViewAtEnd()

                delegate: StyledText {
                    id: logLine

                    required property string message
                    required property bool isError

                    width: ListView.view ? ListView.view.width : implicitWidth

                    text: logLine.message
                    wrapMode: Text.Wrap
                    font: Tokens.font.mono.small
                    color: logLine.isError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: logView.count === 0
                    text: qsTr("Output from an update or rebuild appears here")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }
        }
    }
}
