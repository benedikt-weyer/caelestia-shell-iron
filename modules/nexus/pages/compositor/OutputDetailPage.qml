pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property string name: root.nState.selectedOutputName
    readonly property var settings: IronlandCtl.config?.outputs[root.name] ?? null
    property var detectedRefreshRates: []
    // Rebuilt (and the previous items destroyed) whenever detectedRefreshRates
    // changes - which happens once, right after detectOutputs() resolves.
    property list<var> refreshMenuItems: [autoRefreshItem]

    readonly property list<MenuItem> modeItems: [
        MenuItem {
            text: qsTr("Extend (auto-placed)")
        },
        MenuItem {
            text: qsTr("Extend: right of…")
        },
        MenuItem {
            text: qsTr("Extend: left of…")
        },
        MenuItem {
            text: qsTr("Extend: above…")
        },
        MenuItem {
            text: qsTr("Extend: below…")
        },
        MenuItem {
            text: qsTr("Extend: at position…")
        },
        MenuItem {
            text: qsTr("Duplicate (mirror)…")
        }
    ]

    function modeIndex(): int {
        const s = root.settings;
        if (!s)
            return 0;
        if (s.mirror_of)
            return 6;
        if (!s.position)
            return 0;
        if (s.position.right_of)
            return 1;
        if (s.position.left_of)
            return 2;
        if (s.position.above)
            return 3;
        if (s.position.below)
            return 4;
        return 5;
    }

    function applyMode(idx: int, target: string, x: string, y: string): void {
        const args = [];
        switch (idx) {
        case 1:
            args.push("--right-of", target);
            break;
        case 2:
            args.push("--left-of", target);
            break;
        case 3:
            args.push("--above", target);
            break;
        case 4:
            args.push("--below", target);
            break;
        case 5:
            args.push("--x", x || "0", "--y", y || "0");
            break;
        case 6:
            args.push("--mirror-of", target);
            break;
        default:
            args.push("--auto-position");
        }
        IronlandCtl.outputsSet(root.name, args, () => {});
    }

    title: root.name
    isSubPage: true

    Component.onCompleted: IronlandCtl.detectOutputs(outputs => {
        const found = outputs?.find(o => o.name === root.name);
        root.detectedRefreshRates = found?.refresh_rates ?? [];

        for (const item of root.refreshMenuItems)
            if (item !== autoRefreshItem)
                item.destroy();
        root.refreshMenuItems = [autoRefreshItem, ...root.detectedRefreshRates.map(rate => refreshItemComp.createObject(root, {
                    rateMhz: rate
                }))];
    })

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        CompositorError {}

        // rateMhz: 0 is the "Automatic" sentinel, matching how the config
        // file itself represents "no override" for refresh_rate.
        RefreshItem {
            id: autoRefreshItem

            rateMhz: 0
        }

        Component {
            id: refreshItemComp

            RefreshItem {}
        }

        ToggleRow {
            first: true
            text: qsTr("Primary monitor")
            checked: root.settings?.primary ?? false
            onToggled: IronlandCtl.outputsSet(root.name, checked ? ["--primary"] : ["--no-primary"], () => {})
        }

        SelectRow {
            label: qsTr("Refresh rate")
            menuOnTop: true
            menuItems: root.refreshMenuItems
            active: menuItems.find(i => i.rateMhz === (root.settings?.refresh_rate ?? 0)) ?? menuItems[0]
            onSelected: item => IronlandCtl.outputsSet(root.name, item.rateMhz ? ["--refresh-mhz", String(item.rateMhz)] : ["--auto-refresh"], () => {})
        }

        SelectRow {
            last: true
            label: qsTr("Position")
            menuOnTop: true
            menuItems: root.modeItems
            active: root.modeItems[root.modeIndex()]
            onSelected: item => root.applyMode(root.modeItems.indexOf(item), targetField.value, xField.value, yField.value)
        }

        TextFieldRow {
            id: targetField

            first: true
            last: true
            visible: [1, 2, 3, 4, 6].includes(root.modeIndex())
            label: qsTr("Relative to / duplicate of")
            placeholderText: qsTr("other monitor's connector name")
            value: root.settings?.position?.right_of ?? root.settings?.position?.left_of ?? root.settings?.position?.above ?? root.settings?.position?.below ?? root.settings?.mirror_of ?? ""
            onEditingFinished: v => root.applyMode(root.modeIndex(), v, "", "")
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.modeIndex() === 5
            spacing: Tokens.spacing.small

            TextFieldRow {
                id: xField

                Layout.fillWidth: true
                first: true
                label: qsTr("X")
                validator: IntValidator {}
                value: root.settings?.position?.x !== undefined ? String(root.settings.position.x) : "0"
                onEditingFinished: v => root.applyMode(5, "", v, yField.value)
            }

            TextFieldRow {
                id: yField

                Layout.fillWidth: true
                last: true
                label: qsTr("Y")
                validator: IntValidator {}
                value: root.settings?.position?.y !== undefined ? String(root.settings.position.y) : "0"
                onEditingFinished: v => root.applyMode(5, "", xField.value, v)
            }
        }

        RowButton {
            Layout.topMargin: Tokens.spacing.medium
            first: true
            last: true
            icon: "restart_alt"
            text: qsTr("Forget this monitor")
            subtext: qsTr("Revert to auto-placed, extended, not primary")
            visible: root.settings !== null
            onClicked: {
                IronlandCtl.outputsRemove(root.name, () => {});
                root.nState.closeSubPage();
            }
        }
    }

    component RefreshItem: MenuItem {
        required property int rateMhz

        text: rateMhz === 0 ? qsTr("Automatic") : rateMhz % 1000 === 0 ? qsTr("%1 Hz").arg(rateMhz / 1000) : qsTr("%1 Hz").arg((rateMhz / 1000).toFixed(3))
    }
}
