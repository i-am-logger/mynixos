# mynixos Opinionated Defaults: Graphical Apps
#
# Apps enabled when graphical.enable = true. Users override with
# apps.{app}.enable = false.
#
# Only apps that exist on every platform live here. Wayland/X11-only ones —
# hyprland, waybar, feh — are in ./mynixos-linux.nix, so darwin never defaults
# on something it cannot run.

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.enable or false) {
        apps.graphical = {
          # Browsers
          # The primary browser comes from environment.BROWSER; these toggles
          # add extra ones alongside it.
          browsers.chromium.enable = lib.mkDefault false;

          # Terminals
          # Likewise environment.TERMINAL picks the primary terminal.
          terminals = {
            kitty.enable = lib.mkDefault false;
            ghostty.enable = lib.mkDefault false;
          };

          # Editors (graphical)
          editors = {
            helix.enable = lib.mkDefault true;
            marktext.enable = lib.mkDefault false;
          };

          # File managers (graphical use)
          # yazi already enabled by terminal if terminal.enable

          # Utilities
          utils = {
            calculator.enable = lib.mkDefault false;
            imagemagick.enable = lib.mkDefault true;
          };

          # Sync
          sync.rclone.enable = lib.mkDefault true;

          # Note: webapps, streaming, media are sub-features with their own enable flags
          # Those are handled separately in graphical.nix implementation
        };
      };
    }));
  };
}
