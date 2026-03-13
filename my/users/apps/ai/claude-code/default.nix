{ config
, lib
, pkgs
, ...
}:

with lib;

let
  anyUserClaudeCode = any
    (userCfg: userCfg.apps.ai.tools.claude-code.enable or false)
    (attrValues config.my.users);
in
{
  config = mkMerge [
    # Allow claude-code unfree package (when ANY user enables it)
    (mkIf anyUserClaudeCode {
      my.system.allowedUnfreePackages = [ "claude-code" ];
    })

    # Per-user claude-code installation via home-manager
    {
      home-manager.users = mapAttrs
        (
          _name: userCfg:
            let
              cfg = userCfg.apps.ai.tools.claude-code;
            in
            mkIf cfg.enable {
              programs.claude-code = {
                enable = true;
                package = pkgs.claude-code;
              };
            }
        )
        config.my.users;
    }
  ];
}
