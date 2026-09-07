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

    cmake_parse_arguments(arg "" "" "FILES" ${ARGN})
    get_target_property(target_binary_dir ${target} BINARY_DIR)

    # The raw libwayland client bindings are plain C, generated into
    # <target>'s binary dir - keep them out of <target>'s (C++-only) PCH so
    # CMake doesn't try to instantiate a C-language PCH from C++ headers.
    foreach(protocol_file IN LISTS arg_FILES)
        get_filename_component(protocol_name "${protocol_file}" NAME_WLE)
        set_source_files_properties(
            "${target_binary_dir}/wayland-${protocol_name}-client-protocol.h"
            "${target_binary_dir}/wayland-${protocol_name}-protocol.c"
            PROPERTIES SKIP_PRECOMPILE_HEADERS ON
        )
    endforeach()
endfunction()
