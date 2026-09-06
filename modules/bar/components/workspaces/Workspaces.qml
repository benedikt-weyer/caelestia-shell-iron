pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    // Special workspaces were a Hyprland-only concept with no equivalent
    // under ironland-copositor's workspace model - always false/0 now, kept
    // as properties so the bindings below don't need individual changes.
    readonly property bool onSpecial: false
    readonly property int activeWsId: (Hypr.workspacesFor(screen).find(w => w.active)?.index ?? 0) + 1

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspacesFor(screen))
            occ[ws.index + 1] = ws.windows.length > 0;
        return occ;
    }
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.small

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Tokens.spacing.extraSmall)

            Repeater {
                id: workspaces

                model: Config.bar.workspaces.shown

                Workspace {
                    screen: root.screen
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: parent.horizontalCenter
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
                fullscreen: root.fullscreen
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                if (!ws || root.activeWsId === ws)
                    return;
                Hypr.switchWorkspace(root.screen, ws - 1);
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
