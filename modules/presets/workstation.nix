{ config, lib, ... }:

with lib;

let
  cfg = config.my.presets.workstation;
in
{
  config = mkIf cfg.enable {
    # Enable webapps feature by default
    my.features.graphical.webapps.enable = mkDefault true;

    # Default app stack for workstations
    my.apps = {
      browsers.brave = mkDefault true;

      terminals = {
        wezterm = mkDefault true;
        kitty = mkDefault true;
        ghostty = mkDefault true;
      };

      editors.helix = mkDefault true;
      windowManagers.hyprland = mkDefault true;
      shells.fish = mkDefault true;
      prompts.starship = mkDefault true;
      fileManagers.mc = mkDefault true;

      multiplexers = {
        zellij = mkDefault true;
        tmux = mkDefault true;
      };

      viewers.bat = mkDefault true;
      fileUtils.lsd = mkDefault true;

      sysinfo = {
        btop = mkDefault true;
        neofetch = mkDefault true;
      };

      visualizers.cava = mkDefault true;
      git = mkDefault true;
      jujutsu = mkDefault true;
      ssh = mkDefault true;
      xdg = mkDefault true;
    };
  };
}
