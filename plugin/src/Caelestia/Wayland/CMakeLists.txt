qml_module(caelestia-wayland
    URI Caelestia.Wayland
    INCLUDE_PREFIX wayland
    SOURCES
        ironlandshortcut.cpp
        ironlandfocusgrab.cpp
        ironlandpermissionprompt.cpp
        ironlandcapturepermissions.cpp
    LIBRARIES
        Qt::Gui
        Qt::GuiPrivate
        Qt::WaylandClient
    DEPENDENCIES
        Caelestia
)

caelestia_add_wayland_protocol(caelestia-wayland
    FILES
        "${CMAKE_SOURCE_DIR}/plugin/protocols/ironland-shortcuts-v1.xml"
        "${CMAKE_SOURCE_DIR}/plugin/protocols/ironland-focus-grab-v1.xml"
        "${CMAKE_SOURCE_DIR}/plugin/protocols/ironland-permission-prompt-v1.xml"
        "${CMAKE_SOURCE_DIR}/plugin/protocols/ironland-capture-permissions-v1.xml"
)
