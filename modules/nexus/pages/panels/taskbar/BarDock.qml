pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    // Dock scopes, ordered to match config::DockScope (Monitor, SharedWorkspace, Global)
    readonly property list<MenuItem> scopeItems: [
        MenuItem {
            text: qsTr("Monitor")
        },
        MenuItem {
            text: qsTr("Shared workspace")
        },
        MenuItem {
            text: qsTr("Global")
        }
    ]

    title: qsTr("Dock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            subtext: qsTr("Show a dock with icons for running apps at the bottom of the screen")
            checked: Config.dock.enabled
            onToggled: GlobalConfig.dock.enabled = checked
        }

        ToggleRow {
            text: qsTr("Background")
            subtext: qsTr("Show a background pill behind the dock icons")
            checked: Config.dock.showBackground
            onToggled: GlobalConfig.dock.showBackground = checked
        }

        StepperRow {
            label: qsTr("Icon size")
            subtext: qsTr("Size of the app icons in the dock")
            value: Config.dock.iconSize
            from: 16
            to: 64
            stepSize: 2
            onMoved: v => GlobalConfig.dock.iconSize = v
        }

        SelectRow {
            last: true
            label: qsTr("Scope")
            subtext: qsTr("Which running apps are shown in the dock")
            menuItems: root.scopeItems
            active: root.scopeItems[Config.dock.scope]
            onSelected: item => GlobalConfig.dock.scope = root.scopeItems.indexOf(item)
        }
    }
}
