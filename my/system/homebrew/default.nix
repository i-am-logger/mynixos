# Homebrew -- darwin only.
#
# Both this file and ./options.nix are imported by platforms/darwin.nix and by
# nothing else, so on NixOS the options are not merely inert -- they do not
# exist. `my.homebrew.enable = true` on a Linux host is "The option
# `my.homebrew.enable' does not exist", not a silent no-op.
#
# nix-darwin's `homebrew.*` module only writes a Brewfile and runs `brew
# bundle`; it does NOT install Homebrew. nix-homebrew does that, and mynixos
# supplies it in `darwinModules.default` (see flake.nix): it is a flake input
# *value* rather than a path, so it is listed there rather than in
# platforms/darwin.nix, the same way impermanence and lanzaboote are on the
# NixOS side. The consumer flake needs no nix-homebrew reference of its own.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.homebrew;

  # App Store installs run from the activation script, NOT through
  # `homebrew.masApps`, because those two cannot both be satisfied:
  #
  #   * `mas install` states "Requires root privileges to install apps" in its
  #     own --help, and shells out to sudo when it does not have them.
  #   * nix-darwin runs `brew bundle` as the configured user
  #     (`sudo --preserve-env=PATH --user=<user>`), because Homebrew refuses to
  #     run as root.
  #
  # So brew bundle invokes mas as an unprivileged user with no TTY, mas asks
  # sudo for a password it cannot read, and every entry fails with
  # "Installing X has failed!" -- whether or not the app is present.
  #
  # The activation script itself already runs as root, which is exactly what mas
  # wants, so the install goes here and nix-darwin's masApps is left empty.
  masInstall = pkgs.writeShellScript "mynixos-mas-install" ''
    set -u
    mas=${lib.getExe' pkgs.mas "mas"}

    # mas must run as root to install, but it reads SUDO_UID to work out WHOSE
    # App Store session to use -- without it, it stops with "Failed to get sudo
    # uid". It normally gets that from having been started as `sudo mas`, and
    # nix-darwin's activate runs under `env -i`, so nothing is inherited. Set it
    # from the configured user, which is the account signed into the App Store.
    uid=$(${lib.getExe' pkgs.coreutils "id"} -u ${escapeShellArg cfg.user}) || exit 0
    gid=$(${lib.getExe' pkgs.coreutils "id"} -g ${escapeShellArg cfg.user}) || exit 0

    # `mas install` on an app that is already present prints a warning and exits
    # 0, so this is idempotent and needs no "is it installed" probe -- which
    # matters, because `mas list` discovers apps through the Spotlight index and
    # reports nothing when that index is cold.
    ${concatStringsSep "\n" (mapAttrsToList
      (name: id: ''
        echo >&2 "  mas: ${name} (${toString id})"
        SUDO_UID="$uid" SUDO_GID="$gid" SUDO_USER=${escapeShellArg cfg.user} \
          "$mas" install ${toString id} || \
          echo >&2 "  warning: mas could not install ${name} (${toString id}); is the App Store signed in?"
      '')
      cfg.masApps)}
  '';
in
{
  config = mkIf cfg.enable {
    nix-homebrew = {
      enable = true;
      inherit (cfg) user;
      # Taps left mutable: pinning homebrew-core and homebrew-cask as flake
      # inputs costs a multi-hundred-MB fetch for very little, given how few
      # casks this policy permits.
      mutableTaps = true;
    };

    homebrew = {
      enable = true;
      inherit (cfg) casks;
      # masApps deliberately NOT passed through -- see masInstall above.
      onActivation = {
        inherit (cfg) cleanup;
        autoUpdate = true;
        upgrade = true;
      };
    };

    # After Homebrew, so a cask and an App Store app can both be declared without
    # ordering surprises. Runs as root, which is what mas requires.
    system.activationScripts.mas.text = mkIf (cfg.masApps != { }) ''
      echo >&2 "Mac App Store apps..."
      ${masInstall}
    '';
  };
}
