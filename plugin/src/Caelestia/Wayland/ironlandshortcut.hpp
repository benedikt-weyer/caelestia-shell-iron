#pragma once

#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <qobject.h>
#include <qqmlintegration.h>

#include "qwayland-ironland-shortcuts-v1.h"

namespace caelestia::wayland {

// Registry-bound global for the `ironland-shortcuts-v1` protocol (see
// plugin/protocols/ironland-shortcuts-v1.xml). Not itself exposed to QML -
// IronlandShortcut looks it up through instance() once it needs to
// register, and retries on activeChanged() if the compositor hadn't
// advertised the global yet (e.g. the shell starting before the
// compositor's socket is ready).
class IronlandShortcutsManager : public QWaylandClientExtensionTemplate<IronlandShortcutsManager>,
                                  public QtWayland::ironland_shortcuts_manager_v1 {
    Q_OBJECT

public:
    static IronlandShortcutsManager* instance();

private:
    IronlandShortcutsManager();
};

// QML-facing shortcut, mirroring Quickshell.Hyprland's GlobalShortcut. Two
// mutually exclusive ways to trigger it - `name` takes priority if both are
// set:
//
// - `name`: matches a key in the compositor's `[shortcuts]` config (as
//   `"shortcut:<name>"`, see ironland-compositor's config.rs) - for
//   shortcuts the user is meant to be able to rebind.
// - `modifiers`/`key`: a raw trigger this component claims for itself via
//   the protocol's `bind` request (version 2+), with no compositor config
//   involved at all - for a keybind the shell owns outright (e.g. Super+V
//   for the clipboard history overlay, see `modules/Shortcuts.qml`). `key`
//   is a single printable ASCII character (letters, digits, punctuation);
//   `modifiers` is any of "ctrl", "alt", "shift", "super" (an alias for the
//   protocol's "logo").
//
// Either way, listen for `pressed`/`released`.
class IronlandShortcut : public QObject, public QtWayland::ironland_shortcut_v1 {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QStringList modifiers READ modifiers WRITE setModifiers NOTIFY modifiersChanged)
    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY keyChanged)
    // Stored but otherwise unused: kept only so QML written against
    // Quickshell.Hyprland's GlobalShortcut (which has this property, used
    // there for a shortcut cheatsheet) doesn't fail on an unknown property.
    Q_PROPERTY(QString description MEMBER m_description)

public:
    explicit IronlandShortcut(QObject* parent = nullptr);
    ~IronlandShortcut() override;

    [[nodiscard]] QString name() const;
    void setName(const QString& name);

    [[nodiscard]] QStringList modifiers() const;
    void setModifiers(const QStringList& modifiers);

    [[nodiscard]] QString key() const;
    void setKey(const QString& key);

signals:
    void nameChanged();
    void modifiersChanged();
    void keyChanged();
    // `output` is the wl_output name (e.g. "eDP-1") the pointer was over
    // when the shortcut fired, or an empty string if the compositor
    // couldn't determine one.
    void pressed(const QString& output);
    void released();

protected:
    void ironland_shortcut_v1_pressed(const QString& output) override;
    void ironland_shortcut_v1_released() override;

private:
    QString m_name;
    QStringList m_modifiers;
    QString m_key;
    QString m_description;

    // Registers this shortcut with the manager if it hasn't been already
    // and the manager is active, preferring `m_name` (via `get_shortcut`)
    // over `m_modifiers`/`m_key` (via `bind`) when both are usable -
    // otherwise a no-op that leaves it to try again on the next property
    // change or activeChanged().
    void tryRegister();
};

} // namespace caelestia::wayland
