pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.launcher.services

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).dock.enabled && !Strings.testRegexList(GlobalConfig.forScreen(s.name).dock.excludedScreens, s.name))

    StyledWindow {
        id: win

        required property ShellScreen modelData

        readonly property int iconSize: contentItem.Config.dock.iconSize
        // Pinned apps are always shown (even with no window on this screen, in
        // which case clicking launches a new instance) and always come first,
        // in pinned order; any other running app follows in discovery order.
        readonly property var groups: {
            const pinned = GlobalConfig.dock.pinnedApps;

            const running = [];
            for (const t of Hypr.toplevels.values) {
                if (Hypr.isToplevelIgnored(t) || !t.screens.includes(win.modelData))
                    continue;

                const group = running.find(g => g.appId === t.appId);
                if (group)
                    group.windows.push(t);
                else
                    running.push({
                        appId: t.appId,
                        windows: [t]
                    });
            }

            const pinnedGroups = pinned.map(appId => ({
                        appId: appId,
                        windows: running.find(g => g.appId === appId)?.windows ?? [],
                        pinned: true
                    }));
            const unpinnedGroups = running.filter(g => !pinned.includes(g.appId)).map(g => ({
                        appId: g.appId,
                        windows: g.windows,
                        pinned: false
                    }));

            return pinnedGroups.concat(unpinnedGroups);
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
                        pinned: modelData.pinned
                        iconSize: win.iconSize
                    }
                }
            }
        }
    }

    component DockIcon: ColumnLayout {
        id: icon

        required property var group
        required property bool pinned
        required property int iconSize

        readonly property bool active: group.windows.some(w => w.activated)

        function primaryAction(): void {
            if (group.windows.length > 0)
                activate();
            else
                launch();
        }

        function activate(): void {
            const idx = group.windows.findIndex(w => w.activated);
            const next = group.windows[(idx + 1) % group.windows.length];
            next.activate();
        }

        function launch(): void {
            const entry = DesktopEntries.byId(icon.group.appId);
            if (entry)
                Apps.launch(entry);
        }

        function togglePin(): void {
            const pinnedApps = GlobalConfig.dock.pinnedApps;
            GlobalConfig.dock.pinnedApps = icon.pinned ? pinnedApps.filter(a => a !== icon.group.appId) : [...pinnedApps, icon.group.appId];
        }

        function quit(): void {
            for (const w of icon.group.windows)
                w.close();
        }

        spacing: Tokens.spacing.extraSmall / 2

        Item {
            id: iconRoot

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: icon.iconSize
            implicitHeight: icon.iconSize

            IconImage {
                anchors.centerIn: parent
                asynchronous: true
                implicitSize: icon.iconSize
                source: Icons.getAppIcon(icon.group.appId, "image-missing")
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        menu.expanded = !menu.expanded;
                    else
                        icon.primaryAction();
                }
            }

            MenuItem {
                id: openItem

                icon: "open_in_new"
                text: icon.group.windows.length > 0 ? qsTr("New window") : qsTr("Open")

                onClicked: icon.launch()
            }

            MenuItem {
                id: pinItem

                icon: icon.pinned ? "keep_off" : "keep"
                text: icon.pinned ? qsTr("Unpin from dock") : qsTr("Pin to dock")

                onClicked: icon.togglePin()
            }

            MenuItem {
                id: quitItem

                icon: "close"
                text: qsTr("Quit")

                onClicked: icon.quit()
            }

            Menu {
                id: menu

                attachTo: iconRoot
                attachSideY: Menu.Top
                thisSideY: Menu.Bottom
                marginY: -Tokens.spacing.small

                items: icon.group.windows.length > 0 ? [openItem, pinItem, quitItem] : [openItem, pinItem]
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
