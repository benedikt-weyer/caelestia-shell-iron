#include "ironlandfocusgrab.hpp"

#include <QtGui/qpa/qplatformnativeinterface.h>
#include <qguiapplication.h>

namespace caelestia::wayland {

IronlandFocusGrabManager::IronlandFocusGrabManager()
    : QWaylandClientExtensionTemplate<IronlandFocusGrabManager>(1) {}

IronlandFocusGrabManager* IronlandFocusGrabManager::instance() {
    static IronlandFocusGrabManager manager;
    return &manager;
}

IronlandFocusGrab::IronlandFocusGrab(QObject* parent)
    : QObject(parent) {
    connect(IronlandFocusGrabManager::instance(), &IronlandFocusGrabManager::activeChanged, this,
        &IronlandFocusGrab::syncGrab);
}

IronlandFocusGrab::~IronlandFocusGrab() {
    if (isInitialized()) {
        destroy();
    }
}

bool IronlandFocusGrab::active() const {
    return m_active;
}

void IronlandFocusGrab::setActive(bool active) {
    if (m_active == active) {
        return;
    }

    m_active = active;
    emit activeChanged();
    syncGrab();
}

QWindow* IronlandFocusGrab::window() const {
    return m_window;
}

void IronlandFocusGrab::setWindow(QWindow* window) {
    if (m_window == window) {
        return;
    }

    m_window = window;
    emit windowChanged();
    syncGrab();
}

void IronlandFocusGrab::syncGrab() {
    if (!m_active) {
        if (isInitialized()) {
            destroy();
        }
        return;
    }

    if (isInitialized() || !m_window) {
        return;
    }

    auto* manager = IronlandFocusGrabManager::instance();
    if (!manager->isActive()) {
        return;
    }

    if (!m_window->handle()) {
        m_window->create();
    }

    auto* surface = static_cast<struct ::wl_surface*>(
        QGuiApplication::platformNativeInterface()->nativeResourceForWindow(
            QByteArrayLiteral("surface"), m_window));
    if (!surface) {
        return;
    }

    init(manager->grab(surface));
}

void IronlandFocusGrab::ironland_focus_grab_v1_cleared() {
    // The compositor only ever sends this once and then treats the grab as
    // inert (see the protocol doc) - destroy our side to match, before
    // telling QML, so a `cleared` handler that immediately sets
    // `active: false` doesn't try to destroy an already-cleared object.
    destroy();
    emit cleared();
}

} // namespace caelestia::wayland
