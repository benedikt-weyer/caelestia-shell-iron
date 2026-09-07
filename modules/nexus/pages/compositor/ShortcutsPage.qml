pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var cfg: IronlandCtl.config
    readonly property var knownActions: Object.keys(IronlandCtl.actionLabels)
    property var events: null // {configured: {name: [combos]}, suggested: [name...]}
    property string newEventName: ""

    function refreshEvents(): void {
        IronlandCtl.shortcutsEventsList(result => root.events = result);
    }

    function combosText(action: string): string {
        return (root.cfg?.shortcuts[action] ?? []).join(", ");
    }

    function commitAction(action: string, value: string): void {
        if (value.trim())
            IronlandCtl.shortcutsSet(action, value, () => {});
        else
            IronlandCtl.shortcutsUnset(action, () => {});
    }

    function commitEvent(name: string, value: string): void {
        if (value.trim())
            IronlandCtl.eventAdd(name, value, () => root.refreshEvents());
        else
            IronlandCtl.eventRemove(name, () => root.refreshEvents());
    }

    title: qsTr("Shortcuts")
    isSubPage: true

    Component.onCompleted: root.refreshEvents()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        CompositorError {}

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: qsTr("Separate multiple key combos for the same action with commas, e.g. \"super+left, super+kp_left\". Clear a field to revert it to the built-in default.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            first: true
            text: qsTr("Actions")
        }

        Repeater {
            id: actionRows

            model: root.knownActions

            TextFieldRow {
                id: actionField

                required property string modelData
                required property int index

                first: index === 0
                last: index === actionRows.count - 1
                label: IronlandCtl.actionLabel(modelData)
                placeholderText: qsTr("e.g. super+shift+q")
                value: root.combosText(modelData)
                onEditingFinished: v => root.commitAction(modelData, v)
            }
        }

        SectionHeader {
            text: qsTr("Shell events")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: qsTr("Binds a key to a named shortcut a client (like this shell) requests over ironland-shortcuts-v1, rather than one of the compositor's own actions above.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: eventRows

            model: Object.keys(root.events?.configured ?? {}).sort()

            TextFieldRow {
                required property string modelData
                required property int index

                first: index === 0
                label: modelData
                placeholderText: qsTr("e.g. super+g")
                value: (root.events.configured[modelData] ?? []).join(", ")
                onEditingFinished: v => root.commitEvent(modelData, v)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: root.events?.suggested ?? []

                RowButton {
                    required property string modelData

                    Layout.fillWidth: true
                    first: true
                    last: true
                    icon: "add"
                    text: modelData
                    onClicked: IronlandCtl.eventAdd(modelData, "", () => root.refreshEvents())
                }
            }
        }

        TextFieldRow {
            id: newEventField

            last: true
            label: qsTr("Custom event name")
            placeholderText: qsTr("e.g. one a third-party client advertises")
            onEditingFinished: v => {
                if (v) {
                    IronlandCtl.eventAdd(v, "", () => root.refreshEvents());
                    newEventField.clear();
                }
            }
        }
    }
}
