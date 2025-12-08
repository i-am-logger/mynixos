{ config, lib, pkgs, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.terminal.sysinfo.btop.enable or false) {
          programs.btop = {
            enable = true;
            settings = {
              update_ms = 100;
              show_gpu_info = "On";
              shown_boxes = "cpu mem net proc gpu0";
            };
            package = pkgs.btop.override {
              cudaSupport = true;
            };
          };
        })
      config.my.users;
  };
}
