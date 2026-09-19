#include "nixbackendclient.hpp"

#include <chrono>
#include <functional>
#include <mutex>
#include <thread>

#include <grpcpp/grpcpp.h>

#include <qmetaobject.h>
#include <qprocess.h>

#include "nix_backend.grpc.pb.h"

namespace caelestia::services {

using Qt::StringLiterals::operator""_s;

namespace {

namespace pb = caelestia::nixbackend::v1;

using StreamStarter =
    std::function<std::unique_ptr<grpc::ClientReaderInterface<pb::ProgressEvent>>(pb::NixBackend::Stub*, grpc::ClientContext*)>;

QString socketPath() {
    const QByteArray override = qgetenv("NIX_BACKEND_SOCKET");
    if (!override.isEmpty()) {
        return QString::fromLocal8Bit(override);
    }

    QString runtimeDir = QString::fromLocal8Bit(qgetenv("XDG_RUNTIME_DIR"));
    if (runtimeDir.isEmpty()) {
        runtimeDir = u"/tmp"_s;
    }
    return runtimeDir + u"/nix-backend-generic.sock"_s;
}

pb::RebuildMode toProtoMode(NixBackendClient::RebuildMode mode) {
    switch (mode) {
        case NixBackendClient::RebuildMode::Boot:
            return pb::BOOT;
        case NixBackendClient::RebuildMode::Test:
            return pb::TEST;
        case NixBackendClient::RebuildMode::Switch:
            return pb::SWITCH;
    }
    return pb::SWITCH;
}

NixBackendClient::Phase toClientPhase(pb::EventPhase phase) {
    return static_cast<NixBackendClient::Phase>(static_cast<quint8>(phase));
}

void fillTarget(pb::SystemTarget* target, const QString& configDir, const QString& hostName) {
    target->set_config_dir(configDir.toStdString());
    target->set_host_name(hostName.toStdString());
}

// Waits up to ~5s for the daemon to accept a connection, spawning it
// (expected on PATH, see nix/default.nix) once if nothing answers straight
// away - so the shell works without the user starting a service by hand.
std::shared_ptr<grpc::Channel> connectOrSpawn(const QString& path) {
    const std::string target = "unix://" + path.toStdString();

    // A unix socket path isn't a valid HTTP/2 ":authority", and grpc-core
    // (unlike a tonic/hyper client) derives one from it by default anyway -
    // the server then rejects the request outright (RST_STREAM). Pin a
    // fixed, always-valid authority instead; its value is never checked
    // against anything since the server is only ever reached over this
    // unix socket.
    grpc::ChannelArguments args;
    args.SetString(GRPC_ARG_DEFAULT_AUTHORITY, "localhost");
    auto channel = grpc::CreateCustomChannel(target, grpc::InsecureChannelCredentials(), args);

    bool spawned = false;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while (std::chrono::steady_clock::now() < deadline) {
        if (channel->WaitForConnected(std::chrono::system_clock::now() + std::chrono::milliseconds(200))) {
            return channel;
        }

        if (!spawned) {
            spawned = true;
            QProcess::startDetached(u"nix-backend-generic"_s, {});
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    // Not connected - the RPC below will fail with UNAVAILABLE, surfaced to
    // the caller as lastError/finished(false) same as any other RPC error.
    return channel;
}

} // namespace

struct NixBackendClient::Impl {
    std::mutex mutex;
    std::thread worker;
    std::shared_ptr<grpc::ClientContext> context; // guarded by mutex; set while a call is in flight

    ~Impl() {
        {
            const std::lock_guard lock(mutex);
            if (context) {
                context->TryCancel();
            }
        }
        if (worker.joinable()) {
            worker.join();
        }
    }

    // Drains a ProgressEvent stream on the calling (worker) thread, posting
    // each event and the final status back to `self`'s thread. Nested
    // classes have access to the enclosing class's private members (incl.
    // through a pointer), which is what lets this call self's private
    // setters directly instead of needing a friend declaration.
    void runStream(NixBackendClient* self, std::unique_ptr<grpc::ClientReaderInterface<pb::ProgressEvent>> reader) {
        pb::ProgressEvent event;
        while (reader->Read(&event)) {
            const NixBackendClient::Phase phase = toClientPhase(event.phase());
            const QString message = QString::fromStdString(event.message());
            const bool isError = event.is_error();
            const qreal fraction = event.fraction_done();

            QMetaObject::invokeMethod(
                self,
                [self, phase, message, isError, fraction]() {
                    self->setPhase(phase);
                    if (fraction >= 0.0) {
                        self->setFractionDone(fraction);
                    }
                    if (!message.isEmpty()) {
                        self->setStatusMessage(message);
                        emit self->lineLogged(message, isError);
                    }
                    if (isError) {
                        self->setLastError(message);
                    }
                },
                Qt::QueuedConnection);
        }

        const grpc::Status status = reader->Finish();

        {
            const std::lock_guard lock(mutex);
            context.reset();
        }

        const bool success = status.ok();
        const QString errorText = success ? QString() : QString::fromStdString(status.error_message());

        QMetaObject::invokeMethod(
            self,
            [self, success, errorText]() {
                if (!success && !errorText.isEmpty()) {
                    self->setLastError(errorText);
                    emit self->lineLogged(errorText, true);
                }
                self->setRunning(false);
                emit self->finished(success);
            },
            Qt::QueuedConnection);
    }
};

NixBackendClient::NixBackendClient(QObject* parent) : QObject(parent), m_impl(std::make_unique<Impl>()) {}

NixBackendClient::~NixBackendClient() = default;

bool NixBackendClient::running() const {
    return m_running;
}

NixBackendClient::Phase NixBackendClient::phase() const {
    return m_phase;
}

qreal NixBackendClient::fractionDone() const {
    return m_fractionDone;
}

QString NixBackendClient::statusMessage() const {
    return m_statusMessage;
}

QString NixBackendClient::lastError() const {
    return m_lastError;
}

bool NixBackendClient::flakeHasGitHistory() const {
    return m_flakeHasGitHistory;
}

QString NixBackendClient::flakeLastModified() const {
    return m_flakeLastModified;
}

QString NixBackendClient::flakeLastCommitSubject() const {
    return m_flakeLastCommitSubject;
}

QString NixBackendClient::flakeLastCommitHash() const {
    return m_flakeLastCommitHash;
}

void NixBackendClient::setRunning(bool value) {
    if (m_running == value) {
        return;
    }
    m_running = value;
    emit runningChanged();
}

void NixBackendClient::setPhase(Phase value) {
    if (m_phase == value) {
        return;
    }
    m_phase = value;
    emit phaseChanged();
}

void NixBackendClient::setFractionDone(qreal value) {
    if (qFuzzyCompare(m_fractionDone + 1.0, value + 1.0)) {
        return;
    }
    m_fractionDone = value;
    emit fractionDoneChanged();
}

void NixBackendClient::setStatusMessage(const QString& value) {
    if (m_statusMessage == value) {
        return;
    }
    m_statusMessage = value;
    emit statusMessageChanged();
}

void NixBackendClient::setLastError(const QString& value) {
    if (m_lastError == value) {
        return;
    }
    m_lastError = value;
    emit lastErrorChanged();
}

void NixBackendClient::updateFlake(const QString& configDir, const QString& hostName) {
    if (m_running) {
        return;
    }

    auto request = std::make_shared<pb::UpdateFlakeRequest>();
    fillTarget(request->mutable_target(), configDir, hostName);

    if (m_impl->worker.joinable()) {
        m_impl->worker.join(); // Previous call already finished; reap it before reusing the slot.
    }

    setRunning(true);
    setPhase(Phase::Idle);
    setFractionDone(-1.0);
    setStatusMessage(QString());
    setLastError(QString());

    const QString path = socketPath();
    Impl* impl = m_impl.get();

    m_impl->worker = std::thread([this, impl, request, path]() {
        auto channel = connectOrSpawn(path);
        auto stub = pb::NixBackend::NewStub(channel);

        auto context = std::make_shared<grpc::ClientContext>();
        {
            const std::lock_guard lock(impl->mutex);
            impl->context = context;
        }

        auto reader = stub->UpdateFlake(context.get(), *request);
        impl->runStream(this, std::move(reader));
    });
}

void NixBackendClient::rebuild(const QString& configDir, const QString& hostName, RebuildMode mode) {
    if (m_running) {
        return;
    }

    auto request = std::make_shared<pb::RebuildRequest>();
    fillTarget(request->mutable_target(), configDir, hostName);
    request->set_mode(toProtoMode(mode));

    if (m_impl->worker.joinable()) {
        m_impl->worker.join();
    }

    setRunning(true);
    setPhase(Phase::Idle);
    setFractionDone(-1.0);
    setStatusMessage(QString());
    setLastError(QString());

    const QString path = socketPath();
    Impl* impl = m_impl.get();

    m_impl->worker = std::thread([this, impl, request, path]() {
        auto channel = connectOrSpawn(path);
        auto stub = pb::NixBackend::NewStub(channel);

        auto context = std::make_shared<grpc::ClientContext>();
        {
            const std::lock_guard lock(impl->mutex);
            impl->context = context;
        }

        auto reader = stub->Rebuild(context.get(), *request);
        impl->runStream(this, std::move(reader));
    });
}

void NixBackendClient::refreshFlakeStatus(const QString& configDir, const QString& hostName) {
    auto request = std::make_shared<pb::FlakeStatusRequest>();
    fillTarget(request->mutable_target(), configDir, hostName);

    const QString path = socketPath();

    std::thread([this, request, path]() {
        auto channel = connectOrSpawn(path);
        auto stub = pb::NixBackend::NewStub(channel);

        grpc::ClientContext context;
        pb::FlakeStatusReply reply;
        const grpc::Status status = stub->GetFlakeStatus(&context, *request, &reply);
        if (!status.ok()) {
            return;
        }

        const bool hasHistory = reply.has_git_history();
        const QString modified = QString::fromStdString(reply.last_modified_iso8601());
        const QString subject = QString::fromStdString(reply.last_commit_subject());
        const QString hash = QString::fromStdString(reply.last_commit_hash());

        QMetaObject::invokeMethod(
            this,
            [this, hasHistory, modified, subject, hash]() {
                const bool changed = m_flakeHasGitHistory != hasHistory || m_flakeLastModified != modified
                    || m_flakeLastCommitSubject != subject || m_flakeLastCommitHash != hash;
                if (!changed) {
                    return;
                }

                m_flakeHasGitHistory = hasHistory;
                m_flakeLastModified = modified;
                m_flakeLastCommitSubject = subject;
                m_flakeLastCommitHash = hash;
                emit flakeStatusChanged();
            },
            Qt::QueuedConnection);
    }).detach();
}

} // namespace caelestia::services
