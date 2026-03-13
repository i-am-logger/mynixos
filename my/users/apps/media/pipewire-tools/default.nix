{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.media.tools.pipewireTools.enable or false {
          home.packages = with pkgs; [
            # PipeWire CLI tools
            pipewire
          ];
        })
      config.my.users;
  };
}
