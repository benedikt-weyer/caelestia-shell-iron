# Thin wrapper around Qt's own qt6_generate_wayland_protocol_client_sources
# (see Qt6WaylandScannerTools/Qt6WaylandClientMacros.cmake), which finding
# Qt6::WaylandClient already pulls in along with the Wayland::Scanner and
# Qt6::qtwaylandscanner targets it needs.
#
# Usage: caelestia_add_wayland_protocol(<target> FILES <protocol.xml>...)
#
# For each protocol.xml this adds, to <target>:
#   - wayland-<name>-client-protocol.h/.c   (raw libwayland client bindings)
#   - qwayland-<name>.h/.cpp                (QtWaylandClient::QtWayland::<iface> wrappers)
# and puts <target>'s binary dir on its own include path so generated code
# can '#include' the raw header by its plain name.
function(caelestia_add_wayland_protocol target)
    qt6_generate_wayland_protocol_client_sources(${target} ${ARGN})
endfunction()
