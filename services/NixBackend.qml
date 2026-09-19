pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.NixBackend

// Thin QML-facing wrapper around the native NixBackendClient gRPC client
// (Caelestia.NixBackend, see plugin/src/Caelestia/NixBackend) - adds the
// bits that are awkward to do in C++: reading the configured system target
// out of GlobalConfig, keeping a bounded scrolling log, and refreshing the
// "last updated" git status automatically after a successful op.
Singleton {
    id: root

    // Mirrors NixBackendClient::RebuildMode's ordinals so callers don't need
    // to import Caelestia.NixBackend just for these three constants.
    readonly property int modeSwitch: 0
    readonly property int modeBoot: 1
    readonly property int modeTest: 2

    // Mirrors NixBackendClient::Phase's ordinals, for callers that just want
    // to compare against "did it fail" without importing Caelestia.NixBackend.
    readonly property int phaseFailed: 8

    readonly property string configDir: GlobalConfig.nixBackend.systemConfigDir
    readonly property string hostName: GlobalConfig.nixBackend.systemHostName

    readonly property bool running: NixBackendClient.running
    readonly property int phase: NixBackendClient.phase
    readonly property real fractionDone: NixBackendClient.fractionDone
    readonly property string statusMessage: NixBackendClient.statusMessage
    readonly property string lastError: NixBackendClient.lastError

    readonly property bool flakeHasGitHistory: NixBackendClient.flakeHasGitHistory
    readonly property string flakeLastModified: NixBackendClient.flakeLastModified
    readonly property string flakeLastCommitSubject: NixBackendClient.flakeLastCommitSubject
    readonly property string flakeLastCommitHash: NixBackendClient.flakeLastCommitHash

    readonly property ListModel log: ListModel {}

    function phaseLabel(phase: int): string {
        switch (phase) {
        case NixBackendClient.Started:
            return qsTr("Starting");
        case NixBackendClient.FlakeUpdate:
            return qsTr("Updating flake");
        case NixBackendClient.Build:
            return qsTr("Building");
        case NixBackendClient.Diff:
            return qsTr("Diffing closures");
        case NixBackendClient.Register:
            return qsTr("Registering generation");
        case NixBackendClient.Activate:
            return qsTr("Activating");
        case NixBackendClient.Finished:
            return qsTr("Finished");
        case NixBackendClient.Failed:
            return qsTr("Failed");
        default:
            return qsTr("Idle");
        }
    }

    // Plain-text error report for pasting into an issue or chat: the status
    // message, the RPC error (if distinct), then every error line from the log.
    function errorText(): string {
        const parts = [];
        if (root.statusMessage)
            parts.push(root.statusMessage);
        if (root.lastError && root.lastError !== root.statusMessage)
            parts.push(root.lastError);
        for (let i = 0; i < root.log.count; i++) {
            const entry = root.log.get(i);
            if (entry.isError)
                parts.push(entry.message);
        }
        return parts.join("\n");
    }

    function clearLog(): void {
        root.log.clear();
    }

    function updateFlake(): void {
        if (root.running)
            return;
        root.clearLog();
        NixBackendClient.updateFlake(root.configDir, root.hostName);
    }

    function rebuild(mode: int): void {
        if (root.running)
            return;
        root.clearLog();
        NixBackendClient.rebuild(root.configDir, root.hostName, mode);
    }

    function refreshFlakeStatus(): void {
        NixBackendClient.refreshFlakeStatus(root.configDir, root.hostName);
    }

    Component.onCompleted: root.refreshFlakeStatus()

    Connections {
        function onLineLogged(message: string, isError: bool): void {
            root.log.append({
                message: message,
                isError: isError
            });
            // Keep the log bounded across long-running builds.
            while (root.log.count > 500)
                root.log.remove(0);
        }

        function onFinished(success: bool): void {
            if (success)
                root.refreshFlakeStatus();
        }

        target: NixBackendClient
    }
}
