{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.media.pipewireTools.enable or false) {
          home.packages = with pkgs; [
            # PipeWire CLI tools
            pipewire
          ];
        })
      config.my.users;
  };
}
