# Brave on darwin, built from the signed DMG instead of the unsigned zip.
#
# SCOPE: darwin only. The Linux hosts keep nixpkgs' brave verbatim — they build
# from the .deb, which this file never touches.
#
# WHY THIS EXISTS
#
# nixpkgs' brave crashes on launch on macOS 27, ~170ms in, before a window ever
# appears:
#
#   [FATAL:base/path_service.cc:264] Failed to get the path for 1001
#
# 1001 is chrome::DIR_LOGS, which on macOS resolves through chrome::DIR_USER_DATA
# to ~/Library/Application Support/BraveSoftware/Brave-Browser. The provider is
# asked to CREATE that directory, the mkdir returns EPERM, PathService::CheckedGet
# fails its CHECK, and the process takes a SIGTRAP.
#
# The mkdir fails because macOS 27 protects browser profile directories against
# access by anything other than the browser that owns them — Apple's
# anti-infostealer measure. Confirmed by hand: inside ~/Library/Application
# Support, mkdir of BraveSoftware/Brave-Browser, Google/Chrome and Firefox all
# return EPERM, while BraveSoftware/Brave-Browser-Beta, ZZParent/Brave-Browser
# and /tmp/BraveSoftware/Brave-Browser all succeed. The rule keys off the exact
# protected path, not the name and not the parent.
#
# TCC decides "is this the browser that owns this directory?" from the code
# signature. nixpkgs' brave cannot satisfy it:
#
#   Identifier=Brave Browser          (should be com.brave.Browser)
#   TeamIdentifier=not set            (should be KL8N8XSYF4)
#   flags=0x20002(adhoc,linker-signed)
#   Sealed Resources=none             (Contents/_CodeSignature is absent)
#
# so it is denied, and — because an ad-hoc binary has no identity to attach a
# grant to — it is denied without a consent prompt. There is nothing the user can
# click to allow it.
#
# WHY THE DMG
#
# Two independent causes had to be fixed; either one alone leaves the signature
# ad-hoc, which is why both changes are here:
#
#   1. Upstream's darwin ZIP — the artifact nixpkgs fetches — ships NO signature
#      on the outer bundle. Its nested frameworks (Sparkle, BraveUpdater) carry
#      _CodeSignature, but "Brave Browser.app/Contents/_CodeSignature" is simply
#      not in the archive. The DMG ships the Developer ID signature.
#
#   2. stdenv's darwin fixup re-signs Mach-O binaries ad-hoc, destroying the
#      Developer ID signature even when the source has one. dontFixup/dontStrip
#      keep the bundle byte-intact.
#
# VERIFIED on macOS 27.0 (26A5406e) / aarch64-darwin, brave 1.93.138:
#
#   codesign -dvv  ->  Identifier=com.brave.Browser
#                      Authority=Developer ID Application: Brave Software, Inc. (KL8N8XSYF4)
#                      TeamIdentifier=KL8N8XSYF4
#                      Sealed Resources version=2 rules=13 files=76
#   codesign --verify --deep --strict  ->  rc=0
#
# — field-for-field identical to Brave's own DMG — and `open -a` launches it and
# it stays up, where the nixpkgs build dies every time. The store path being
# under /nix is irrelevant to TCC; identity is the signature, not the location.
#
# UPSTREAM STATUS
#
# nixpkgs' brave has no darwin maintainer testing launches; the package builds
# fine, which is all CI checks. Not reported yet. Once nixpkgs switches the
# darwin source to the DMG and stops re-signing it, DELETE THIS FILE.
#
# RE-PINNING
#
# The version is pinned here rather than taken from nixpkgs, because the hashes
# below are version-specific and mynixos does not control which nixpkgs a
# consumer locks. To bump: raise `pinnedVersion` and replace both hashes with
#
#   nix store prefetch-file --json \
#     https://github.com/brave/brave-browser/releases/download/v<VER>/Brave-Browser-arm64.dmg
#
# The warning below fires when the pin has fallen behind the nixpkgs recipe,
# which is the signal to do that.
_final: prev:

prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  brave =
    let
      pinnedVersion = "1.95.102";

      # arm64 is the verified one; the x64 hash is recorded so the expression is
      # complete, but no x86_64-darwin host exists to launch it on.
      dmg = {
        aarch64-darwin = {
          suffix = "arm64";
          hash = "sha256-l+tfihfRoOGR06RwWeebn6R9OTADXRCiOtCG355Ksfs=";
        };
        x86_64-darwin = {
          suffix = "x64";
          hash = "sha256-NwpxF2L74VdjA1enwQHpSSPS4FmaIObz/NoQE/jbeR0=";
        };
      }.${prev.stdenv.hostPlatform.system};

      # Mirrors my/herdr's pin: say so when nixpkgs has moved past us, rather
      # than silently holding the fleet on a stale browser.
      stale = prev.lib.versionOlder pinnedVersion prev.brave.version;
    in
    prev.lib.warnIf stale
      ''
        nixpkgs-fixes/brave.nix pins darwin brave ${pinnedVersion}, but nixpkgs
        ships ${prev.brave.version}. Re-pin the DMG (see RE-PINNING in that file).
      ''
      (prev.brave.overrideAttrs (old: {
        version = pinnedVersion;

        src = prev.fetchurl {
          name = "brave-${pinnedVersion}-darwin-${dmg.suffix}.dmg";
          url = "https://github.com/brave/brave-browser/releases/download/v${pinnedVersion}/Brave-Browser-${dmg.suffix}.dmg";
          inherit (dmg) hash;
        };

        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.undmg ];

        # The DMG unpacks to the bundle plus the usual drag-to-/Applications
        # symlink, so unpackPhase cannot pick a source root on its own. The
        # installPhase expects to be standing inside the bundle.
        sourceRoot = "Brave Browser.app";

        # THE POINT OF THIS FILE. stdenv's darwin fixup would re-sign the
        # binaries ad-hoc and drop Contents/_CodeSignature, which is exactly the
        # state that makes TCC refuse the profile directory. Nothing here needs
        # fixup: installPhase copies the bundle and runs makeWrapper itself.
        dontFixup = true;
        dontStrip = true;
      }));
}
