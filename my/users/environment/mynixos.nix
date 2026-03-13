# mynixos Opinionated Defaults: User Environment
#
# This file defines which environment applications are set when graphical.enable = true
# Users can override by setting environment.BROWSER = pkgs.firefox; etc.

{ lib, pkgs, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.graphical.enable or false) {
        environment = {
          BROWSER = lib.mkDefault {
            enable = true;
            package = pkgs.brave;
            settings = { };
          };
          TERMINAL = lib.mkDefault {
            enable = true;
            package = pkgs.wezterm;
            settings = { };
          };
          EDITOR = lib.mkDefault {
            enable = true;
            package = pkgs.helix;
            settings = { };
          };
          SHELL = lib.mkDefault {
            enable = true;
            package = pkgs.bashInteractive;
            settings = { };
          };
          FILE_MANAGER = lib.mkDefault {
            enable = true;
            package = pkgs.yazi;
            settings = { };
          };
          launcher = lib.mkDefault {
            enable = true;
            package = pkgs.walker;
            settings = { };
          };
          multiplexer = lib.mkDefault {
            enable = true;
            package = pkgs.zellij;
            settings = { };
          };
        };
      };
    }));
  };
}
