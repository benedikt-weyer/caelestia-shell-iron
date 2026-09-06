pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Compositor-agnostic replacement for what used to be a thin wrapper around
// Quickshell.Hyprland: toplevels come from the generic
// wlr-foreign-toplevel-management-v1 (via Quickshell's own ToplevelManager,
// no compositor-specific glue needed), workspaces from IronWorkspaces (the
// ext-workspace-v1 bridge - see that file), and "monitor" is just a
// ShellScreen, since there's no separate monitor-info type to wrap anymore.
//
// Concepts that had no home outside Hyprland's own IPC - special
// workspaces, "game mode" config toggles, keyboard layout/caps-lock/num-lock
// tracking - are gone; their consumers now use fixed fallbacks. See the
// caelestia-shell-iron port notes for the full list.
Singleton {
    id: root

    readonly property var toplevels: ToplevelManager.toplevels
    readonly property Toplevel activeToplevel: ToplevelManager.activeToplevel

    // No generic protocol reports "the focused output" directly - approximated
    // as whichever output the active toplevel is on, falling back to the
    // first screen (e.g. nothing focused yet, or focus is on a layer-shell
    // surface rather than a window).
    readonly property ShellScreen focusedMonitor: root.activeToplevel?.screens[0] ?? Quickshell.screens[0] ?? null

    readonly property var focusedWorkspaces: root.focusedMonitor ? IronWorkspaces.workspacesFor(root.focusedMonitor.name) : []
    readonly property var focusedWorkspace: root.focusedWorkspaces.find(w => w.active) ?? null
    readonly property int activeWsId: (root.focusedWorkspace?.index ?? 0) + 1

    function monitorFor(screen: ShellScreen): ShellScreen {
        return screen;
    }

    function monitorNames(): list<string> {
        return Quickshell.screens.map(s => s.name);
    }

    function workspacesFor(screen: ShellScreen): var {
        return screen ? IronWorkspaces.workspacesFor(screen.name) : [];
    }

    function switchWorkspace(screen: ShellScreen, index: int): void {
        if (screen)
            IronWorkspaces.activate(screen.name, index);
    }

    // Best-effort: matches by title+app id against the workspace's window
    // list from IronWorkspaces (see its doc for why there's no stable id to
    // match on instead), since wlr-foreign-toplevel-management-v1 has no
    // workspace concept of its own.
    function toplevelsForWs(screen: ShellScreen, wsIndex: int): list<Toplevel> {
        const ws = root.workspacesFor(screen).find(w => w.index === wsIndex);
        if (!ws || !ws.windows.length)
            return [];

        return root.toplevels.values.filter(t => ws.windows.some(w => w.title === t.title && w.appId === t.appId));
    }

    function isToplevelIgnored(toplevel: Toplevel): bool {
        return !toplevel?.appId;
    }

    // Keyboard device tracking rode entirely on Hyprland's own IPC
    // (HyprExtras/HyprDevices) - no generic protocol reports caps-lock/
    // num-lock/layout, so these are fixed "off"/"unknown" stubs. Consumers
    // (StatusIcons, LockStatus, the lock screen's state message) already
    // degrade sensibly on these: the caps/num-lock indicators just never
    // show, and the layout label reads as unknown.
    readonly property bool capsLock: false
    readonly property bool numLock: false
    readonly property string defaultKbLayout: "??"
    readonly property string kbLayoutFull: qsTr("Unknown")
    readonly property string kbLayout: "??"
}
