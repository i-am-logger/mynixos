# mynixos Opinionated Defaults: Terminal Apps
#
# This file defines which apps are enabled when terminal.enable = true
# Users can override by setting apps.{app}.enable = false

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.terminal.enable or false) {
        apps.terminal = {
          # Shells (bash is default, fish optional)
          shells.bash.enable = lib.mkDefault true;
          shells.fish.enable = lib.mkDefault false;
          
          # Prompts
          prompts.starship.enable = lib.mkDefault true;
          
          # Viewers
          viewers.bat.enable = lib.mkDefault true;
          # feh is handled by graphical feature
          
          # File utilities
          fileUtils.lsd.enable = lib.mkDefault true;
          
          # File managers
          fileManagers.yazi.enable = lib.mkDefault true;
          fileManagers.mc.enable = lib.mkDefault false;
          
          # System info
          sysinfo.fastfetch.enable = lib.mkDefault true;
          sysinfo.btop.enable = lib.mkDefault true;
          sysinfo.neofetch.enable = lib.mkDefault false;
          
          # Network tools
          network.termscp.enable = lib.mkDefault false;
          
          # Visualizers
          visualizers.cava.enable = lib.mkDefault true;
          
          # Fun/Eye candy
          fun.pipes.enable = lib.mkDefault false;
          
          # Note: Multiplexers (zellij, tmux) are controlled by terminal.multiplexer setting, not as apps
        };
      };
    }));
  };
}
