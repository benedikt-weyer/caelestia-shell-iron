import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property Toplevel client

    anchors.fill: parent
    spacing: Tokens.spacing.small

    Label {
        Layout.topMargin: Tokens.padding.extraLargeIncreased

        text: root.client?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    Label {
        text: root.client?.appId ?? qsTr("No active client")
        color: Colours.palette.m3tertiary

        font: Tokens.font.body.large
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Tokens.padding.extraLargeIncreased
        Layout.rightMargin: Tokens.padding.extraLargeIncreased
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.largeIncreased

        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "desktop_windows"
        text: {
            const screens = root.client?.screens ?? [];
            return screens.length > 0 ? qsTr("Monitor: %1").arg(screens.map(s => s.name).join(", ")) : qsTr("Monitor: unknown");
        }
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "fullscreen"
        text: qsTr("Fullscreen: %1").arg(root.client?.fullscreen ? "yes" : "no")
        color: Colours.palette.m3tertiary
    }

    Detail {
        icon: "check_box_outline_blank"
        text: qsTr("Maximised: %1").arg(root.client?.maximized ? "yes" : "no")
        color: Colours.palette.m3secondary
    }

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true

        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font: Tokens.font.body.medium
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}
