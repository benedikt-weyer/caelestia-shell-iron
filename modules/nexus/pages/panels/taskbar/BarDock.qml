pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

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
            last: true
            label: qsTr("Icon size")
            subtext: qsTr("Size of the app icons in the dock")
            value: Config.dock.iconSize
            from: 16
            to: 64
            stepSize: 2
            onMoved: v => GlobalConfig.dock.iconSize = v
        }
    }
}
