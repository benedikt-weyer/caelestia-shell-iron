pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    readonly property var stats: NixBackend.stats ?? ({})
    readonly property list<var> displayItems: NixBackend.activeItems.slice(0, 8)
    readonly property real downloadRate: NixBackend.activeItems.filter(i => i.kind === "download" && i.status === "running").reduce((sum, i) => sum + (i.bytesPerSec ?? 0), 0)
    readonly property bool hasActivity: root.running && (NixBackend.activeItems.length > 0 || (root.stats.buildsExpected ?? 0) > 0 || (root.stats.copiesExpected ?? 0) > 0)

    function formatBytes(bytes: real): string {
        if (!bytes || bytes <= 0)
            return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        let v = bytes;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return `${v.toFixed(v < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
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
                            NixBackend.copyError();
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
            id: activityCard

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large

            visible: root.hasActivity
            clip: true
            implicitHeight: root.hasActivity ? activityColumn.implicitHeight + Tokens.padding.medium * 2 : 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            Behavior on implicitHeight {
                Anim {}
            }

            ColumnLayout {
                id: activityColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        visible: (root.stats.buildsExpected ?? 0) > 0
                        text: (root.stats.buildsRunning ?? 0) > 0 ? qsTr("Building %1/%2 (%3 running)").arg(root.stats.buildsDone ?? 0).arg(root.stats.buildsExpected ?? 0).arg(root.stats.buildsRunning) : qsTr("Built %1/%2").arg(root.stats.buildsDone ?? 0).arg(root.stats.buildsExpected ?? 0)
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        visible: (root.stats.copiesExpected ?? 0) > 0
                        text: {
                            const done = root.stats.copiesDone ?? 0;
                            const expected = root.stats.copiesExpected ?? 0;
                            const bytes = (root.stats.downloadBytesExpected ?? 0) > 0 ? ` (${root.formatBytes(root.stats.downloadBytesDone ?? 0)}/${root.formatBytes(root.stats.downloadBytesExpected)})` : "";
                            return qsTr("Downloading %1/%2%3").arg(done).arg(expected).arg(bytes);
                        }
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        visible: root.downloadRate > 0
                        text: qsTr("%1/s").arg(root.formatBytes(root.downloadRate))
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Repeater {
                    model: root.displayItems

                    delegate: RowLayout {
                        id: itemRow

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.extraSmall / 2
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: itemRow.modelData.kind === "download" ? "download" : "build"
                            fontStyle: Tokens.font.icon.small
                            color: itemRow.modelData.status === "done" ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: itemRow.modelData.name || qsTr("(unknown)")
                            elide: Text.ElideMiddle
                            font: Tokens.font.mono.small
                            color: itemRow.modelData.status === "done" ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                        }

                        StyledText {
                            visible: itemRow.modelData.kind === "download" && itemRow.modelData.bytesExpected > 0
                            text: `${root.formatBytes(itemRow.modelData.bytesDone)} / ${root.formatBytes(itemRow.modelData.bytesExpected)}`
                            font: Tokens.font.mono.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        MaterialIcon {
                            visible: itemRow.modelData.status === "done"
                            text: "check"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3primary
                        }

                        LoadingIndicator {
                            visible: itemRow.modelData.status === "running"
                            animated: true
                            implicitWidth: 14
                            implicitHeight: 14
                        }
                    }
                }
            }
        }

        StyledRect {
            id: consoleCard

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            Layout.bottomMargin: Tokens.padding.large

            property bool expanded: false

            clip: true
            implicitHeight: consoleColumn.implicitHeight + Tokens.padding.medium * 2

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            Behavior on implicitHeight {
                Anim {}
            }

            ColumnLayout {
                id: consoleColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                spacing: consoleCard.expanded ? Tokens.spacing.small : 0

                StyledRect {
                    id: consoleHeader

                    Layout.fillWidth: true
                    implicitHeight: consoleHeaderRow.implicitHeight

                    radius: Tokens.rounding.small
                    color: "transparent"

                    StateLayer {
                        radius: consoleHeader.radius
                        onClicked: consoleCard.expanded = !consoleCard.expanded
                    }

                    RowLayout {
                        id: consoleHeaderRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Console output")
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            visible: NixBackend.log.count > 0
                            text: NixBackend.log.count
                            font: Tokens.font.body.small
                            color: Colours.palette.m3outline
                        }

                        MaterialIcon {
                            text: "expand_more"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                            rotation: consoleCard.expanded ? 180 : 0

                            Behavior on rotation {
                                Anim {}
                            }
                        }
                    }
                }

                Item {
                    id: consoleBody

                    Layout.fillWidth: true
                    Layout.preferredHeight: consoleCard.expanded ? 260 : 0

                    clip: true
                    visible: height > 0

                    Behavior on Layout.preferredHeight {
                        Anim {}
                    }

                    VerticalFadeListView {
                        id: logView

                        property bool followBottom: true

                        anchors.fill: parent

                        clip: true
                        spacing: Tokens.spacing.extraSmall / 2
                        model: NixBackend.log

                        onCountChanged: if (followBottom)
                            positionViewAtEnd()
                        onVisibleChanged: if (visible && followBottom)
                            positionViewAtEnd()
                        onDragStarted: followBottom = false
                        onFlickStarted: followBottom = false
                        onAtYEndChanged: if (atYEnd)
                            followBottom = true

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

                    IconButton {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Tokens.padding.small

                        visible: logView.count > 0 && !logView.followBottom
                        opacity: visible ? 1 : 0

                        icon: "arrow_downward"
                        type: IconButton.Filled
                        isRound: true
                        font: Tokens.font.icon.small
                        onClicked: {
                            logView.followBottom = true;
                            logView.positionViewAtEnd();
                        }

                        Behavior on opacity {
                            Anim {}
                        }
                    }
                }
            }
        }
    }
}
