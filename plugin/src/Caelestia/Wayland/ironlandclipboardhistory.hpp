#pragma once

#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <qbytearray.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qtmetamacros.h>
#include <qvariant.h>

#include "qwayland-ironland-clipboard-history-v1.h"

namespace caelestia::wayland {

// Registry-bound global for the `ironland-clipboard-history-v1` protocol
// (see plugin/protocols/ironland-clipboard-history-v1.xml). Not itself
// exposed to QML - IronlandClipboardHistory looks it up through instance().
//
// Binding this global alone is unrestricted (see the protocol doc), but
// receiving any `entry` requires this executable to be allowed through the
// compositor's own on-screen permission prompt (`ironland-permission-prompt-v1`,
// rendered and answered entirely compositor-side - no client, including this
// shell, can see or influence it) the first time this shell runs against a
// given compositor process.
class IronlandClipboardHistoryManager
    : public QWaylandClientExtensionTemplate<IronlandClipboardHistoryManager>,
      public QtWayland::ironland_clipboard_history_manager_v1 {
    Q_OBJECT

public:
    static IronlandClipboardHistoryManager* instance();

signals:
    void entryChanged(quint32 id, const QString& mimeTypes, const QString& preview);
    void entryThumbnail(quint32 id, quint32 width, quint32 height, const QByteArray& bytes);
    void entryRemoved(quint32 id);
    void cleared();
    void denied();

protected:
    void ironland_clipboard_history_manager_v1_entry(
        uint32_t id, const QString& mime_types, const QString& preview) override;
    void ironland_clipboard_history_manager_v1_thumbnail(
        uint32_t id, uint32_t width, uint32_t height, wl_array* bytes) override;
    void ironland_clipboard_history_manager_v1_removed(uint32_t id) override;
    void ironland_clipboard_history_manager_v1_cleared() override;
    void ironland_clipboard_history_manager_v1_denied() override;

private:
    IronlandClipboardHistoryManager();
};

// QML-facing, most-recent-first clipboard history model - suitable as a
// ListView/Repeater model directly (each entry: {id, mimeType, preview}).
// Maintains its own ordered copy of the compositor's history from
// `entry`/`removed`/`cleared` events (see the manager above), moving an
// existing id to the front instead of duplicating it on a repeat `entry` -
// mirroring the compositor-side semantics (see the protocol doc).
//
// Exactly one of these should exist for the whole shell - see
// services/ClipboardHistory.qml.
class IronlandClipboardHistory : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    // Set once if the compositor denies this executable clipboard-history
    // access (see `denied` in the protocol doc) - lets QML show something
    // instead of a silently-empty history.
    Q_PROPERTY(bool denied READ denied NOTIFY deniedChanged)

public:
    explicit IronlandClipboardHistory(QObject* parent = nullptr);

    [[nodiscard]] QVariantList entries() const;
    [[nodiscard]] bool denied() const;

    // Removes one entry (`id` from an `entries()` item's "id"). A no-op if
    // the manager isn't active.
    Q_INVOKABLE void remove(quint32 id);
    // Clears the entire history. A no-op if the manager isn't active.
    Q_INVOKABLE void removeAll();
    // Copies entry `id`'s full text to the system clipboard, reading it
    // back from the compositor via the protocol's `receive` request (the
    // `entries()` item only carries a truncated preview - see the protocol
    // doc for why). A no-op if `id` isn't a currently-known entry or the
    // manager isn't active.
    Q_INVOKABLE void restore(quint32 id);

signals:
    void entriesChanged();
    void deniedChanged();

private:
    struct Entry {
        quint32 id;
        QString mimeType;
        QString preview;
        // Only set for an image entry (its `thumbnail` event always follows
        // its `entry` event - see the protocol doc) - a
        // "data:image/png;base64,..." URI, directly usable as an
        // `Image.source`. Empty for a text entry.
        QString thumbnail;
    };

    QList<Entry> m_entries;
    bool m_denied = false;

    void upsert(quint32 id, const QString& mimeTypes, const QString& preview);
    void setThumbnail(quint32 id, const QByteArray& bytes);
};

} // namespace caelestia::wayland
