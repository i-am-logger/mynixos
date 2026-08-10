# herdr, a terminal multiplexer built around running coding agents side by side.
#
# Gated on `terminal.multiplexer == "herdr"`, the same selector tmux and zellij
# use, and for the same reason: a second on/off switch beside the selector is a
# second way to say one thing. Its enum member and the enum's default are
# declared in ./options.nix.
#
# Unlike tmux and zellij, home-manager has no programs.herdr module, so this one
# puts the package on PATH and writes the config file itself.
{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  isHerdr = userCfg: (userCfg.terminal.multiplexer or null) == "herdr";

  # `herdr --default-config` is the schema of record. Only settings that would
  # otherwise be WRONG for a Nix-managed install are stated; herdr's own
  # defaults are left unsaid.
  settingsFor = userCfg: {
    # A declarative install has already made every choice the wizard asks about.
    onboarding = false;

    theme = {
      # Follow the host terminal's light/dark appearance rather than pinning one.
      auto_switch = true;
      dark_name = "catppuccin";
      light_name = "catppuccin-latte";
    };

    terminal = optionalAttrs (userCfg.shell != null) {
      # mynixos DECLARES the shell (my/users/users/mynixos-darwin.nix makes it
      # zsh, mynixos-linux.nix bash) but deliberately leaves a macOS account's
      # login shell alone -- so $SHELL, which is herdr's own fallback, is
      # whatever Setup Assistant left in the directory service. Naming it makes
      # herdr's panes honour the declaration instead of the directory service.
      default_shell = userCfg.shell;
    };

    update = {
      # The binary is a read-only store path. It cannot self-update, so this
      # poll to herdr.dev could only ever tell us what the next lock bump would.
      version_check = false;

      # A different thing, off for a different reason: this one fetches
      # agent-DETECTION manifests, so switching it off is a real trade -- herdr
      # stops learning to recognise agents released after the pinned version, in
      # exchange for making no unbidden network call. Turn it back on if
      # detection goes stale before the next nixpkgs bump.
      manifest_check = false;
    };
  };

  configFor = userCfg:
    (pkgs.formats.toml { }).generate "herdr-config.toml" (settingsFor userCfg);
in
{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (isHerdr userCfg) {
          home.packages = [ pkgs.herdr ];

          # The file, never the directory: herdr writes session.json and
          # session-history.json next to config.toml, so ~/.config/herdr has to
          # stay a real, writable directory. xdg.configFile symlinks per file,
          # which is exactly what that needs.
          #
          # Consequence worth knowing: config.toml is a store path, so herdr's
          # own settings screen cannot save to it. Settings changes come back
          # here as Nix.
          xdg.configFile."herdr/config.toml".source = configFor userCfg;
        })
      (activeUsers config.my.users);
  };
}
