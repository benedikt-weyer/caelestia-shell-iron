#!/usr/bin/env bash
# Rebuilds the local cmake tree (see .envrc) and launches it directly with
# quickshell, bypassing the installed/systemd-managed caelestia-shell so you
# can test local changes (plugin included) in place.
#
# Usage: run.sh [qs args...]
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cmake --build build

# The C++ plugin (import Caelestia) lives under build/qml; the shell QML tree
# (shell.qml, modules/, services/, utils/, components/, assets/) is only
# staged into build/qml by `cmake --install`, so run straight from the repo
# root and just point the plugin import path at the build dir.
export QML2_IMPORT_PATH="$repo_root/build/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

exec qs -n -p "$repo_root" "$@"
