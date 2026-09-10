pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.Wayland
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var entries: [...permissions.entries].sort((a, b) => a.subject.localeCompare(b.subject))

    title: qsTr("Screen Capture")
    isSubPage: true

    // qmllint disable unresolved-type
    IronlandCapturePermissions {
        // qmllint enable unresolved-type
        id: permissions
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: qsTr("Every program that has asked to capture the screen, identified by its executable path. Allowed programs capture silently; denied ones fail without asking again. Forget a decision to be asked again next time. This list only lasts until the compositor restarts.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            first: true
            text: qsTr("Programs")
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.entries.length === 0
            text: qsTr("No program has asked to capture the screen yet.")
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        Repeater {
            id: entryRows

            model: root.entries

            CaptureGrantRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === entryRows.count - 1
                subject: modelData.subject
                allowed: modelData.allowed
                onToggled: allowed => permissions.setGrant(modelData.subject, allowed)
                onForget: permissions.forget(modelData.subject)
            }
        }
    }

    component CaptureGrantRow: ConnectedRect {
        id: rowRoot

        required property string subject
        required property bool allowed
        property alias first: rowRoot.first
        property alias last: rowRoot.last

        signal toggled(allowed: bool)
        signal forget

        Layout.fillWidth: true
        implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.largeIncreased

            spacing: Tokens.spacing.medium

            Column {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right

                    text: rowRoot.subject.split("/").pop()
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.right: parent.right

                    text: rowRoot.subject
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideMiddle
                }
            }

            IconButton {
                icon: "delete"
                type: IconButton.Text
                font: Tokens.font.icon.medium
                onClicked: rowRoot.forget()
            }

            StyledSwitch {
                checked: rowRoot.allowed
                onToggled: rowRoot.toggled(checked)
            }
        }
    }
}
