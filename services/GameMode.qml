pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services

// Used to also push `animations:enabled`/`blur:enabled`/gaps/border/rounding
// overrides into Hyprland's own live config (and restore them with a
// `reload` on exit) - pure Hyprland config automation with no equivalent
// under ironland-compositor, so this is now just a local toggle other QML
// (e.g. DesktopClock's own background blur) can react to for its own
// visual effects, with no compositor-side effect of its own.
Singleton {
    id: root

    property alias enabled: props.enabled

    onEnabledChanged: {
        if (enabled) {
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode enabled"), qsTr("Reduced shell visual effects"), "gamepad");
        } else {
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode disabled"), qsTr("Shell visual effects restored"), "gamepad");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: false

        reloadableId: "gameMode"
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "gameMode"
    }
}
