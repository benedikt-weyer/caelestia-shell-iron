#pragma once

#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariant.h>
#include <qvector.h>

#include <QtWaylandClient/QWaylandClientExtensionTemplate>

#include "qwayland-ironland-frame-capture-v1.h"

namespace caelestia::wayland {

// Registry-bound global for the `ironland-frame-capture-v1` protocol (see
// plugin/protocols/ironland-frame-capture-v1.xml). Not itself exposed to
// QML - IronlandFrameCapture looks it up through instance().
class IronlandFrameCaptureManager : public QWaylandClientExtensionTemplate<IronlandFrameCaptureManager>,
                                    public QtWayland::ironland_frame_capture_manager_v1 {
    Q_OBJECT

public:
    static IronlandFrameCaptureManager* instance();

private:
    IronlandFrameCaptureManager();
};

// QML-facing capture session, backing Nexus's Performance page: a
// diagnostic aid, not a permanent user-facing feature - see the protocol
// XML's own description for why it needs no permission gating.
//
// One instance covers one `capture()` call at a time; calling it again
// while already capturing discards whatever was collected so far and
// starts over (matches a button that just says "Capture next N frames").
class IronlandFrameCapture : public QObject, public QtWayland::ironland_frame_capture_v1 {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool capturing READ capturing NOTIFY capturingChanged)
    // List of {output, frameIndex, frameTimeUs, stutter, stages: [{name,
    // startUs, durationUs}]} objects, one per (output, frameIndex) pair
    // reported so far - suitable as a QML model directly, and as the
    // source for a flame graph / clipboard export once `capturing` goes
    // false.
    Q_PROPERTY(QVariantList frames READ frames NOTIFY framesChanged)

public:
    explicit IronlandFrameCapture(QObject* parent = nullptr);
    ~IronlandFrameCapture() override;

    [[nodiscard]] bool capturing() const;
    [[nodiscard]] QVariantList frames() const;

    // Starts capturing `frameCount` frames on every currently live output
    // (see the protocol request's own doc) - discards any previous run's
    // data immediately.
    Q_INVOKABLE void capture(int frameCount);

signals:
    void capturingChanged();
    void framesChanged();

protected:
    void ironland_frame_capture_v1_stage(const QString& output, uint32_t frame_index, const QString& name,
        uint32_t start_us, uint32_t duration_us) override;
    void ironland_frame_capture_v1_frame(
        const QString& output, uint32_t frame_index, uint32_t frame_time_us, uint32_t stutter) override;
    void ironland_frame_capture_v1_finished() override;

private:
    // Index into m_frames for a given (output, frame_index) pair, created
    // on that pair's first `stage`/`frame` event - preserves the order
    // frames were first reported in, which is what a flame graph wants to
    // render in.
    QHash<QPair<QString, uint32_t>, int> m_frameIndex;
    QVector<QVariantMap> m_frames;
    bool m_capturing = false;

    // Finds (creating if needed) `m_frames`' entry for `(output,
    // frame_index)`, returning its index.
    int entryFor(const QString& output, uint32_t frame_index);
};

} // namespace caelestia::wayland
