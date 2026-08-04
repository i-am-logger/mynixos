# mynixos Opinionated Defaults: User Environment
#
# These selectors are what actually cause the corresponding app modules to
# install: my/users/apps/editors/helix keys off `environment.EDITOR.package`,
# my/users/apps/file-managers/yazi off `environment.FILE_MANAGER.package`, and so
# on. A selector left null means the app silently never installs.
#
# That is why the gate matters, and why it is per-selector rather than one
# blanket `graphical.enable`:
#
#   * EDITOR and FILE_MANAGER are TUI tools, so they key off `terminal.enable`.
#     A terminal-only host -- a headless Linux box, or macOS -- needs helix and
#     yazi, and gating them on `graphical.enable` would drop both silently.
#   * TERMINAL and BROWSER are GUI apps, and both build on darwin.
#   * launcher and locker are Hyprland-specific and name `pkgs.walker` /
#     `pkgs.hyprlock` in the option VALUE, so they live in ./mynixos-linux.nix
#     rather than being guarded here.
#
# Users can override any of these by setting environment.BROWSER = pkgs.firefox;
# etc.

{ lib, pkgs, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkMerge [
        # Terminal tools: available wherever there is a shell.
        (lib.mkIf (config.terminal.enable or false) {
          environment = {
            EDITOR = lib.mkDefault {
              enable = true;
              package = pkgs.helix;
              settings = { };
            };
            FILE_MANAGER = lib.mkDefault {
              enable = true;
              package = pkgs.yazi;
              settings = { };
            };
          };
        })

        # GUI apps. Both wezterm and brave build on aarch64-darwin.
        (lib.mkIf (config.graphical.enable or false) {
          environment = {
            BROWSER = lib.mkDefault {
              enable = true;
              package = pkgs.brave;
              settings = { };
            };
            TERMINAL = lib.mkDefault {
              enable = true;
              package = pkgs.wezterm;
              settings = { };
            };
          };
        })
      ];
    }));
  };
}
