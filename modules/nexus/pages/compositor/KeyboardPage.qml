import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var cfg: IronlandCtl.config

    title: qsTr("Keyboard")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        CompositorError {}

        SectionHeader {
            first: true
            text: qsTr("Layout")
        }

        TextFieldRow {
            first: true
            label: qsTr("Layout")
            subtext: qsTr("e.g. us, de, gb (empty = system default)")
            value: root.cfg?.keyboard.layout ?? ""
            onEditingFinished: v => IronlandCtl.setValue("keyboard.layout", v)
        }

        TextFieldRow {
            label: qsTr("Variant")
            subtext: qsTr("e.g. nodeadkeys, dvorak (optional)")
            value: root.cfg?.keyboard.variant ?? ""
            onEditingFinished: v => IronlandCtl.setValue("keyboard.variant", v)
        }

        TextFieldRow {
            label: qsTr("Model")
            subtext: qsTr("e.g. pc105 (optional)")
            value: root.cfg?.keyboard.model ?? ""
            onEditingFinished: v => IronlandCtl.setValue("keyboard.model", v)
        }

        TextFieldRow {
            label: qsTr("Options")
            subtext: qsTr("e.g. caps:swapescape (optional)")
            value: root.cfg?.keyboard.options ?? ""
            onEditingFinished: v => IronlandCtl.setValue("keyboard.options", v)
        }

        TextFieldRow {
            last: true
            label: qsTr("Rules")
            subtext: qsTr("advanced: xkb rules file (usually leave empty)")
            value: root.cfg?.keyboard.rules ?? ""
            onEditingFinished: v => IronlandCtl.setValue("keyboard.rules", v)
        }

        SectionHeader {
            text: qsTr("Default apps")
        }

        TextFieldRow {
            first: true
            label: qsTr("Terminal command")
            subtext: qsTr("Run by the \"Open terminal\" shortcut")
            value: root.cfg?.terminal ?? ""
            onEditingFinished: v => IronlandCtl.setValue("terminal", v)
        }

        TextFieldRow {
            label: qsTr("Browser command")
            subtext: qsTr("Run by the \"Open browser\" shortcut")
            value: root.cfg?.browser ?? ""
            onEditingFinished: v => IronlandCtl.setValue("browser", v)
        }

        TextFieldRow {
            last: true
            label: qsTr("File manager command")
            subtext: qsTr("Run by the \"Open file manager\" shortcut")
            value: root.cfg?.file_manager ?? ""
            onEditingFinished: v => IronlandCtl.setValue("file_manager", v)
        }

        SectionHeader {
            text: qsTr("Window decoration")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Show top bar")
            subtext: qsTr("Compositor-drawn window header; off means no server-side decoration regardless of what a client requests")
            checked: root.cfg?.top_bar ?? false
            onToggled: IronlandCtl.setValue("top_bar", checked ? "true" : "false")
        }
    }
}
