#pragma once

#include <memory>

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>

namespace caelestia::services {

// QML-facing gRPC client for nix-backend-generic (see
// nix-backend-generic/proto/nix_backend.proto at the repo root, the shared
// contract both sides build from). Talks to the daemon over a unix socket,
// spawning it on demand if nothing answers yet - see nixbackendclient.cpp.
//
// Only one call may be in flight at a time; updateFlake()/rebuild() are
// no-ops while running() is true. Every event of a call updates phase/
// fractionDone/statusMessage and (each non-empty line) emits lineLogged, so
// QML can drive both a compact status readout and a scrolling log from the
// same stream.
class NixBackendClient : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(caelestia::services::NixBackendClient::Phase phase READ phase NOTIFY phaseChanged)
    Q_PROPERTY(qreal fractionDone READ fractionDone NOTIFY fractionDoneChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool flakeHasGitHistory READ flakeHasGitHistory NOTIFY flakeStatusChanged)
    Q_PROPERTY(QString flakeLastModified READ flakeLastModified NOTIFY flakeStatusChanged)
    Q_PROPERTY(QString flakeLastCommitSubject READ flakeLastCommitSubject NOTIFY flakeStatusChanged)
    Q_PROPERTY(QString flakeLastCommitHash READ flakeLastCommitHash NOTIFY flakeStatusChanged)

public:
    // Mirrors proto::EventPhase exactly (same numeric values) so the wire
    // value can be static_cast straight across - see toClientPhase().
    enum class Phase : quint8 {
        Idle = 0,
        Started,
        FlakeUpdate,
        Build,
        Diff,
        Register,
        Activate,
        Finished,
        Failed
    };
    Q_ENUM(Phase)

    enum class RebuildMode : quint8 { Switch, Boot, Test };
    Q_ENUM(RebuildMode)

    explicit NixBackendClient(QObject* parent = nullptr);
    ~NixBackendClient() override;

    [[nodiscard]] bool running() const;
    [[nodiscard]] Phase phase() const;
    [[nodiscard]] qreal fractionDone() const;
    [[nodiscard]] QString statusMessage() const;
    [[nodiscard]] QString lastError() const;
    [[nodiscard]] bool flakeHasGitHistory() const;
    [[nodiscard]] QString flakeLastModified() const;
    [[nodiscard]] QString flakeLastCommitSubject() const;
    [[nodiscard]] QString flakeLastCommitHash() const;

    // configDir/hostName empty means "let the daemon resolve it" (its own
    // env vars, then /etc/nixos + the machine's hostname).
    Q_INVOKABLE void updateFlake(const QString& configDir, const QString& hostName);
    Q_INVOKABLE void rebuild(const QString& configDir, const QString& hostName, RebuildMode mode);
    Q_INVOKABLE void refreshFlakeStatus(const QString& configDir, const QString& hostName);

signals:
    void runningChanged();
    void phaseChanged();
    void fractionDoneChanged();
    void statusMessageChanged();
    void lastErrorChanged();
    void flakeStatusChanged();
    void lineLogged(const QString& message, bool isError);
    void finished(bool success);

private:
    struct Impl;
    // Keeps grpc++/protobuf generated headers out of this header entirely,
    // so nothing else in the plugin needs them on its include path.
    std::unique_ptr<Impl> m_impl;

    void setRunning(bool value);
    void setPhase(Phase value);
    void setFractionDone(qreal value);
    void setStatusMessage(const QString& value);
    void setLastError(const QString& value);

    bool m_running = false;
    Phase m_phase = Phase::Idle;
    qreal m_fractionDone = -1.0;
    QString m_statusMessage;
    QString m_lastError;
    bool m_flakeHasGitHistory = false;
    QString m_flakeLastModified;
    QString m_flakeLastCommitSubject;
    QString m_flakeLastCommitHash;
};

} // namespace caelestia::services
