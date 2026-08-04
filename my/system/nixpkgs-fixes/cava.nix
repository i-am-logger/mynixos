# cava 1.0.0, fleet-wide, with a working Core Audio tap on darwin.
#
# SCOPE: the version/src override applies on BOTH platforms -- Linux hosts get
# 1.0.0 too, and cava-peaks (packages/cava-peaks) runs against it there. Only the
# availability PATCH below is darwin-only.
#
# 1.0.0's configure.ac requires fftw3, iniparser, ncursesw, portaudio and pulse;
# nixpkgs' 0.10.7 derivation already supplies all five, so overriding version and
# src alone is enough. Its optional backends (ALSA, JACK, PipeWire, sndio, GL)
# are absent from those buildInputs and were equally absent at 0.10.7, so the
# bump does not change which backends a Linux host gets.
#
# WHY THIS EXISTS
#
# nixpkgs ships cava 0.10.7. cava 1.0.0 (2026-06-13) added a native Core Audio
# input backend, and on macOS 14.2+ it can capture system output DIRECTLY with
#
#   [input]
#   method = coreaudio
#   source = tap
#
# which removes the need for a loopback device — i.e. Background Music, which
# cannot be packaged in nixpkgs at all (its HAL plugin must live in
# /Library/Audio/Plug-Ins/HAL, it needs a _BGMXPCHelper service account, and a
# coreaudiod restart). Getting cava onto 1.0.0 is what makes that dependency go
# away rather than merely automating it.
#
# WHY THE PATCH
#
# 1.0.0 does not build on darwin as packaged. cava's configure.ac gates the tap
# backend on AC_CHECK_HEADER([CoreAudio/AudioHardwareTapping.h]) alone. The
# header IS in the SDK, so the backend switches on — and then compilation fails:
#
#   'AudioHardwareCreateProcessTap' has been marked as being introduced in
#   macOS 14.2 here, but the deployment target is macOS 14.0.0
#
# A header-presence test cannot detect a deployment-target mismatch. Raising the
# deployment target was tried four ways (darwinMinVersionHook,
# MACOSX_DEPLOYMENT_TARGET, apple-sdk_15, plain bump) and none of them moved it.
#
# The patch does what clang itself suggests instead: wrap the two call sites in
# `@available(macOS 14.2, *)`. That is strictly better than raising the target —
# cava keeps building for older macOS and picks the tap up at RUNTIME on 14.2+.
#
# Verified locally on macOS 26.6 / aarch64-darwin: builds against the stock
# deployment target, `coreaudio` appears in the compiled-in backends, and the
# tap path runs (it reaches macOS TCC and asks for "System Audio Recording
# Only" permission, which is a one-time manual grant to the terminal app).
#
# UPSTREAM STATUS
#   - nixpkgs PR #531480 (cava: 0.10.7 -> 1.0.0) is an automated r-ryantm bump,
#     open since 2026-06-13. Its checks say "built on NixOS" — it was never
#     built on darwin, which is why this breakage is unnoticed.
#   - The patch is not upstreamed yet. Once it lands in cava and nixpkgs bumps,
#     DELETE THIS FILE.
_final: prev:

let
  isDarwin = prev.stdenv.hostPlatform.isDarwin;
in
{
  cava = prev.cava.overrideAttrs (old: {
    version = "1.0.0";

    src = prev.fetchFromGitHub {
      owner = "karlstav";
      repo = "cava";
      rev = "1.0.0";
      hash = "sha256-0vQWobnt9pAZTJc45Lgcfad72BE8DUPGQ5/YwMSmU98=";
    };

    # Only darwin needs it; the Linux build never touches coreaudio_tap.m.
    patches = (old.patches or [ ]) ++ prev.lib.optionals isDarwin [
      ../../../packages/cava/coreaudio-tap-availability.patch
    ];
  });
}
