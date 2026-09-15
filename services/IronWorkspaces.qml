pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wraps the `ironland-workspaces` helper binary (a standalone Wayland
// client shipped by ironland-compositor - see its own module doc), since
// Quickshell has no built-in support for `ext-workspace-v1`. Talks
// line-delimited JSON over the process's stdin/stdout; see that binary's
// doc comment for the wire format, including the best-effort `windows`
// list per workspace (from ironland-compositor's own
// `ironland-workspace-windows-v1`, matched by title/app id - empty on a
// compositor that doesn't support it).
Singleton {
    id: root

    // output name -> array of {index, name, active, windows: [{title, appId, floating}]}
    property var outputs: ({})

    function workspacesFor(outputName: string): var {
        return root.outputs[outputName] ?? [];
    }

    function activate(outputName: string, index: int): void {
        proc.write(`${JSON.stringify({
            activate: {
                output: outputName,
                index: index
            }
        })}\n`);
    }

    // Best-effort, same as `windows` itself: matches the target window by
    // title+appId within the given output/workspace. A no-op if the
    // compositor doesn't support `ironland-workspace-windows-v1` or nothing
    // matches.
    function setFloating(outputName: string, index: int, title: string, appId: string, floating: bool): void {
        proc.write(`${JSON.stringify({
            setFloating: {
                output: outputName,
                index: index,
                title: title,
                appId: appId,
                floating: floating
            }
        })}\n`);
    }

    Process {
        id: proc

        running: true
        stdinEnabled: true
        command: ["ironland-workspaces"]

        stdout: SplitParser {
            onRead: data => {
                if (!data.trim())
                    return;

                let state;
                try {
                    state = JSON.parse(data);
                } catch (e) {
                    console.warn("IronWorkspaces: ignoring malformed line from ironland-workspaces:", data);
                    return;
                }

                const map = {};
                for (const output of state.outputs ?? [])
                    map[output.name] = output.workspaces ?? [];
                root.outputs = map;
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.warn("IronWorkspaces: ironland-workspaces exited, restarting", exitCode, exitStatus);
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer

        interval: 2000
        onTriggered: proc.running = true
    }
}
