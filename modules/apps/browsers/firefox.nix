{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.browsers.firefox;
in
{
  config = mkIf cfg {
    # Install Firefox
    environment.systemPackages = with pkgs; [ firefox ];

    # Enable Firefox in home-manager for each user
    home-manager.users = mapAttrs (name: userCfg: {
      programs.firefox = {
        enable = true;
        package = pkgs.firefox;
      };
    }) config.my.users;
  };
}
