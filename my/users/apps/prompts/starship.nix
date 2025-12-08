{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.terminal.prompts.starship.enable or false) {
          programs.starship = {
            enable = true;
            # Load settings from the original TOML file
            settings = builtins.fromTOML (builtins.readFile ./config/starship.toml);
          };
        })
      config.my.users;
  };
}
