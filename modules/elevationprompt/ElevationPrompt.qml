pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Caelestia.Wayland
import qs.components.containers
import qs.services

Scope {
    id: root

    property list<var> pending: []
    readonly property var current: pending.length > 0 ? pending[0] : null

    function respond(allowed: bool): void {
        if (!root.current)
            return;

        permissionPrompt.answer(root.current.promptId, allowed);
        root.pending = root.pending.slice(1);
    }

    // qmllint disable unresolved-type
    IronlandPermissionPrompt {
        // qmllint enable unresolved-type
        id: permissionPrompt

        onPromptRequested: (promptId, appId, reason) => {
            root.pending = root.pending.concat([
                {
                    promptId: promptId,
                    appId: appId,
                    reason: reason
                }
            ]);
        }
        onPromptCancelled: promptId => {
            root.pending = root.pending.filter(p => p.promptId !== promptId);
        }
    }

    LazyLoader {
        active: root.current !== null

        StyledWindow {
            id: win

            screen: Screens.screens[0] ?? Quickshell.screens[0]
            name: "elevation"
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Prompt {
                anchors.fill: parent
                prompt: root.current

                onAllow: root.respond(true)
                onDeny: root.respond(false)
            }
        }
    }
}
