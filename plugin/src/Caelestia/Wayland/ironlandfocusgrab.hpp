#pragma once

#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <qobject.h>
#include <qpointer.h>
#include <qqmlintegration.h>
#include <qwindow.h>

#include "qwayland-ironland-focus-grab-v1.h"

namespace caelestia::wayland {

// Registry-bound global for the `ironland-focus-grab-v1` protocol (see
// plugin/protocols/ironland-focus-grab-v1.xml). Not itself exposed to QML -
// IronlandFocusGrab looks it up through instance().
class IronlandFocusGrabManager : public QWaylandClientExtensionTemplate<IronlandFocusGrabManager>,
                                  public QtWayland::ironland_focus_grab_manager_v1 {
    Q_OBJECT

public:
    static IronlandFocusGrabManager* instance();

private:
    IronlandFocusGrabManager();
};

// QML-facing grab, mirroring Quickshell.Hyprland's HyprlandFocusGrab, but
// over exactly one window (the protocol has no whitelist/commit dance - see
// its XML doc) instead of a list.
class IronlandFocusGrab : public QObject, public QtWayland::ironland_focus_grab_v1 {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QWindow* window READ window WRITE setWindow NOTIFY windowChanged)

public:
    explicit IronlandFocusGrab(QObject* parent = nullptr);
    ~IronlandFocusGrab() override;

    [[nodiscard]] bool active() const;
    void setActive(bool active);
    [[nodiscard]] QWindow* window() const;
    void setWindow(QWindow* window);

signals:
    void activeChanged();
    void windowChanged();
    void cleared();

protected:
    void ironland_focus_grab_v1_cleared() override;

private:
    bool m_active = false;
    QPointer<QWindow> m_window;

    // Starts the wire-level grab if `active` and `window` are both set and
    // it isn't already running; ends it (without emitting `cleared`, since
    // that's reserved for the compositor clearing it) if `active` went
    // false. A no-op whenever the preconditions for the state it's moving
    // to aren't met yet - the next relevant property change retries.
    void syncGrab();
};

} // namespace caelestia::wayland
