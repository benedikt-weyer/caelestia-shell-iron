{
  lib,
  rustPlatform,
  makeWrapper,
  pkg-config,
  wayland,
  libxkbcommon,
}:
rustPlatform.buildRustPackage {
  pname = "iron-polkit";
  version = "0.1.0";
  src = ./../iron-polkit;
  cargoLock.lockFile = ./../iron-polkit/Cargo.lock;

  nativeBuildInputs = [pkg-config makeWrapper];
  # smithay-client-toolkit probes for xkbcommon via pkg-config at build time.
  buildInputs = [libxkbcommon wayland];

  # The wayland/xkbcommon bindings dlopen their libraries at runtime instead of
  # linking them, so without this the overlay dies at startup with
  # "ConnectError(NoWaylandLib)" under a service with a bare environment.
  postInstall = ''
    wrapProgram $out/bin/iron-polkit \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [wayland libxkbcommon]}
  '';

  meta = {
    description = "Polkit authentication agent with an iced layer-shell prompt for ironland-compositor";
    license = lib.licenses.gpl3Only;
    mainProgram = "iron-polkit";
  };
}
