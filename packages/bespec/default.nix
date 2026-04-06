{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, alsa-lib
, dbus
, makeWrapper
, libGL
, libxkbcommon
, wayland
, xorg
, vulkan-loader
}:

stdenv.mkDerivation rec {
  pname = "bespec";
  version = "1.6.3";

  src = fetchurl {
    url = "https://github.com/BeSpec-Dev/BeSpec/releases/download/v${version}/bespec-v${version}-linux.tar.gz";
    hash = "sha256-RR9hW4+QXaj+byUD3aR1z1N39uj3r99X+GadCtn9Qz0=";
  };

  sourceRoot = "bespec-dist";

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    alsa-lib
    dbus
    stdenv.cc.cc.lib
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

  installPhase = ''
    runHook preInstall

    install -Dm755 bespec $out/bin/bespec
    install -Dm644 icon.png $out/share/icons/hicolor/256x256/apps/bespec.png
    install -Dm644 bespec.desktop $out/share/applications/bespec.desktop

    substituteInPlace $out/share/applications/bespec.desktop \
      --replace-quiet "/usr/local/bin/bespec" "$out/bin/bespec" \
      --replace-quiet "/usr/local/share/icons/bespec.png" "$out/share/icons/hicolor/256x256/apps/bespec.png"

    wrapProgram $out/bin/bespec \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDependencies}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Lightweight, configurable, real-time audio spectrum visualizer with peak hold";
    homepage = "https://github.com/BeSpec-Dev/BeSpec";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bespec";
  };
}
