#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qtmetamacros.h>

#include <QtWaylandClient/QWaylandClientExtensionTemplate>

#include "qwayland-ironland-permission-prompt-v1.h"

namespace caelestia::wayland {

// Registry-bound global for the `ironland-permission-prompt-v1` protocol
// (see plugin/protocols/ironland-permission-prompt-v1.xml). Not itself
// exposed to QML - IronlandPermissionPrompt looks it up through instance().
//
// This binds version 2, the version that added the *renderer* role
// (`set_renderer`/`show`/`cancel`/`answer`) this shell uses - see the
// protocol doc for why that's a separate role from the *requester* one
// `ironland-portal-screenshot` uses (`prompt`), which this shell never
// calls.
class IronlandPermissionPromptManager : public QWaylandClientExtensionTemplate<IronlandPermissionPromptManager>,
                                        public QtWayland::ironland_permission_prompt_manager_v1 {
    Q_OBJECT

public:
    static IronlandPermissionPromptManager* instance();

signals:
    // Forwarded straight from the wire events - see IronlandPermissionPrompt
    // for the QML-facing signals these actually drive.
    void promptRequested(quint32 promptId, const QString& appId, const QString& reason);
    void promptCancelled(quint32 promptId);

protected:
    void ironland_permission_prompt_manager_v1_show(
        uint32_t prompt_id, const QString& app_id, const QString& reason) override;
    void ironland_permission_prompt_manager_v1_cancel(uint32_t prompt_id) override;

private:
    IronlandPermissionPromptManager();
};

// QML-facing singleton-ish listener: registers this shell as the
// compositor's permission-prompt renderer (see the protocol doc) as soon as
// the global is available, forwards every `show`/`cancel` as a QML signal,
// and lets QML answer via `answer()`.
//
// Exactly one of these should exist for the whole shell (see
// modules/elevation/Elevation.qml) - a second instance would just register
// itself as the renderer again, replacing the first (harmless per the
// protocol doc, but pointless).
class IronlandPermissionPrompt : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit IronlandPermissionPrompt(QObject* parent = nullptr);

    // Answers the prompt named `promptId` (from a prior `promptRequested`).
    // A no-op if it's already been answered/cancelled.
    Q_INVOKABLE void answer(quint32 promptId, bool allowed);

signals:
    void promptRequested(quint32 promptId, const QString& appId, const QString& reason);
    void promptCancelled(quint32 promptId);

private:
    // Calls set_renderer() once the manager is active; retried on
    // activeChanged() the same way IronlandShortcut retries registration,
    // in case this shell starts before the compositor's socket is ready.
    void tryRegister();
};

} // namespace caelestia::wayland
