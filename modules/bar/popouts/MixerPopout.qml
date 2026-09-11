pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    // layout's width is pinned to Tokens.sizes.bar.mixerWidth rather than
    // sized from its content, so root must size off that actual width, not
    // layout.implicitWidth (which reflects the narrower content and cut the
    // popout off on the right).
    implicitWidth: layout.width + Tokens.padding.medium * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium
        width: Tokens.sizes.bar.mixerWidth

        StyledText {
            text: qsTr("Output apps")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        StyledText {
            visible: Audio.outputStreams.length === 0
            Layout.preferredHeight: visible ? implicitHeight : 0
            text: qsTr("No apps playing audio")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: Audio.outputStreams

            StreamRow {
                required property PwNode modelData

                stream: modelData
                icon: Icons.getVolumeIcon(Audio.getStreamVolume(modelData), Audio.getStreamMuted(modelData))
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Input apps")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        StyledText {
            visible: Audio.inputStreams.length === 0
            Layout.preferredHeight: visible ? implicitHeight : 0
            text: qsTr("No apps using the microphone")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: Audio.inputStreams

            StreamRow {
                required property PwNode modelData

                stream: modelData
                icon: Icons.getMicVolumeIcon(Audio.getStreamVolume(modelData), Audio.getStreamMuted(modelData))
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: qsTr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }

    component StreamRow: ColumnLayout {
        id: streamRow

        required property PwNode stream
        required property string icon

        Layout.fillWidth: true
        spacing: Tokens.spacing.small / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: streamRow.icon
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: Audio.getStreamName(streamRow.stream)
                elide: Text.ElideRight
            }

            StyledText {
                text: `${Math.round(Audio.getStreamVolume(streamRow.stream) * 100)}%`
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 2

            onWheel: event => {
                const step = GlobalConfig.services.audioIncrement;
                const volume = Audio.getStreamVolume(streamRow.stream);
                if (event.angleDelta.y > 0)
                    Audio.setStreamVolume(streamRow.stream, volume + step);
                else if (event.angleDelta.y < 0)
                    Audio.setStreamVolume(streamRow.stream, volume - step);
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.implicitHeight

                value: Audio.getStreamVolume(streamRow.stream)
                enabled: !Audio.getStreamMuted(streamRow.stream)
                onInteraction: v => Audio.setStreamVolume(streamRow.stream, v)
            }
        }
    }
}
