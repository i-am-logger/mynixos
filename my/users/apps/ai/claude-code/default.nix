{ activeUsers
, config
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

    # Per-user claude-code installation and config repo cloning via home-manager
    {
      home-manager.users = mapAttrs
        (
          _name: userCfg:
            # Use module function to access home-manager's lib (provides lib.hm.dag)
            { lib, ... }:
            let
              cfg = userCfg.apps.ai.tools.claude-code;
            in
            lib.mkIf cfg.enable (lib.mkMerge [
              {
                programs.claude-code = {
                  enable = true;
                  package = pkgs.claude-code;
                };

                home.sessionVariables = {
                  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
                };
              }

              # Clone claude-config repo on first activation (runs as user, has SSH agent access)
              (lib.mkIf (cfg.cloneConfigRepo != null) {
                home.activation.cloneClaudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  _claude="$HOME/.claude"
                  _git=${pkgs.git}/bin/git

                  if [ -d "$_claude/.git" ]; then
                    true # Already initialized — user manages sync
                  elif [ -d "$_claude" ] && [ -n "$(ls -A "$_claude" 2>/dev/null)" ]; then
                    echo "WARNING: $_claude exists and is not a git repo — skipping clone (resolve manually)" >&2
                  else
                    echo "Cloning Claude config into $_claude..."
                    $_git clone ${escapeShellArg cfg.cloneConfigRepo} "$_claude" 2>&1 || \
                      echo "WARNING: Failed to clone Claude config" >&2
                  fi
                '';
              })
            ])
        )
        (activeUsers config.my.users);
    }
  ];
}
