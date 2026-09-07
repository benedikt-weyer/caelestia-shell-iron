# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`caelestia-shell-iron` is a desktop shell built on [Quickshell](https://quickshell.outfoxxed.me) (QML). It is a fork of `caelestia-dots/shell` ported off Hyprland-specific APIs (`hyprctl`/`Quickshell.Hyprland`) onto generic Wayland protocols, targeting a companion compositor called **ironland-compositor**. Where the upstream project used Hyprland IPC/extensions, this fork talks to custom Wayland protocols instead:

- `plugin/protocols/ironland-shortcuts-v1.xml` — global shortcuts (replaces `Quickshell.Hyprland`'s `GlobalShortcut`)
- `plugin/protocols/ironland-focus-grab-v1.xml` — focus grabbing
- `ironland-workspaces` — an external helper binary (not in this repo) that speaks line-delimited JSON over stdin/stdout for `ext-workspace-v1` support (see `services/IronWorkspaces.qml`)

Some Hyprland-specific services (`hyprdevices`, `hyprextras`, `services/Hypr.qml`) remain for features not yet ported or that are Hyprland-only; don't assume the whole codebase is compositor-agnostic.

The shell has two parts:
- **QML shell** (`shell.qml`, `modules/`, `components/`, `services/`, `utils/`) — the actual UI, loaded by Quickshell.
- **C++ plugin** (`plugin/`) — a Qt QML module (`import Caelestia`) providing native types the QML side can't do efficiently: settings persistence, config schema, native Wayland protocol clients, image processing, audio visualisation, blob shader components, etc. Built with CMake, installed alongside the QML tree.

## Build & dev workflow

This project uses Nix + direnv for the dev environment. `direnv allow` (or entering the directory with direnv active) runs `.envrc`, which:
1. Configures CMake in `build/` (RelWithDebInfo, clang++ or clazy, ccache if available) if not already configured.
2. Builds the C++ plugin.
3. Exports `CAELESTIA_LIB_DIR` and `QML2_IMPORT_PATH` so a locally-run Quickshell picks up the freshly built plugin.
4. Adds `scripts/` to `PATH`.

To rebuild and run the shell against your local checkout (plugin included) without touching the system-installed/systemd-managed shell:

```sh
scripts/run.sh [qs args...]
```

This just does `cmake --build build` then `exec qs -n -p build/qml`.

Manual CMake build (see README for full manual-install instructions):

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
```

Useful CMake vars:
- `ENABLE_MODULES` (default `extras;plugin;shell`) — which top-level pieces to configure.
- `INSTALL_LIBDIR` / `INSTALL_QMLDIR` / `INSTALL_QSCONFDIR` — install locations for the native lib, QML plugin, and Quickshell config dir respectively.

C++ compiler warnings are strict (`-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wold-style-cast -Wsign-conversion` etc., see root `CMakeLists.txt`), and CI treats warnings as errors.

### Linting & formatting (mirrors CI, see `.github/workflows/`)

QML format check (uses `qmlformat` from Qt 6, plus a custom convention checker):
```sh
qmlformat <file.qml> | diff -u <file.qml> -
python3 scripts/qml-lint-conventions.py          # check convention violations (import/property/signal/function ordering, blank lines)
python3 scripts/qml-lint-conventions.py --fix    # auto-fix what it can
```

QML static lint (`qmllint`), requires a configured build so import paths resolve — see `.github/workflows/lint.yml` for the exact invocation (it regenerates `.qmlls.ini` via a throwaway `qs -p .` run to get build/import paths, then runs `qmllint --import disable`).

C++ format:
```sh
clang-format --dry-run --Werror plugin/**/*.cpp plugin/**/*.hpp extras/**/*.cpp
```

C++ lint (`clang-tidy` via `run-clang-tidy`), needs `compile_commands.json`:
```sh
cmake -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON
run-clang-tidy -p build -quiet -warnings-as-errors='*' -source-filter='^(?!.*/build/).*\.cpp$'
```

There is no automated test suite; CI validates by building (Nix flake + raw CMake, both gcc and clazy) and, for flake updates, actually launching the shell headlessly under Sway and checking the process survives.

## Architecture

### QML side layout
- `shell.qml` — entry point (`ShellRoot`), wires up global singletons/loaders and top-level scopes (`Background`, `Drawers`, `AreaPicker`, `Lock`, `Shortcuts`, `BatteryMonitor`, `IdleMonitors`).
- `modules/` — one subdirectory per shell surface (bar, dashboard, launcher, lock, nexus, notifications, osd, session, sidebar, utilities, background, areapicker, drawers, windowinfo). Deeper nesting mirrors sub-components of that surface (e.g. `modules/bar/components`, `modules/bar/popouts`, `modules/dashboard/media`).
- `services/` — singleton `pragma Singleton` QML services (state and external integrations): `ShellState` (per-screen UI state), `Hypr`/`IronWorkspaces` (compositor integration), `Colours`, `Audio`, `Players`, `Notifs`/`NotifData`, `Weather`, `Wallpapers`, `Brightness`, `VPN`, `Nmcli`, `Recorder`, `GameMode`, `IdleInhibitor`, `Screens`, `Time`.
- `components/` — reusable, generic QML building blocks (styled rects/text, animations, containers, controls, effects, file dialog, images, widgets) used across modules. Not surface-specific.
- `utils/` — plain JS/QML utility singletons (icons, images, paths, searching, string helpers, system info) plus `utils/scripts` (shell scripts invoked by QML `Process`).
- Config is read through the C++ plugin's `Config` node tree (see below) and exposed to QML as `Config.<section>.<option>` (Config in Config node tree, mapping to `~/.config/caelestia/shell.json`, documented exhaustively in `README.md`'s example config block).

### C++ plugin layout (`plugin/src/Caelestia/`)
Each subdirectory is its own `add_subdirectory` with its own `CMakeLists.txt`, all folded into the single `caelestia-core` QML module (`import Caelestia`):
- `Settings/` — generic reactive settings-tree infrastructure (`node`, `objectnode`, `listnode`, `schema`, `settingsfile`, change batching, codecs). This is the low-level engine; not config-specific itself.
- `Config/` — the concrete config schema built on top of `Settings/`, one header per config section (`appearanceconfig`, `barconfig`, `dashboardconfig`, `generalconfig`, `launcherconfig`, `lockconfig`, `nexusconfig`, `notifsconfig`, `osdconfig`, `sidebarconfig`, `utilitiesconfig`, `serviceconfig`, etc.), plus `rootnodes` tying them together and `tokensattached`/`configattached` for QML attached-property access.
- `Models/` — `appdb` (desktop app database/search) and `filesystemmodel`.
- `Services/` — native backends too heavy/low-level for pure QML: audio visualisation pipeline (`audiocollector` → `audioprovider`/`cavaprovider`/`beattracker`), `cpu`/`gpu`/`diskinfo` system stats, `hyprdevices`/`hyprextras` (Hyprland-only, legacy), lyrics fetching (`lyriccandidate`).
- `Blobs/` — the animated blob shape shader effect (`blobgroup`/`blobrect`/`blobinvertedrect`/`blobshape`/`blobmaterial` + GLSL shaders in `shaders/`).
- `Images/` — image caching/analysis (`cachingimageprovider`, `imagecacher`, `imageanalyser`, `iutils`).
- `Wayland/` — native Wayland protocol clients: `ironlandshortcut` (global shortcuts) and `ironlandfocusgrab`, generated against the XML protocol specs in `plugin/protocols/` via `plugin/cmake/wayland-protocol.cmake`.
- `Components/` — misc QML-exposed C++ items (`buttonrow`, `lazylistview`, `sparklineitem`, `visualiserbars`, `wavyline`, circular/linear indicator managers).
- Build helpers live in `plugin/cmake/`: `qml-module.cmake` (the `qml_module()` helper used by every subdirectory's `CMakeLists.txt`), `pch.cmake` (precompiled headers — C bindings are excluded from PCH), `wayland-protocol.cmake`, `sensorslib.cmake`.

`extras/` builds a tiny standalone helper (`extras/version.cpp`) unrelated to the QML plugin — a version-reporting binary baked with `VERSION`/`GIT_REVISION` from CMake/git.

## Conventions

- Commit messages: `module: change` (lowercase subject, no leading capital — enforced by `check-pr-title.yml`). See allowed scopes in `.github/workflows/check-pr-title.yml` (shell modules like `bar`, `dashboard`, `launcher`, ... and plugin areas like `core`, `config`, `services`, `settings`, `wayland`/`plugins`, ...). Squash multiple changes into one commit when related; put the most impactful change in the subject and the rest in the body.
- QML property/signal/function ordering within an object follows the [Qt QML coding conventions](https://doc.qt.io/qt-6/qml-codingconventions.html) — enforced by `scripts/qml-lint-conventions.py`: id, then properties, then signals, then JS functions, then property bindings, then child objects, then component definitions, with blank lines between sections.
- No trailing whitespace; single space around operators (formatting is otherwise whatever `qmlformat`/`clang-format` produce — just run them).
- See `.github/CONTRIBUTING.md` for the full (short) contribution rules, including: PRs must be tested before submitting, and descriptions must explain what changed and how to use it.
