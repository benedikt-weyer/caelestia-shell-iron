pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

// One clipboard-history entry. Clicking its body restores it to the system
// clipboard and closes the overlay; its own remove button only removes that
// one entry.
StyledRect {
    id: root

    required property var modelData

    signal restored

    implicitWidth: 160
    implicitHeight: 96
    radius: Tokens.rounding.medium
    color: mouse.containsMouse ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) : Colours.tPalette.m3surfaceContainerHigh
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ClipboardHistory.restore(root.modelData.id);
            root.restored();
        }
    }

    Image {
        anchors.fill: parent
        anchors.margins: 1 // Stay inside root's border

        visible: root.modelData.thumbnail.length > 0
        source: root.modelData.thumbnail
        fillMode: Image.PreserveAspectCrop
        asynchronous: true

        layer.enabled: true
        layer.effect: Mask {
            maskSource: mask
        }

        StyledRect {
            id: mask

            anchors.fill: parent
            layer.enabled: true
            visible: false
            radius: root.radius
        }
    }

    StyledText {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        anchors.topMargin: Tokens.padding.small + 18

        visible: root.modelData.thumbnail.length === 0
        text: root.modelData.preview
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.small
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: 4
        clip: true
    }

    IconButton {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.extraSmall
        isRound: true
        icon: "close"
        padding: Tokens.padding.extraSmall / 2
        font: Tokens.font.icon.small
        onClicked: ClipboardHistory.remove(root.modelData.id)
    }
}
