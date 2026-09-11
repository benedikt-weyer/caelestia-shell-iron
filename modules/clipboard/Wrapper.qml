pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

// Slides the clipboard-history overlay (Content.qml) down from the top of
// the screen when `screenState.clipboardHistory` is set (toggled by the
// Super+V shortcut in modules/Shortcuts.qml) - mirrors
// qs.modules.dashboard's Wrapper.qml, which uses the same offsetScale/
// Loader pattern.
Item {
    id: root

    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.clipboardHistory
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 640
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
        }
    }
}
