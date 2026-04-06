{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, alsa-lib
, dbus
, pipewire
, makeWrapper
, libGL
, libxkbcommon
, wayland
, xorg
, vulkan-loader
}:

rustPlatform.buildRustPackage rec {
  pname = "bespec";
  version = "1.6.4-rc.3-hotreload";

  src = fetchFromGitHub {
    owner = "i-am-logger";
    repo = "BeSpec";
        rev = "c084952de2fba5a7596e03caede87cfed8d810fc";
    hash = "sha256-bA/O2pBcAfYmKgvuCb5LzqHVoOfb9GUpNlKWoqQD5pA=";
  };

  cargoHash = "sha256-IFmFNTtlDGP6LInzTPc12uTrhtXOajPxlO5mxbxs2wY=";

  nativeBuildInputs = [ pkg-config makeWrapper ];

  buildInputs = [
    alsa-lib
    dbus
    pipewire
  ];

  runtimeDependencies = [
    libGL
    libxkbcommon
    wayland
    vulkan-loader
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ];

  postInstall = ''
    install -Dm644 assets/icon.png $out/share/icons/hicolor/256x256/apps/bespec.png

    wrapProgram $out/bin/bespec \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDependencies}"
  '';

  meta = with lib; {
    description = "Lightweight, configurable, real-time audio spectrum visualizer with peak hold";
    homepage = "https://github.com/BeSpec-Dev/BeSpec";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bespec";
  };
}
