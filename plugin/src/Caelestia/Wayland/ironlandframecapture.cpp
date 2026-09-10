#include "ironlandframecapture.hpp"

namespace caelestia::wayland {

IronlandFrameCaptureManager::IronlandFrameCaptureManager()
    : QWaylandClientExtensionTemplate<IronlandFrameCaptureManager>(1) {}

IronlandFrameCaptureManager* IronlandFrameCaptureManager::instance() {
    static IronlandFrameCaptureManager manager;
    return &manager;
}

IronlandFrameCapture::IronlandFrameCapture(QObject* parent)
    : QObject(parent) {}

IronlandFrameCapture::~IronlandFrameCapture() {
    if (isInitialized()) {
        destroy();
    }
}

bool IronlandFrameCapture::capturing() const {
    return m_capturing;
}

QVariantList IronlandFrameCapture::frames() const {
    QVariantList list;
    list.reserve(m_frames.size());
    for (const auto& frame : m_frames) {
        list.append(frame);
    }
    return list;
}

void IronlandFrameCapture::capture(int frameCount) {
    auto* manager = IronlandFrameCaptureManager::instance();
    if (!manager->isActive()) {
        return;
    }

    if (isInitialized()) {
        destroy();
    }

    m_frameIndex.clear();
    m_frames.clear();
    m_capturing = true;
    emit capturingChanged();
    emit framesChanged();

    init(manager->capture(static_cast<uint32_t>(frameCount)));
}

int IronlandFrameCapture::entryFor(const QString& output, uint32_t frame_index) {
    const auto key = qMakePair(output, frame_index);
    const auto it = m_frameIndex.constFind(key);
    if (it != m_frameIndex.constEnd()) {
        return it.value();
    }

    QVariantMap entry;
    entry[QStringLiteral("output")] = output;
    entry[QStringLiteral("frameIndex")] = frame_index;
    entry[QStringLiteral("frameTimeUs")] = 0;
    entry[QStringLiteral("stutter")] = false;
    entry[QStringLiteral("stages")] = QVariantList();

    const int index = static_cast<int>(m_frames.size());
    m_frames.append(entry);
    m_frameIndex.insert(key, index);
    return index;
}

void IronlandFrameCapture::ironland_frame_capture_v1_stage(
    const QString& output, uint32_t frame_index, const QString& name, uint32_t start_us, uint32_t duration_us) {
    QVariantMap& entry = m_frames[entryFor(output, frame_index)];
    QVariantList stages = entry[QStringLiteral("stages")].toList();

    QVariantMap stage;
    stage[QStringLiteral("name")] = name;
    stage[QStringLiteral("startUs")] = start_us;
    stage[QStringLiteral("durationUs")] = duration_us;
    stages.append(stage);

    entry[QStringLiteral("stages")] = stages;
    emit framesChanged();
}

void IronlandFrameCapture::ironland_frame_capture_v1_frame(
    const QString& output, uint32_t frame_index, uint32_t frame_time_us, uint32_t stutter) {
    QVariantMap& entry = m_frames[entryFor(output, frame_index)];
    entry[QStringLiteral("frameTimeUs")] = frame_time_us;
    entry[QStringLiteral("stutter")] = stutter != 0;
    emit framesChanged();
}

void IronlandFrameCapture::ironland_frame_capture_v1_finished() {
    m_capturing = false;
    emit capturingChanged();
}

} // namespace caelestia::wayland
