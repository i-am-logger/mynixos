{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.sysinfo.btop;
in
{
  # Option is declared in flake.nix
  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      programs.btop = {
        enable = true;
        settings = {
          update_ms = 100;
          show_gpu = "true";
          shown_boxes = "cpu mem net proc gpu0";
        };
        package = pkgs.btop.override {
          cudaSupport = true;
        };
      };
    }) config.my.users;
  };
}
