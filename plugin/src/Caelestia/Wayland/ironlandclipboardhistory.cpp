#include "ironlandclipboardhistory.hpp"

#include <algorithm>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>

#include <QByteArray>
#include <QClipboard>
#include <QGuiApplication>
#include <QImage>
#include <QList>
#include <QSocketNotifier>

namespace caelestia::wayland {

IronlandClipboardHistoryManager::IronlandClipboardHistoryManager()
    : QWaylandClientExtensionTemplate<IronlandClipboardHistoryManager>(2) {}

IronlandClipboardHistoryManager* IronlandClipboardHistoryManager::instance() {
    static IronlandClipboardHistoryManager manager;
    return &manager;
}

void IronlandClipboardHistoryManager::ironland_clipboard_history_manager_v1_entry(
    uint32_t id, const QString& mime_types, const QString& preview) {
    emit entryChanged(id, mime_types, preview);
}

void IronlandClipboardHistoryManager::ironland_clipboard_history_manager_v1_thumbnail(
    uint32_t id, uint32_t width, uint32_t height, wl_array* bytes) {
    emit entryThumbnail(id, width, height,
        QByteArray(static_cast<const char*>(bytes->data), static_cast<qsizetype>(bytes->size)));
}

void IronlandClipboardHistoryManager::ironland_clipboard_history_manager_v1_removed(uint32_t id) {
    emit entryRemoved(id);
}

void IronlandClipboardHistoryManager::ironland_clipboard_history_manager_v1_cleared() {
    emit cleared();
}

void IronlandClipboardHistoryManager::ironland_clipboard_history_manager_v1_denied() {
    emit denied();
}

IronlandClipboardHistory::IronlandClipboardHistory(QObject* parent)
    : QObject(parent) {
    auto* manager = IronlandClipboardHistoryManager::instance();
    connect(manager, &IronlandClipboardHistoryManager::entryChanged, this,
        [this](quint32 id, const QString& mimeTypes, const QString& preview) {
            upsert(id, mimeTypes, preview);
        });
    connect(manager, &IronlandClipboardHistoryManager::entryThumbnail, this,
        [this](quint32 id, quint32, quint32, const QByteArray& bytes) { setThumbnail(id, bytes); });
    connect(manager, &IronlandClipboardHistoryManager::entryRemoved, this, [this](quint32 id) {
        const auto removed = m_entries.removeIf([id](const Entry& e) { return e.id == id; });
        if (removed > 0) {
            emit entriesChanged();
        }
    });
    connect(manager, &IronlandClipboardHistoryManager::cleared, this, [this]() {
        if (!m_entries.isEmpty()) {
            m_entries.clear();
            emit entriesChanged();
        }
    });
    connect(manager, &IronlandClipboardHistoryManager::denied, this, [this]() {
        m_denied = true;
        emit deniedChanged();
    });
}

void IronlandClipboardHistory::upsert(quint32 id, const QString& mimeTypes, const QString& preview) {
    // `mimeTypes` is space-separated (see the protocol doc); this shell
    // only ever needs the first (and, in practice, only) one, to name it
    // back in `receive`.
    const auto mimeType = mimeTypes.section(QLatin1Char(' '), 0, 0);

    m_entries.removeIf([id](const Entry& e) { return e.id == id; });
    m_entries.prepend(Entry{id, mimeType, preview, QString()});
    emit entriesChanged();
}

void IronlandClipboardHistory::setThumbnail(quint32 id, const QByteArray& bytes) {
    // The `thumbnail` event always immediately follows the `entry` event it
    // belongs to (see the protocol doc), so the entry is always already
    // upserted by the time this runs.
    const auto it = std::find_if(m_entries.begin(), m_entries.end(), [id](const Entry& e) { return e.id == id; });
    if (it == m_entries.end()) {
        return;
    }

    it->thumbnail = QStringLiteral("data:image/png;base64,") + QString::fromLatin1(bytes.toBase64());
    emit entriesChanged();
}

QVariantList IronlandClipboardHistory::entries() const {
    QVariantList list;
    list.reserve(m_entries.size());
    for (const auto& entry : m_entries) {
        QVariantMap item;
        item[QStringLiteral("id")] = entry.id;
        item[QStringLiteral("mimeType")] = entry.mimeType;
        item[QStringLiteral("preview")] = entry.preview;
        item[QStringLiteral("thumbnail")] = entry.thumbnail;
        list.append(item);
    }
    return list;
}

bool IronlandClipboardHistory::denied() const {
    return m_denied;
}

void IronlandClipboardHistory::remove(quint32 id) {
    auto* manager = IronlandClipboardHistoryManager::instance();
    if (!manager->isActive()) {
        return;
    }

    manager->remove(id);
}

void IronlandClipboardHistory::removeAll() {
    auto* manager = IronlandClipboardHistoryManager::instance();
    if (!manager->isActive()) {
        return;
    }

    manager->remove_all();
}

void IronlandClipboardHistory::restore(quint32 id) {
    auto* manager = IronlandClipboardHistoryManager::instance();
    if (!manager->isActive()) {
        return;
    }

    QString mimeType;
    for (const auto& entry : m_entries) {
        if (entry.id == id) {
            mimeType = entry.mimeType;
            break;
        }
    }
    if (mimeType.isEmpty()) {
        return;
    }

    int fds[2];
    if (pipe2(fds, O_CLOEXEC | O_NONBLOCK) != 0) {
        return;
    }
    const auto readFd = fds[0];
    const auto writeFd = fds[1];

    manager->receive(id, mimeType, writeFd);
    close(writeFd);

    // Reads asynchronously and sets the system clipboard once the
    // compositor has closed its end (see the protocol doc's `receive`
    // description) - mirrors the non-blocking read `crate::clipboard` does
    // compositor-side for the same reason: never block the event loop on
    // however long the other end takes.
    auto* buffer = new QByteArray();
    auto* notifier = new QSocketNotifier(readFd, QSocketNotifier::Read, this);
    connect(notifier, &QSocketNotifier::activated, notifier, [notifier, readFd, buffer, mimeType]() {
        char chunk[8192];
        const auto n = read(readFd, chunk, sizeof(chunk));
        if (n > 0) {
            buffer->append(chunk, n);
            return;
        }
        // n == 0 (EOF) or n < 0 with anything other than "try again" both
        // end the read - either way there's nothing more usable to wait
        // for.
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            return;
        }
        notifier->setEnabled(false);
        if (!buffer->isEmpty()) {
            if (mimeType.startsWith(QStringLiteral("image/"))) {
                QImage image;
                if (image.loadFromData(*buffer)) {
                    QGuiApplication::clipboard()->setImage(image);
                }
            } else {
                QGuiApplication::clipboard()->setText(QString::fromUtf8(*buffer));
            }
        }
        close(readFd);
        delete buffer;
        notifier->deleteLater();
    });
}

} // namespace caelestia::wayland
