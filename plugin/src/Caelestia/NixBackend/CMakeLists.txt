qml_module(caelestia-nixbackend
    URI Caelestia.NixBackend
    SOURCES
        nixbackendclient.cpp
    LIBRARIES
        gRPC::grpc++
        protobuf::libprotobuf
        caelestia-core
    DEPENDENCIES
        Caelestia
)

caelestia_add_grpc_proto(caelestia-nixbackend
    PROTO_FILE "${CMAKE_SOURCE_DIR}/nix-backend-generic/proto/nix_backend.proto"
)
