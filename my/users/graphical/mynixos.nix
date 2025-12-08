# mynixos Opinionated Defaults: Graphical Apps
#
# This file defines which apps are enabled when graphical.enable = true
# Users can override by setting apps.{app}.enable = false

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.enable or false) {
        apps.graphical = {
          # Window managers
          windowManagers.hyprland.enable = lib.mkDefault true;
          
          # Browsers
          browsers.brave.enable = lib.mkDefault true;
          browsers.firefox.enable = lib.mkDefault false;
          browsers.chromium.enable = lib.mkDefault false;
          
          # Terminals
          terminals.wezterm.enable = lib.mkDefault true;
          terminals.kitty.enable = lib.mkDefault false;
          terminals.ghostty.enable = lib.mkDefault false;
          
          # Launchers
          launchers.walker.enable = lib.mkDefault true;
          
          # Status bars
          statusbars.waybar.enable = lib.mkDefault true;
          
          # Editors (graphical)
          editors.helix.enable = lib.mkDefault true;
          editors.marktext.enable = lib.mkDefault false;
          
          # File managers (graphical use)
          # yazi already enabled by terminal if terminal.enable
          
          # Viewers
          viewers.feh.enable = lib.mkDefault true;
          
          # Utilities
          utils.calculator.enable = lib.mkDefault false;
          utils.imagemagick.enable = lib.mkDefault true;
          
          # Sync
          sync.rclone.enable = lib.mkDefault true;
          
          # Note: webapps, streaming, media are sub-features with their own enable flags
          # Those are handled separately in graphical.nix implementation
        };
      };
    }));
  };
}
