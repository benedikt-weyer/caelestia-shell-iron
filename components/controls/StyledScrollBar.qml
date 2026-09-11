import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

ScrollBar {
    id: root

    required property Flickable flickable
    // True when attached via ScrollBar.horizontal (orientation is set
    // automatically by that attached property).
    readonly property bool isHorizontal: orientation === Qt.Horizontal
    property bool shouldBeActive
    property real nonAnimPosition
    property bool animating
    property bool _updatingFromFlickable: false
    property bool _updatingFromUser: false

    // Extent (contentWidth/contentHeight) and viewport size (width/height)
    // along the bar's own axis, and the flickable's current position on
    // that axis - shared by every place below that maps between flickable
    // content position and a [0, 1] bar position.
    function extent(): real {
        return isHorizontal ? flickable.contentWidth : flickable.contentHeight;
    }

    function viewSize(): real {
        return isHorizontal ? flickable.width : flickable.height;
    }

    function contentPos(): real {
        return isHorizontal ? flickable.contentX : flickable.contentY;
    }

    function setContentPos(pos: real): void {
        if (isHorizontal)
            flickable.contentX = pos;
        else
            flickable.contentY = pos;
    }

    // Maps a [0, 1-size] bar position to a flickable content position and
    // applies it - used by both wheel and drag handling below.
    function applyPosition(newPos: real): void {
        const e = extent();
        const v = viewSize();
        if (e > v) {
            const maxContentPos = e - v;
            const maxPos = 1 - size;
            const pos = maxPos > 0 ? (newPos / maxPos) * maxContentPos : 0;
            setContentPos(Math.max(0, Math.min(maxContentPos, pos)));
        }
    }

    // Sync nonAnimPosition with the flickable when not animating.
    function syncFromFlickable(): void {
        if (!animating && !fullMouse.pressed) {
            _updatingFromFlickable = true;
            const e = extent();
            const v = viewSize();
            nonAnimPosition = e > v ? Math.max(0, Math.min(1, contentPos() / (e - v))) : 0;
            _updatingFromFlickable = false;
        }
    }

    onHoveredChanged: {
        if (hovered)
            shouldBeActive = true;
        else
            shouldBeActive = flickable.moving;
    }

    // Sync nonAnimPosition with Qt's automatic position binding
    onPositionChanged: {
        if (_updatingFromUser) {
            _updatingFromUser = false;
            return;
        }
        if (position === nonAnimPosition) {
            animating = false;
            return;
        }
        if (!animating && !_updatingFromFlickable && !fullMouse.pressed) {
            nonAnimPosition = position;
        }
    }

    Component.onCompleted: {
        if (flickable)
            syncFromFlickable();
    }
    implicitWidth: isHorizontal ? 0 : Tokens.padding.extraSmall
    implicitHeight: isHorizontal ? Tokens.padding.extraSmall : 0

    contentItem: StyledRect {
        anchors.left: root.isHorizontal ? undefined : parent.left
        anchors.right: root.isHorizontal ? undefined : parent.right
        anchors.top: root.isHorizontal ? parent.top : undefined
        anchors.bottom: root.isHorizontal ? parent.bottom : undefined
        opacity: {
            if (root.size === 1)
                return 0;
            if (fullMouse.pressed)
                return 1;
            if (mouse.containsMouse)
                return 0.8;
            if (root.policy === ScrollBar.AlwaysOn || root.shouldBeActive)
                return 0.6;
            return 0;
        }
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondary

        MouseArea {
            id: mouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // Sync nonAnimPosition with flickable when not animating
    Connections {
        function onContentXChanged() {
            root.syncFromFlickable();
        }
        function onContentYChanged() {
            root.syncFromFlickable();
        }

        target: root.flickable
    }

    Connections {
        function onMovingChanged(): void {
            if (root.flickable.moving)
                root.shouldBeActive = true;
            else
                hideDelay.restart();
        }

        target: root.flickable
    }

    Timer {
        id: hideDelay

        interval: 600
        onTriggered: root.shouldBeActive = root.flickable.moving || root.hovered
    }

    CustomMouseArea {
        id: fullMouse

        function onWheel(event: WheelEvent): void {
            root.animating = true;
            root._updatingFromUser = true;
            let newPos = root.nonAnimPosition;
            if (event.angleDelta.y > 0)
                newPos = Math.max(0, root.nonAnimPosition - 0.1);
            else if (event.angleDelta.y < 0)
                newPos = Math.min(1 - root.size, root.nonAnimPosition + 0.1);
            root.nonAnimPosition = newPos;
            root.applyPosition(newPos);
        }

        anchors.fill: parent
        preventStealing: true

        onPressed: event => {
            root.animating = true;
            root._updatingFromUser = true;
            const coord = root.isHorizontal ? event.x : event.y;
            const extent = root.isHorizontal ? root.width : root.height;
            const newPos = Math.max(0, Math.min(1 - root.size, coord / extent - root.size / 2));
            root.nonAnimPosition = newPos;
            root.applyPosition(newPos);
        }

        onPositionChanged: event => {
            root._updatingFromUser = true;
            const coord = root.isHorizontal ? event.x : event.y;
            const extent = root.isHorizontal ? root.width : root.height;
            const newPos = Math.max(0, Math.min(1 - root.size, coord / extent - root.size / 2));
            root.nonAnimPosition = newPos;
            root.applyPosition(newPos);
        }
    }

    Behavior on position {
        enabled: !fullMouse.pressed

        Anim {}
    }
}
