#pragma once

#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qtmetamacros.h>
#include <qvariant.h>

#include "qwayland-ironland-capture-permissions-v1.h"

namespace caelestia::wayland {

// Registry-bound global for the `ironland-capture-permissions-v1` protocol
// (see plugin/protocols/ironland-capture-permissions-v1.xml). Not itself
// exposed to QML - IronlandCapturePermissions looks it up through
// instance().
class IronlandCapturePermissionsManager
    : public QWaylandClientExtensionTemplate<IronlandCapturePermissionsManager>,
      public QtWayland::ironland_capture_permissions_manager_v1 {
    Q_OBJECT

public:
    static IronlandCapturePermissionsManager* instance();

signals:
    void entryChanged(const QString& subject, bool allowed);
    void entryRemoved(const QString& subject);

protected:
    void ironland_capture_permissions_manager_v1_entry(const QString& subject, uint32_t allowed) override;
    void ironland_capture_permissions_manager_v1_removed(const QString& subject) override;

private:
    IronlandCapturePermissionsManager();
};

// QML-facing view of the compositor's screen-capture grant table (see
// `crate::screencopy`'s module doc in the compositor for what's actually
// in it) - in practice consumed by a Nexus settings page to show and let
// the user manage which executables can capture the screen.
//
// Exactly one of these should exist for the whole shell (mirrors
// IronlandPermissionPrompt) - it maintains its own local copy of the table
// from `entry`/`removed` events, kept in sync for as long as the
// underlying manager global stays bound.
class IronlandCapturePermissions : public QObject {
    Q_OBJECT
    QML_ELEMENT

    // List of {subject: string, allowed: bool} objects, one per grant
    // currently on file - suitable as a QML ListView/Repeater model
    // directly.
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)

public:
    explicit IronlandCapturePermissions(QObject* parent = nullptr);

    [[nodiscard]] QVariantList entries() const;

    // Grants or revokes capture access for `subject` (an executable path,
    // exactly as given by an `entries()` item's "subject").
    Q_INVOKABLE void setGrant(const QString& subject, bool allowed);
    // Removes `subject`'s decision entirely - the next time it tries to
    // capture, it's prompted again from scratch.
    Q_INVOKABLE void forget(const QString& subject);

signals:
    void entriesChanged();

private:
    QMap<QString, bool> m_grants;
};

} // namespace caelestia::wayland
