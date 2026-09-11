#include "ironlandshortcut.hpp"

namespace caelestia::wayland {

namespace {

// Decodes `modifiers` (any of "ctrl"/"alt"/"shift"/"super", case-
// insensitive) into the protocol's bitmask (1=ctrl, 2=alt, 4=shift, 8=logo).
// Unrecognised entries are silently ignored.
uint32_t modifiersBitmask(const QStringList& modifiers) {
    uint32_t bits = 0;
    for (const auto& mod : modifiers) {
        const auto lower = mod.toLower();
        if (lower == QLatin1String("ctrl") || lower == QLatin1String("control")) {
            bits |= 1;
        } else if (lower == QLatin1String("alt")) {
            bits |= 2;
        } else if (lower == QLatin1String("shift")) {
            bits |= 4;
        } else if (lower == QLatin1String("super") || lower == QLatin1String("logo")
            || lower == QLatin1String("meta")) {
            bits |= 8;
        }
    }
    return bits;
}

// xkbcommon keysyms for printable ASCII (space through tilde) are numerically
// identical to their Latin-1 code point - true for every letter, digit and
// punctuation character `key` is documented to accept - so this needs no
// xkbcommon dependency of its own. Returns 0 (an invalid keysym, never
// requested by any real key) for anything else, including a multi-character
// string.
uint32_t keysymForKey(const QString& key) {
    if (key.size() != 1) {
        return 0;
    }
    const auto ch = key.at(0).toLower().unicode();
    return (ch >= 0x20 && ch <= 0x7e) ? static_cast<uint32_t>(ch) : 0;
}

} // namespace

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

QStringList IronlandShortcut::modifiers() const {
    return m_modifiers;
}

void IronlandShortcut::setModifiers(const QStringList& modifiers) {
    if (m_modifiers == modifiers) {
        return;
    }

    m_modifiers = modifiers;
    emit modifiersChanged();
    tryRegister();
}

QString IronlandShortcut::key() const {
    return m_key;
}

void IronlandShortcut::setKey(const QString& key) {
    if (m_key == key) {
        return;
    }

    m_key = key;
    emit keyChanged();
    tryRegister();
}

void IronlandShortcut::tryRegister() {
    if (isInitialized()) {
        return;
    }

    auto* manager = IronlandShortcutsManager::instance();
    if (!manager->isActive()) {
        return;
    }

    if (!m_name.isEmpty()) {
        init(manager->get_shortcut(m_name));
        return;
    }

    if (const auto keysym = keysymForKey(m_key); keysym != 0) {
        // Qualified: `QWaylandClientExtensionTemplate` has its own,
        // unrelated `bind()` (for the wl_registry global itself), which
        // would otherwise make this call ambiguous.
        init(manager->QtWayland::ironland_shortcuts_manager_v1::bind(
            modifiersBitmask(m_modifiers), keysym));
    }
}

void IronlandShortcut::ironland_shortcut_v1_pressed(const QString& output) {
    emit pressed(output);
}

void IronlandShortcut::ironland_shortcut_v1_released() {
    emit released();
}

} // namespace caelestia::wayland
