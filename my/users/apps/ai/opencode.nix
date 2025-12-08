{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          cfg = userCfg.apps.ai.tools.opencode;
        in
        mkIf (cfg.enable or false) {
          # Use home-manager module for opencode
          programs.opencode = {
            enable = true;
            package = pkgs.opencode;
          };

          # OpenCode persists its data in ~/.claude and ~/.config/opencode
          # These are handled by the app's persistedDirectories in options/users/apps.nix
        })
      config.my.users;
  };
}
