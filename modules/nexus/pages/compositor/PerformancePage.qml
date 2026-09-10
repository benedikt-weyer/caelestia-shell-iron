import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var cfg: IronlandCtl.config
    readonly property list<MenuItem> positionItems: [
        MenuItem {
            text: qsTr("Top left")
        },
        MenuItem {
            text: qsTr("Top right")
        },
        MenuItem {
            text: qsTr("Bottom left")
        },
        MenuItem {
            text: qsTr("Bottom right")
        }
    ]
    readonly property var positionValues: ["top_left", "top_right", "bottom_left", "bottom_right"]

    title: qsTr("Performance")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        CompositorError {}

        SectionHeader {
            first: true
            text: qsTr("FPS overlay")
        }

        ToggleRow {
            first: true
            text: qsTr("Show FPS overlay")
            subtext: qsTr("Frame rate, last frame time, and a stutter counter drawn on every output")
            checked: root.cfg?.performance.fps_overlay ?? false
            onToggled: IronlandCtl.setValue("performance.fps_overlay", checked ? "true" : "false")
        }

        SelectRow {
            last: true
            label: qsTr("Position")
            menuItems: root.positionItems
            active: root.positionItems[Math.max(0, root.positionValues.indexOf(root.cfg?.performance.fps_overlay_position ?? "top_right"))]
            onSelected: item => IronlandCtl.setValue("performance.fps_overlay_position", root.positionValues[root.positionItems.indexOf(item)])
        }

        SectionHeader {
            text: qsTr("Stutter analytics")
        }

        TextFieldRow {
            first: true
            label: qsTr("Stutter threshold")
            subtext: qsTr("Frame time (ms) above which a frame counts as a stutter; empty/0 picks 1.5× the output's refresh interval automatically")
            value: (root.cfg?.performance.stutter_threshold_ms ?? 0) > 0 ? String(root.cfg.performance.stutter_threshold_ms) : ""
            validator: DoubleValidator {
                bottom: 0
            }
            onEditingFinished: v => IronlandCtl.setValue("performance.stutter_threshold_ms", v || "0")
        }

        ToggleRow {
            last: true
            text: qsTr("Log stutters")
            subtext: qsTr("Also report each detected stutter via the compositor's log (journalctl --user, or the terminal under `run`)")
            checked: root.cfg?.performance.stutter_log ?? true
            onToggled: IronlandCtl.setValue("performance.stutter_log", checked ? "true" : "false")
        }
    }
}
