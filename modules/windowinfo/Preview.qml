pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services

// Live window screenshots need `ext-image-copy-capture-v1` (or similar)
// linked to a toplevel handle, which ironland-compositor doesn't implement
// yet - see the port notes. Always shows the placeholder rather than a
// live preview until that lands.
Item {
    id: root

    required property ShellScreen screen
    required property Toplevel client

    Layout.preferredWidth: preview.implicitWidth + Tokens.padding.extraLargeIncreased
    Layout.fillHeight: true

    StyledClippingRect {
        id: preview

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: label.top
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.spacing.medium

        implicitWidth: placeholder.implicitWidth + Tokens.padding.extraLargeIncreased * 2

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        ColumnLayout {
            id: placeholder

            anchors.centerIn: parent
            spacing: 0

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: root.client ? "hide_image" : "web_asset_off"
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(3).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.client ? qsTr("No preview available") : qsTr("No active client")
                color: Colours.palette.m3outline
                font: Tokens.font.body.builders.large.size(28).weight(Font.Medium).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: text.length > 0
                text: root.client ? "" : qsTr("Try switching to a window")
                color: Colours.palette.m3outline
                font: Tokens.font.body.large
            }
        }
    }

    StyledText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.large

        animate: true
        text: {
            const client = root.client;
            if (!client)
                return qsTr("No active client");

            const screens = client.screens.map(s => s.name).join(", ");
            return screens.length > 0 ? qsTr("%1 on %2").arg(client.title).arg(screens) : client.title;
        }
    }
}
