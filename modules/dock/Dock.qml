pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
        readonly property bool showBackground: contentItem.Config.dock.showBackground
        // The DockIcon currently showing its context menu, or null. Kept here
        // (rather than one popup per icon) so opening a menu always closes
        // whichever other one was open.
        property var menuTarget: null

        // Which running windows count as "on this dock", per Config.dock.scope:
        // - Monitor: only this screen's own active workspace.
        // - SharedWorkspace: every screen's active workspace, combined - so
        //   every dock shows the same set, for setups where matching
        //   workspace numbers across monitors are treated as one desktop.
        // - Global: every running window, everywhere.
        readonly property var scopedToplevels: {
            const scope = contentItem.Config.dock.scope;

            if (scope === DockScope.Global)
                return Hypr.toplevels.values.filter(t => !Hypr.isToplevelIgnored(t));

            if (scope === DockScope.SharedWorkspace) {
                let combined = [];
                for (const s of Quickshell.screens) {
                    const ws = Hypr.workspacesFor(s).find(w => w.active);
                    if (ws)
                        combined = combined.concat(Hypr.toplevelsForWs(s, ws.index));
                }
                return combined;
            }

            const ws = Hypr.workspacesFor(win.modelData).find(w => w.active);
            return ws ? Hypr.toplevelsForWs(win.modelData, ws.index) : [];
        }

        // Pinned apps are always shown (even with no window in scope, in
        // which case clicking launches a new instance) and always come first,
        // in pinned order; any other in-scope running app follows in
        // discovery order.
        readonly property var groups: {
            const pinned = GlobalConfig.dock.pinnedApps;

            const running = [];
            for (const t of win.scopedToplevels) {
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
        // Space for the dock is reserved by a dedicated exclusion window
        // instead (see modules/drawers/Exclusions.qml), same as the bar on
        // the left - otherwise this window's own auto-computed exclusive
        // zone would stack with that one's on the same (bottom) edge, and
        // this surface would end up positioned short of the actual screen
        // edge by the latter's reservation.
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        implicitHeight: content.height + Tokens.padding.small * 2
        mask: Region {
            x: (win.width - content.width) / 2
            y: (win.height - content.height) / 2
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
            anchors.verticalCenter: parent.verticalCenter

            radius: Tokens.rounding.extraLarge
            color: win.showBackground ? Colours.tPalette.m3surfaceContainer : "transparent"

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

                        dock: win
                        group: modelData
                        pinned: modelData.pinned
                        iconSize: win.iconSize
                    }
                }
            }
        }

        PopupWindow {
            id: contextMenu

            readonly property var target: win.menuTarget
            readonly property list<MenuItem> menuItems: target ? (target.group.windows.length > 0 ? [target.openItem, target.pinItem, target.quitItem] : [target.openItem, target.pinItem]) : []

            visible: target !== null
            color: "transparent"

            anchor.item: target?.anchorItem ?? null
            anchor.edges: Edges.Top
            anchor.gravity: Edges.Top
            anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
            anchor.margins.bottom: Tokens.spacing.small

            grabFocus: true

            implicitWidth: Math.max(180, column.implicitWidth + column.anchors.margins * 2)
            implicitHeight: column.implicitHeight + column.anchors.margins * 2

            onVisibleChanged: {
                if (!visible)
                    win.menuTarget = null;
            }

            Item {
                anchors.fill: parent
                focus: contextMenu.visible

                Keys.onEscapePressed: win.menuTarget = null

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surfaceContainerLow

                    ColumnLayout {
                        id: column

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.extraSmall
                        spacing: 0

                        Repeater {
                            model: contextMenu.menuItems

                            StyledRect {
                                id: menuRow

                                required property MenuItem modelData
                                required property int index

                                Layout.fillWidth: true
                                implicitWidth: menuRowLayout.implicitWidth + Tokens.padding.medium * 2
                                implicitHeight: menuRowLayout.implicitHeight + Tokens.padding.medium * 2

                                radius: Tokens.rounding.extraSmall
                                color: "transparent"

                                StateLayer {
                                    color: Colours.palette.m3onSurface
                                    onClicked: {
                                        menuRow.modelData.clicked();
                                        win.menuTarget = null;
                                    }
                                }

                                RowLayout {
                                    id: menuRowLayout

                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.medium
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: menuRow.modelData.icon
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true
                                        text: menuRow.modelData.text
                                        color: Colours.palette.m3onSurface
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component DockIcon: ColumnLayout {
        id: icon

        required property var dock
        required property var group
        required property bool pinned
        required property int iconSize

        readonly property alias anchorItem: iconRoot
        readonly property alias openItem: openItem
        readonly property alias pinItem: pinItem
        readonly property alias quitItem: quitItem

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
                        icon.dock.menuTarget = icon.dock.menuTarget === icon ? null : icon;
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
            visible: icon.group.windows.length > 0

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
