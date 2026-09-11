pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Wayland

// Wraps the `ironland-clipboard-history-v1`-backed IronlandClipboardHistory
// plugin object (see plugin/src/Caelestia/Wayland/ironlandclipboardhistory.hpp)
// as a shell-wide singleton, so every screen's clipboard-history overlay
// (modules/clipboard) shares one live-updated list instead of each binding
// the protocol's manager global separately.
Singleton {
    id: root

    // Most-recent-first list of {id, mimeType, preview} objects - directly
    // usable as a ListView/Repeater model.
    readonly property alias entries: history.entries
    // True once the compositor has denied this shell clipboard-history
    // access (see the protocol's `denied` event) - this is permanent for
    // the rest of the compositor's process lifetime (see
    // ironland-compositor's `crate::clipboard` module doc), so the overlay
    // shows an explanatory message instead of a silently-empty list.
    readonly property alias denied: history.denied

    function remove(id: int): void {
        history.remove(id);
    }

    function removeAll(): void {
        history.removeAll();
    }

    // Copies entry `id`'s full text back to the system clipboard.
    function restore(id: int): void {
        history.restore(id);
    }

    // qmllint disable unresolved-type
    IronlandClipboardHistory {
        // qmllint enable unresolved-type
        id: history
    }
}
