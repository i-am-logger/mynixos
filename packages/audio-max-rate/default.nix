# audio-max-rate — pin every CoreAudio device to its highest supported rate.
#
# Pure-stdlib python3 driving the CoreAudio API through ctypes, so there is no
# compiler and no third-party dependency. See the script's docstring for why
# this cannot be done with `defaults` or an existing CLI.
{ lib
, stdenvNoCC
, python3
}:

stdenvNoCC.mkDerivation {
  pname = "audio-max-rate";
  version = "1.0.0";

  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp audio-max-rate.py $out/bin/audio-max-rate
    substituteInPlace $out/bin/audio-max-rate \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'
    chmod +x $out/bin/audio-max-rate
    runHook postInstall
  '';

  meta = {
    description = "Set macOS audio devices to their maximum sample rate";
    mainProgram = "audio-max-rate";
    platforms = lib.platforms.darwin;
  };
}
