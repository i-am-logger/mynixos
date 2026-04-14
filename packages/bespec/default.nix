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
, libx11
, libxcursor
, libxi
, libxrandr
, vulkan-loader
}:

rustPlatform.buildRustPackage rec {
  pname = "bespec";
  # Tracks i-am-logger/BeSpec feat/linux-pipewire-capture — bespec v1.7.0
  # plus the native pipewire-rs audio capture backend that fixes Linux audio
  # routing (cpal's WASAPI loopback pattern silently misroutes on Linux ALSA;
  # pipewire-rs autoconnects to the default sink monitor like cava does).
  # Will retire once the upstream PR merges.
  version = "1.7.0-linux-pipewire";

  src = fetchFromGitHub {
    owner = "i-am-logger";
    repo = "BeSpec";
    rev = "690f8fee8084ea9150c06f2e150bbb34f5ec2294";
    hash = "sha256-8KEFJGr+ZjbhaK9jtpDNPSu05EeFeL3ZKeHJ7Q6msGo=";
  };

  cargoHash = "sha256-qQtRWWaqWH8snxoalQEYgCFAxg3C9cqRUrf/X82IYDk=";

  # bindgenHook sets up LIBCLANG_PATH etc. for libspa-sys / pipewire-sys
  # which use bindgen to parse pipewire's C headers at build time.
  nativeBuildInputs = [
    pkg-config
    makeWrapper
    rustPlatform.bindgenHook
  ];

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
    libx11
    libxcursor
    libxi
    libxrandr
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
