# cava-peaks — cava with peak-hold caps.
#
# A hand-written renderer that drives `cava -p <cfg>` in raw output mode and
# draws the bars itself, so the peak caps can decay on their own timeline.
# Pure-stdlib python3; the only runtime dependency is cava on PATH.
#
# Runtime state deliberately left OUTSIDE the store:
#   ~/.config/cava/config          — the [input] block is copied from here
#   ~/.config/cava/peaks-gain.txt  — written by --calibrate, must stay writable
{ lib
, stdenvNoCC
, makeWrapper
, python3
, cava
}:

stdenvNoCC.mkDerivation {
  pname = "cava-peaks";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/cava-peaks $out/share/cava-peaks

    cp cava-peaks.py $out/libexec/cava-peaks/cava-peaks
    substituteInPlace $out/libexec/cava-peaks/cava-peaks \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'
    chmod +x $out/libexec/cava-peaks/cava-peaks

    # Winamp 2.91 analyzer palette, for `cava-peaks --viscolor <file>`
    cp viscolor-base-2.91.txt $out/share/cava-peaks/

    makeWrapper $out/libexec/cava-peaks/cava-peaks $out/bin/cava-peaks \
      --prefix PATH : ${lib.makeBinPath [ cava ]}

    runHook postInstall
  '';

  meta = {
    description = "cava with peak-hold caps and an LED-ladder renderer";
    longDescription = ''
      Drives cava in raw output mode and renders the spectrum itself, adding
      peak-hold caps that fall on their own timeline. Response and falloff
      follow Audacious's analyzer as used by Linamp.
    '';
    mainProgram = "cava-peaks";
    platforms = lib.platforms.unix;
  };
}
