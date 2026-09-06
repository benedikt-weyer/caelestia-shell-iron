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

// QML-facing shortcut, mirroring Quickshell.Hyprland's GlobalShortcut: set
// `name` to match a key in the compositor's `[shortcuts]` config (as
// `"shortcut:<name>"`, see ironland-copositor's config.rs), then listen for
// `pressed`/`released`.
class IronlandShortcut : public QObject, public QtWayland::ironland_shortcut_v1 {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    // Stored but otherwise unused: kept only so QML written against
    // Quickshell.Hyprland's GlobalShortcut (which has this property, used
    // there for a shortcut cheatsheet) doesn't fail on an unknown property.
    Q_PROPERTY(QString description MEMBER m_description)

public:
    explicit IronlandShortcut(QObject* parent = nullptr);
    ~IronlandShortcut() override;

    [[nodiscard]] QString name() const;
    void setName(const QString& name);

signals:
    void nameChanged();
    void pressed();
    void released();

protected:
    void ironland_shortcut_v1_pressed() override;
    void ironland_shortcut_v1_released() override;

private:
    QString m_name;
    QString m_description;

    // Registers this shortcut with the manager if it hasn't been already,
    // `m_name` is set, and the manager is active - otherwise a no-op that
    // leaves it to try again on the next name change or activeChanged().
    void tryRegister();
};

} // namespace caelestia::wayland
