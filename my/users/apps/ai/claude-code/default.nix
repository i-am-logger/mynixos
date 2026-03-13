{ config
, lib
, pkgs
, ...
}:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (
        _name: userCfg:
          let
            cfg = userCfg.apps.ai.tools.claude-code;
          in
          mkIf (cfg.enable or false) {
            # Use home-manager module for claude-code
            programs.claude-code = {
              enable = true;
              package = pkgs.claude-code;
            };

            # Claude Code persists its data in ~/.claude
            # This is handled by the app's persistedDirectories in options/users/apps.nix
          }
      )
      config.my.users;
  };
}
