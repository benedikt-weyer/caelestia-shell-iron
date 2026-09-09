pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

// A miniature, to-scale drag-and-drop map of the currently connected
// monitors (their real detected x/y/width/height from `detectOutputs`),
// so a multi-monitor layout can be arranged visually instead of only
// through the relative "right of X" pickers. Dragging snaps a tile's
// edges to its neighbours', and on release reports the tile's new
// logical position for the caller to persist via `IronlandCtl.outputsSet`
// (as an explicit `--x`/`--y`, the same "at position" mode the manual
// fields already use).
ConnectedRect {
    id: root

    required property var monitors // [{name, x, y, width, height}, ...] in logical pixels
    property string primaryName
    readonly property int stagePadding: Tokens.padding.large
    readonly property int stageHeight: 220
    readonly property int snapThreshold: 10
    readonly property real boundsMinX: root.monitors.length ? Math.min(...root.monitors.map(m => m.x)) : 0
    readonly property real boundsMinY: root.monitors.length ? Math.min(...root.monitors.map(m => m.y)) : 0
    readonly property real boundsWidth: root.monitors.length ? Math.max(1, Math.max(...root.monitors.map(m => m.x + m.width)) - root.boundsMinX) : 1
    readonly property real boundsHeight: root.monitors.length ? Math.max(1, Math.max(...root.monitors.map(m => m.y + m.height)) - root.boundsMinY) : 1
    readonly property real availWidth: Math.max(1, root.width - root.stagePadding * 2)
    readonly property real availHeight: Math.max(1, root.stageHeight - root.stagePadding * 2)
    readonly property real mapScale: Math.min(root.availWidth / root.boundsWidth, root.availHeight / root.boundsHeight)
    readonly property real offsetX: root.stagePadding + (root.availWidth - root.boundsWidth * root.mapScale) / 2 - root.boundsMinX * root.mapScale
    readonly property real offsetY: root.stagePadding + (root.availHeight - root.boundsHeight * root.mapScale) / 2 - root.boundsMinY * root.mapScale

    signal placed(name: string, x: int, y: int)

    first: true
    last: true
    implicitHeight: root.stageHeight

    Repeater {
        id: rep

        model: root.monitors

        Tile {
            required property var modelData
            required property int index
        }
    }

    component Tile: Rectangle {
        id: tile

        required property var modelData
        required property int index
        property bool dragging
        property real grabOffsetX
        property real grabOffsetY

        radius: Tokens.rounding.small
        border.width: tile.dragging ? 2 : 1
        border.color: tile.modelData.name === root.primaryName ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        color: Qt.alpha(Colours.palette.m3primary, tile.dragging ? 0.35 : 0.16)
        z: tile.dragging ? 2 : 0
        x: tile.modelData.x * root.mapScale + root.offsetX
        y: tile.modelData.y * root.mapScale + root.offsetY
        width: Math.max(1, tile.modelData.width * root.mapScale)
        height: Math.max(1, tile.modelData.height * root.mapScale)

        Behavior on x {
            enabled: !tile.dragging

            Anim {}
        }

        Behavior on y {
            enabled: !tile.dragging

            Anim {}
        }

        StyledText {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Tokens.padding.small * 2)
            text: tile.modelData.name
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: e => {
                tile.dragging = true;
                tile.grabOffsetX = e.x;
                tile.grabOffsetY = e.y;
            }

            onPositionChanged: e => {
                if (!tile.dragging)
                    return;

                const abs = tile.mapToItem(root, e.x, e.y);
                let nx = abs.x - tile.grabOffsetX;
                let ny = abs.y - tile.grabOffsetY;

                let snappedX = null;
                let snappedY = null;
                for (let i = 0; i < rep.count; i++) {
                    if (i === tile.index)
                        continue;
                    const other = rep.itemAt(i);
                    if (!other)
                        continue;

                    if (snappedX === null) {
                        if (Math.abs(nx - (other.x + other.width)) < root.snapThreshold)
                            snappedX = other.x + other.width;
                        else if (Math.abs((nx + tile.width) - other.x) < root.snapThreshold)
                            snappedX = other.x - tile.width;
                        else if (Math.abs(nx - other.x) < root.snapThreshold)
                            snappedX = other.x;
                        else if (Math.abs((nx + tile.width) - (other.x + other.width)) < root.snapThreshold)
                            snappedX = other.x + other.width - tile.width;
                    }
                    if (snappedY === null) {
                        if (Math.abs(ny - (other.y + other.height)) < root.snapThreshold)
                            snappedY = other.y + other.height;
                        else if (Math.abs((ny + tile.height) - other.y) < root.snapThreshold)
                            snappedY = other.y - tile.height;
                        else if (Math.abs(ny - other.y) < root.snapThreshold)
                            snappedY = other.y;
                        else if (Math.abs((ny + tile.height) - (other.y + other.height)) < root.snapThreshold)
                            snappedY = other.y + other.height - tile.height;
                    }
                }

                tile.x = snappedX ?? nx;
                tile.y = snappedY ?? ny;
            }

            onReleased: {
                tile.dragging = false;
                root.placed(tile.modelData.name, Math.round((tile.x - root.offsetX) / root.mapScale), Math.round((tile.y - root.offsetY) / root.mapScale));
            }
        }
    }
}
