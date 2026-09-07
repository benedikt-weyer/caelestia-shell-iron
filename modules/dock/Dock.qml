pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).dock.enabled && !Strings.testRegexList(GlobalConfig.forScreen(s.name).dock.excludedScreens, s.name))

    StyledWindow {
        id: win

        required property ShellScreen modelData

        readonly property int iconSize: contentItem.Config.dock.iconSize
        readonly property var groups: {
            const groups = [];
            for (const t of Hypr.toplevels.values) {
                if (Hypr.isToplevelIgnored(t) || !t.screens.includes(win.modelData))
                    continue;

                const group = groups.find(g => g.appId === t.appId);
                if (group)
                    group.windows.push(t);
                else
                    groups.push({
                        appId: t.appId,
                        windows: [t]
                    });
            }
            return groups;
        }

        screen: modelData
        name: "dock"

        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        implicitHeight: content.height + Tokens.padding.small * 2
        mask: Region {
            x: (win.width - content.width) / 2
            y: win.height - content.height
            width: content.width
            height: content.height
        }

        ShellState.ComponentRef {
            screen: win.modelData
            slot: "dock"
            component: win
        }

        StyledRect {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            width: row.implicitWidth + Tokens.padding.large * 2
            height: row.implicitHeight + Tokens.padding.small * 2

            RowLayout {
                id: row

                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                Repeater {
                    model: win.groups

                    DockIcon {
                        required property var modelData

                        group: modelData
                        iconSize: win.iconSize
                    }
                }
            }
        }
    }

    component DockIcon: ColumnLayout {
        id: icon

        required property var group
        required property int iconSize

        readonly property bool active: group.windows.some(w => w.activated)

        function activate(): void {
            const idx = group.windows.findIndex(w => w.activated);
            const next = group.windows[(idx + 1) % group.windows.length];
            next.activate();
        }

        spacing: Tokens.spacing.extraSmall / 2

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: icon.iconSize
            implicitHeight: icon.iconSize

            MaterialIcon {
                anchors.centerIn: parent
                animate: true
                text: Icons.getAppCategoryIcon(icon.group.appId, "desktop_windows")
                color: icon.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.size(icon.iconSize * 0.6).build()

                Behavior on color {
                    CAnim {}
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: icon.activate()
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: icon.iconSize * 0.5
            Layout.preferredHeight: 3
            radius: 1.5
            color: Colours.palette.m3primary
            opacity: icon.active ? 1 : 0

            Behavior on opacity {
                Anim {}
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 3
            visible: icon.group.windows.length > 1

            Repeater {
                model: Math.min(icon.group.windows.length, 4)

                StyledRect {
                    implicitWidth: 4
                    implicitHeight: 4
                    radius: 2
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
