#include "ironlandpermissionprompt.hpp"

namespace caelestia::wayland {

IronlandPermissionPromptManager::IronlandPermissionPromptManager()
    : QWaylandClientExtensionTemplate<IronlandPermissionPromptManager>(2) {}

IronlandPermissionPromptManager* IronlandPermissionPromptManager::instance() {
    static IronlandPermissionPromptManager manager;
    return &manager;
}

void IronlandPermissionPromptManager::ironland_permission_prompt_manager_v1_show(
    uint32_t prompt_id, const QString& app_id, const QString& reason) {
    emit promptRequested(prompt_id, app_id, reason);
}

void IronlandPermissionPromptManager::ironland_permission_prompt_manager_v1_cancel(uint32_t prompt_id) {
    emit promptCancelled(prompt_id);
}

IronlandPermissionPrompt::IronlandPermissionPrompt(QObject* parent)
    : QObject(parent) {
    auto* manager = IronlandPermissionPromptManager::instance();
    connect(manager, &IronlandPermissionPromptManager::activeChanged, this, &IronlandPermissionPrompt::tryRegister);
    connect(
        manager, &IronlandPermissionPromptManager::promptRequested, this, &IronlandPermissionPrompt::promptRequested);
    connect(
        manager, &IronlandPermissionPromptManager::promptCancelled, this, &IronlandPermissionPrompt::promptCancelled);
    tryRegister();
}

void IronlandPermissionPrompt::answer(quint32 promptId, bool allowed) {
    auto* manager = IronlandPermissionPromptManager::instance();
    if (!manager->isActive()) {
        return;
    }

    manager->answer(promptId, allowed ? 1 : 0);
}

void IronlandPermissionPrompt::tryRegister() {
    auto* manager = IronlandPermissionPromptManager::instance();
    if (!manager->isActive()) {
        return;
    }

    // Idempotent on the wire (re-registering the same client just
    // replaces itself as the renderer, see the protocol doc), so no need
    // to track whether this already ran - simplest to just re-assert it
    // every time the extension (re)activates.
    manager->set_renderer();
}

} // namespace caelestia::wayland
