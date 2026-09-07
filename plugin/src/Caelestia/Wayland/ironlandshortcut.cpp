#include "ironlandshortcut.hpp"

namespace caelestia::wayland {

IronlandShortcutsManager::IronlandShortcutsManager()
    : QWaylandClientExtensionTemplate<IronlandShortcutsManager>(2) {}

IronlandShortcutsManager* IronlandShortcutsManager::instance() {
    static IronlandShortcutsManager manager;
    return &manager;
}

IronlandShortcut::IronlandShortcut(QObject* parent)
    : QObject(parent) {
    connect(IronlandShortcutsManager::instance(), &IronlandShortcutsManager::activeChanged, this,
        &IronlandShortcut::tryRegister);
}

IronlandShortcut::~IronlandShortcut() {
    if (isInitialized()) {
        destroy();
    }
}

QString IronlandShortcut::name() const {
    return m_name;
}

void IronlandShortcut::setName(const QString& name) {
    if (m_name == name) {
        return;
    }

    m_name = name;
    emit nameChanged();
    tryRegister();
}

void IronlandShortcut::tryRegister() {
    if (isInitialized() || m_name.isEmpty()) {
        return;
    }

    auto* manager = IronlandShortcutsManager::instance();
    if (!manager->isActive()) {
        return;
    }

    init(manager->get_shortcut(m_name));
}

void IronlandShortcut::ironland_shortcut_v1_pressed(const QString& output) {
    emit pressed(output);
}

void IronlandShortcut::ironland_shortcut_v1_released() {
    emit released();
}

} // namespace caelestia::wayland
