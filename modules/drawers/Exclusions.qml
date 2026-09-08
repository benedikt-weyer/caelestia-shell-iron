pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar
    required property real dockHeight

    ExclusionZone {
        anchors.left: true
        exclusiveZone: root.bar.exclusiveZone
    }

    ExclusionZone {
        anchors.top: true
    }

    ExclusionZone {
        anchors.right: true
    }

    ExclusionZone {
        anchors.bottom: true
        // The dock (see modules/dock) is its own real layer-shell surface
        // rather than an item drawn inside this one, but it doesn't reserve
        // its own exclusive zone (see its exclusionMode) - so this is the
        // only thing reserving space for it, same as the bar on the left.
        // Without this, both it and the dock reserving space on the same
        // edge would stack, leaving the dock's surface (and the border shape
        // drawn around it) sized correctly but positioned short of the
        // actual screen edge.
        exclusiveZone: root.dockHeight
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        // Matches the border decoration itself (see ContentWindow's
        // borderThickness), which shrinks to nothing on fullscreen - without
        // this, the reservation would outlive the border it's reserving
        // space for, leaving a dead strip where nothing is drawn.
        exclusiveZone: root.bar.fullscreen ? 0 : contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
