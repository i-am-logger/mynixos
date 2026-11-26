# Runtime-lean overrides: what a nixpkgs package carries for BUILDING, or for
# a feature no mynixos host uses, is cut from the runtime closure. Building
# happens in a project's devenv, never on the running system.
#
# Each entry names what it drops and what that costs; tests/module-eval.nix
# (lean-runtime-overrides) asserts every one.
_final: prev:

prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  # Hyprland suffixes binutils, pkgconf, hyprland-guiutils and pciutils onto
  # the PATH of everything it launches -- the first two only so hyprpm can
  # compile plugins on the machine. mynixos builds no plugins at runtime, so
  # the wrapper goes; my/graphical puts hyprland-guiutils (the not-responding
  # and update dialogs Hyprland spawns) and pciutils on the system PATH
  # instead. Cost: Hyprland is compiled locally, not taken from the cache.
  hyprland = prev.hyprland.override { wrapRuntimeDeps = false; };

  # Brave links speech-dispatcher for web-page text-to-speech. Nothing here
  # uses it, and the system speech service is off (my/graphical). Brave is
  # unfree-built locally either way, so this costs no cache hit.
  brave = prev.brave.override { speechd-minimal = prev.emptyDirectory; };
}
