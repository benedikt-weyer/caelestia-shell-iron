#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

// System target for the nix flake update/rebuild dashboard tab (see
// services/NixBackend.qml and nix-backend-generic/proto/nix_backend.proto).
// Both fields empty (the default) means "let the daemon resolve it" from
// its own NIX_BACKEND_CONFIG_DIR/NIX_BACKEND_HOST_NAME env vars, then
// /etc/nixos and the machine's hostname - so this section only needs
// filling in when the flake directory or nixosConfigurations name isn't the
// daemon's own default.
class NixBackendConfig : public settings::ObjectNode {
    CONFIG_NODE(NixBackendConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(QString, systemConfigDir, QString())
    CONFIG_GLOBAL_PROPERTY(QString, systemHostName, QString())
};

} // namespace caelestia::config
