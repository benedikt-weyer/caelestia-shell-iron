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
            text: qsTr("Gaps")
        }

        StepperRow {
            first: true
            label: qsTr("Gap between windows")
            value: root.cfg?.gaps.inner ?? 8
            from: 0
            to: 64
            stepSize: 1
            onMoved: v => IronlandCtl.setValue("gaps.inner", String(v))
        }

        StepperRow {
            last: true
            label: qsTr("Gap to screen edge")
            value: root.cfg?.gaps.outer ?? 0
            from: 0
            to: 64
            stepSize: 1
            onMoved: v => IronlandCtl.setValue("gaps.outer", String(v))
        }

        SectionHeader {
            text: qsTr("Focus border")
        }

        ToggleRow {
            first: true
            text: qsTr("Highlight the focused window")
            checked: root.cfg?.border.enabled ?? false
            onToggled: IronlandCtl.setValue("border.enabled", checked ? "true" : "false")
        }

        StepperRow {
            label: qsTr("Border thickness")
            value: root.cfg?.border.thickness ?? 2
            from: 1
            to: 32
            stepSize: 1
            onMoved: v => IronlandCtl.setValue("border.thickness", String(v))
        }

        TextFieldRow {
            label: qsTr("Colour")
            subtext: qsTr("#rrggbb or #rrggbbaa")
            value: root.cfg?.border.color ?? "#89b4fa"
            onEditingFinished: v => IronlandCtl.setValue("border.color", v)
        }

        TextFieldRow {
            label: qsTr("Gradient colour")
            subtext: qsTr("Empty = solid colour")
            value: root.cfg?.border.gradient_color ?? ""
            onEditingFinished: v => v ? IronlandCtl.setValue("border.gradient_color", v) : IronlandCtl.unsetValue("border.gradient_color")
        }

        StepperRow {
            last: true
            label: qsTr("Gradient angle")
            value: root.cfg?.border.angle ?? 45
            from: 0
            to: 360
            stepSize: 5
            onMoved: v => IronlandCtl.setValue("border.angle", String(v))
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
