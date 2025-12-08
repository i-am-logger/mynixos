{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  config = {
    home-manager.users = mapAttrs (name: userCfg:
      let
        cfg = userCfg.apps.terminal.visualizers.cava;
        hasGraphical = userCfg.graphical.enable or false;
      in
      mkIf (cfg.enable or false) {
        programs.cava = {
          enable = true;
          
          settings = {
            general = {
              framerate = 120; # High framerate for responsiveness
              autosens = 1;
              sensitivity = 100;
              bars = 0; # Auto-calculate based on terminal width
              bar_width = 2;
              bar_spacing = 1; # Spacing between bars
              higher_cutoff_freq = 22000; # Full frequency range
            };
            
            input = {
              method = "pipewire";
              source = "auto";
            };
            
            # Output method - always use noncurses (simple, no shader complexity)
            output = {
              method = "noncurses"; # Terminal-based output
              channels = "mono"; # Mono output
            };
            
            smoothing = {
              monstercat = 1; # Smoothing formula for flowing bars
              waves = 0; # Disable waves mode
              gravity = 100; # How fast bars fall (higher = slower fall = smoother)
              ignore = 0; # Sensitivity cutoff
              noise_reduction = 77; # Smooth the graph movement (0-100, higher = smoother)
            };
          };
        };

        # Enable stylix theming with gradient mode from user config
        stylix.targets.cava = {
          enable = true;
          gradientMode = cfg.gradientMode;
        };
      }
    ) config.my.users;
  };
}
