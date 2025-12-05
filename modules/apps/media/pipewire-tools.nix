{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.media;
in
{
  config = mkIf cfg.pipewireTools {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          # PipeWire CLI tools
          pipewire
        ];
      })
      config.my.users;
  };
}
