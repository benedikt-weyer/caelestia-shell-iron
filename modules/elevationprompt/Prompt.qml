pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    // {promptId, appId, reason}, or null while nothing's pending.
    property var prompt
    readonly property bool shown: root.prompt !== null

    signal allow
    signal deny

    visible: opacity > 0
    opacity: shown ? 1 : 0
    focus: shown
    Keys.onReturnPressed: root.allow()
    Keys.onEnterPressed: root.allow()
    Keys.onEscapePressed: root.deny()

    Behavior on opacity {
        Anim {}
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.4
    }

    StyledRect {
        id: card

        anchors.centerIn: parent
        implicitWidth: 420
        implicitHeight: column.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh

        scale: root.shown ? 1 : 0.9

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Column {
            id: column

            anchors.centerIn: parent
            width: parent.implicitWidth - Tokens.padding.large * 2
            spacing: Tokens.spacing.medium

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "screenshot_monitor"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.large.build()
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.prompt ? `${root.prompt.appId || "An application"} wants to ${root.prompt.reason}` : ""
                font: Tokens.font.body.large
                color: Colours.palette.m3onSurface
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.medium

                TextButton {
                    text: "Deny"
                    type: TextButton.Tonal
                    activeColour: Colours.palette.m3errorContainer
                    inactiveColour: Colours.palette.m3errorContainer
                    activeOnColour: Colours.palette.m3onErrorContainer
                    inactiveOnColour: Colours.palette.m3onErrorContainer

                    onClicked: root.deny()
                }

                TextButton {
                    text: "Allow"
                    type: TextButton.Filled

                    onClicked: root.allow()

                    Component.onCompleted: forceActiveFocus()
                }
            }
        }
    }
}
