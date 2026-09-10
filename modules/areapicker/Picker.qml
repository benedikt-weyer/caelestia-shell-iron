pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia
import qs.components
import qs.components.effects
import qs.services

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property bool onClient

    readonly property real dragThreshold: 6

    // Was synced live from Hyprland's own border config for visual parity
    // when snapped to a window rect - both that sync and the snap itself
    // (see `clients`/`checkClientRects` below) needed per-window on-screen
    // geometry, which no generic Wayland protocol exposes to a client (by
    // design - see the port notes). Fixed values now.
    property real realBorderWidth: 2
    property real realRounding: 0

    property real ssx
    property real ssy
    // Whether the current press has moved far enough to count as a drag
    // (a manual rectangle selection) rather than a plain click, which
    // instead captures the whole display - see `onReleased`/`captureWhole`.
    property bool dragged

    property real sx: 0
    property real sy: 0
    property real ex: screen.width
    property real ey: screen.height

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    // Click-to-select-a-window needed each window's on-screen position/size,
    // which (unlike Hyprland's IPC) no generic Wayland protocol exposes to
    // a client - by design, not an oversight of ironland-compositor's (see
    // the port notes). Manual rectangle selection (drag) still works;
    // there's just nothing to snap to anymore.
    property list<var> clients: []

    function checkClientRects(x: real, y: real): void {}

    // A plain click (no drag) captures the whole display instead of
    // whatever the last/default selection rectangle happened to be.
    function captureWhole(): void {
        sx = 0;
        sy = 0;
        ex = screen.width;
        ey = screen.height;
    }

    function proceed(): void {
        if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
        }
    }

    function save(): void {
        const tmpfile = Qt.resolvedUrl(`/tmp/caelestia-picker-${Quickshell.processId}-${Date.now()}.png`);
        CUtils.saveItem(screencopy, tmpfile, Qt.rect(Math.ceil(rsx), Math.ceil(rsy), Math.floor(sw), Math.floor(sh)), path => {
            if (root.loader.clipboardOnly) {
                Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + path]);
                Quickshell.execDetached(["notify-send", "-a", "caelestia-cli", "-i", path, "Screenshot taken", "Screenshot copied to clipboard"]);
            } else {
                Quickshell.execDetached(["swappy", "-f", path]);
            }
            closeAnim.start();
        });
    }

    onClientsChanged: checkClientRects(mouseX, mouseY)

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.CrossCursor

    Component.onCompleted: {
        // Break binding if frozen
        if (loader.freeze)
            clients = clients;

        opacity = 1;

        // No window rect to default to anymore (see `clients` above) -
        // always starts centred.
        sx = screen.width / 2 - 100;
        sy = screen.height / 2 - 100;
        ex = screen.width / 2 + 100;
        ey = screen.height / 2 + 100;
    }

    onPressed: event => {
        ssx = event.x;
        ssy = event.y;
        dragged = false;
    }

    onReleased: {
        if (closeAnim.running)
            return;

        if (!dragged)
            captureWhole();

        proceed();
    }

    onPositionChanged: event => {
        const x = event.x;
        const y = event.y;

        if (pressed) {
            onClient = false;
            if (!dragged && Math.hypot(x - ssx, y - ssy) > dragThreshold)
                dragged = true;
            sx = ssx;
            sy = ssy;
            ex = x;
            ey = y;
        } else {
            checkClientRects(x, y);
        }
    }

    focus: true
    Keys.onEscapePressed: closeAnim.start()
    Keys.onReturnPressed: {
        captureWhole();
        proceed();
    }
    Keys.onEnterPressed: {
        captureWhole();
        proceed();
    }

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            Anim {
                target: root
                properties: "rsx,rsy"
                to: 0
            }
            Anim {
                target: root
                property: "sw"
                to: root.screen.width
            }
            Anim {
                target: root
                property: "sh"
                to: root.screen.height
            }
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    Loader {
        id: screencopy

        asynchronous: true
        anchors.fill: parent

        active: root.loader.freeze

        sourceComponent: ScreencopyView {
            captureSource: root.screen

            onHasContentChanged: {
                if (hasContent && !root.loader.freeze) {
                    overlay.visible = border.visible = true;
                    root.save();
                }
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: Mask {
            maskSource: selectionWrapper
            maskInverted: true
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        id: border

        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    StyledRect {
        id: hint

        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        implicitWidth: hintText.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: hintText.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh
        opacity: root.dragged ? 0 : 0.9

        Behavior on opacity {
            Anim {}
        }

        StyledText {
            id: hintText

            anchors.centerIn: parent
            text: "Click for full screen · drag to select an area · Esc to cancel"
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.small
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Behavior on rsx {
        enabled: !root.pressed

        Anim {}
    }

    Behavior on rsy {
        enabled: !root.pressed

        Anim {}
    }

    Behavior on sw {
        enabled: !root.pressed

        Anim {}
    }

    Behavior on sh {
        enabled: !root.pressed

        Anim {}
    }
}
