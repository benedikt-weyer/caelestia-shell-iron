import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var cfg: IronlandCtl.config

    title: qsTr("Appearance")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        CompositorError {}

        SectionHeader {
            first: true
            text: qsTr("Colour scheme")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Dark mode")
            subtext: qsTr("Applies immediately (org.freedesktop.appearance colour-scheme, via gsettings)")
            checked: root.cfg?.appearance.dark_mode ?? false
            onToggled: IronlandCtl.setValue("appearance.dark_mode", checked ? "true" : "false")
        }

        SectionHeader {
            text: qsTr("Wallpaper")
        }

        TextFieldRow {
            first: true
            last: true
            label: qsTr("Wallpaper path")
            subtext: qsTr("PNG/JPEG/WebP, scaled and center-cropped; empty uses the built-in default")
            value: root.cfg?.wallpaper ?? ""
            onEditingFinished: v => v ? IronlandCtl.setValue("wallpaper", v) : IronlandCtl.unsetValue("wallpaper")
        }

        SectionHeader {
            text: qsTr("Blur")
        }

        ToggleRow {
            first: true
            text: qsTr("Blur behind translucent windows")
            checked: root.cfg?.blur.enabled ?? false
            onToggled: IronlandCtl.setValue("blur.enabled", checked ? "true" : "false")
        }

        StepperRow {
            last: true
            label: qsTr("Blur radius")
            value: root.cfg?.blur.radius ?? 12
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => IronlandCtl.setValue("blur.radius", String(v))
        }

        SectionHeader {
            text: qsTr("Rounded corners")
        }

        ToggleRow {
            first: true
            text: qsTr("Round window corners")
            checked: root.cfg?.corners.enabled ?? false
            onToggled: IronlandCtl.setValue("corners.enabled", checked ? "true" : "false")
        }

        StepperRow {
            last: true
            label: qsTr("Corner radius")
            value: root.cfg?.corners.radius ?? 12
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => IronlandCtl.setValue("corners.radius", String(v))
        }

        SectionHeader {
            text: qsTr("Cursor")
        }

        TextFieldRow {
            first: true
            label: qsTr("Cursor theme")
            subtext: qsTr("e.g. Adwaita, Bibata-Modern-Classic (empty = system default)")
            value: root.cfg?.cursor.theme ?? ""
            onEditingFinished: v => v ? IronlandCtl.setValue("cursor.theme", v) : IronlandCtl.unsetValue("cursor.theme")
        }

        TextFieldRow {
            last: true
            label: qsTr("Cursor size")
            subtext: qsTr("empty = system default (usually 24)")
            value: root.cfg?.cursor.size ? String(root.cfg.cursor.size) : ""
            validator: IntValidator {
                bottom: 1
            }
            onEditingFinished: v => v ? IronlandCtl.setValue("cursor.size", v) : IronlandCtl.unsetValue("cursor.size")
        }
    }
}
