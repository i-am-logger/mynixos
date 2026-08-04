# KeepingYouAwake — a menu-bar toggle for macOS's own sleep assertions.
#
# Packaged from upstream's release zip rather than the Homebrew cask: it is a
# plain signed .app with no driver, no launchd daemon and no privileged install
# step, so there is nothing a cask would do that a derivation cannot.
#
# nix-darwin rsyncs anything in environment.systemPackages that provides
# /Applications into "/Applications/Nix Apps" as a real bundle (not a symlink),
# so Spotlight and the Dock index it normally.
#
# It is a GUI front end for the same IOKit power assertions `caffeinate(8)`
# uses, so the two are interchangeable in effect — this one just gives you a
# visible indicator and a click target.
{ lib
, stdenvNoCC
, fetchurl
, unzip
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "keepingyouawake";
  version = "1.6.8";

  src = fetchurl {
    url = "https://github.com/newmarcel/KeepingYouAwake/releases/download/${finalAttrs.version}/KeepingYouAwake-${finalAttrs.version}.zip";
    hash = "sha256-gAGhSbRJDACP2sGYmLzpkC1RbEqmQSp+sPmjdEOxXGs=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "KeepingYouAwake.app" "$out/Applications/"
    runHook postInstall
  '';

  # The bundle is signed by the developer; copying preserves that. Do not strip
  # or rewrite it — that invalidates the signature and macOS will refuse to run
  # it on arm64.
  dontFixup = true;

  meta = {
    description = "Menu-bar utility to prevent macOS from going to sleep";
    longDescription = ''
      A small menu bar tool that toggles macOS power assertions, the same
      mechanism `caffeinate` drives from the command line. Unlike caffeinate it
      shows whether it is currently active.
    '';
    homepage = "https://keepingyouawake.app/";
    changelog = "https://github.com/newmarcel/KeepingYouAwake/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
