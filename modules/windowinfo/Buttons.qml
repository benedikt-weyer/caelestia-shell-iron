pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services

// Move-to-workspace/float/pin all dispatched by window address under
// Hyprland; ironland-copositor's tiling model has no per-window address to
// target and no protocol for any of the three (see the port notes), so
// only Kill (a plain wlr-foreign-toplevel-management-v1 `close`) survives.
ColumnLayout {
    id: root

    required property Toplevel client

    anchors.fill: parent
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.large
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.large

        Button {
            color: Colours.palette.m3errorContainer
            onColor: Colours.palette.m3onErrorContainer
            text: qsTr("Kill")
            onClicked: root.client?.close()
        }
    }

    component Button: StyledRect {
        property color onColor: Colours.palette.m3onSurface
        property alias disabled: stateLayer.disabled
        property alias text: label.text

        signal clicked

        radius: Tokens.rounding.medium

        Layout.fillWidth: true
        implicitHeight: label.implicitHeight + Tokens.padding.small

        StateLayer {
            id: stateLayer

            color: parent.onColor
            onClicked: parent.clicked()
        }

        StyledText {
            id: label

            anchors.centerIn: parent

            animate: true
            color: parent.onColor
            font: Tokens.font.body.medium
        }
    }
}
