# Preset implementations
# Presets apply opinionated defaults for common system configurations
{ config, lib, ... }:

with lib;

let
  cfg = config.my.presets;
in
{
  config = mkMerge [
    # Workstation preset: graphical desktop with dev tools and terminal
    (mkIf cfg.workstation.enable {
      my = {
        system.enable = mkDefault true;
        environment.enable = mkDefault true;
        performance.enable = mkDefault true;
        # graphical.enable is auto-derived from user configs, not set here
      };
    })
  ];
}
