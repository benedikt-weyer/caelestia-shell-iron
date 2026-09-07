import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var cfg: IronlandCtl.config

    title: qsTr("Focus")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        CompositorError {}

        ToggleRow {
            first: true
            text: qsTr("Focus follows mouse")
            subtext: qsTr("Focus whatever window the pointer is over, without needing a click")
            checked: root.cfg?.focus.follows_mouse ?? false
            onToggled: IronlandCtl.setValue("focus.follows_mouse", checked ? "true" : "false")
        }

        ToggleRow {
            last: true
            text: qsTr("Mouse follows focus")
            subtext: qsTr("Warp the pointer to a window whenever it's focused some other way (switching workspaces, cycling windows, a new window, the dock)")
            checked: root.cfg?.focus.mouse_follows_focus ?? false
            onToggled: IronlandCtl.setValue("focus.mouse_follows_focus", checked ? "true" : "false")
        }
    }
}
