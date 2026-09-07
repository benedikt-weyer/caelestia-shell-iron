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

exec qs -n -p build/qml "$@"
