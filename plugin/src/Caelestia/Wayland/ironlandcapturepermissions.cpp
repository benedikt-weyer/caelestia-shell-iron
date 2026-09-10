#include "ironlandcapturepermissions.hpp"

namespace caelestia::wayland {

IronlandCapturePermissionsManager::IronlandCapturePermissionsManager()
    : QWaylandClientExtensionTemplate<IronlandCapturePermissionsManager>(1) {}

IronlandCapturePermissionsManager* IronlandCapturePermissionsManager::instance() {
    static IronlandCapturePermissionsManager manager;
    return &manager;
}

void IronlandCapturePermissionsManager::ironland_capture_permissions_manager_v1_entry(
    const QString& subject, uint32_t allowed) {
    emit entryChanged(subject, allowed != 0);
}

void IronlandCapturePermissionsManager::ironland_capture_permissions_manager_v1_removed(
    const QString& subject) {
    emit entryRemoved(subject);
}

IronlandCapturePermissions::IronlandCapturePermissions(QObject* parent)
    : QObject(parent) {
    auto* manager = IronlandCapturePermissionsManager::instance();
    connect(manager, &IronlandCapturePermissionsManager::entryChanged, this,
        [this](const QString& subject, bool allowed) {
            m_grants[subject] = allowed;
            emit entriesChanged();
        });
    connect(manager, &IronlandCapturePermissionsManager::entryRemoved, this,
        [this](const QString& subject) {
            if (m_grants.remove(subject) > 0) {
                emit entriesChanged();
            }
        });
}

QVariantList IronlandCapturePermissions::entries() const {
    QVariantList list;
    list.reserve(m_grants.size());
    for (auto it = m_grants.constBegin(); it != m_grants.constEnd(); ++it) {
        QVariantMap entry;
        entry[QStringLiteral("subject")] = it.key();
        entry[QStringLiteral("allowed")] = it.value();
        list.append(entry);
    }
    return list;
}

void IronlandCapturePermissions::setGrant(const QString& subject, bool allowed) {
    auto* manager = IronlandCapturePermissionsManager::instance();
    if (!manager->isActive()) {
        return;
    }

    manager->set_grant(subject, allowed ? 1 : 0);
}

void IronlandCapturePermissions::forget(const QString& subject) {
    auto* manager = IronlandCapturePermissionsManager::instance();
    if (!manager->isActive()) {
        return;
    }

    manager->forget(subject);
}

} // namespace caelestia::wayland
