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

    # accounts: one folder per name, so a name may appear once.
    {
      assertions = mapAttrsToList
        (name: userCfg:
          let accounts = userCfg.apps.ai.tools.claude-code.accounts or [ ]; in {
            assertion = length (unique accounts) == length accounts;
            message = "my.users.${name}.apps.ai.tools.claude-code.accounts: names must be unique (${concatStringsSep ", " accounts})";
          })
        config.my.users;
    }

    # Per-user claude-code installation and config repo cloning via home-manager
    {
      home-manager.users = mapAttrs
        (
          _name: userCfg:
            # Use module function to access home-manager's lib (provides lib.hm.dag)
            { lib, ... }:
            let
              cfg = userCfg.apps.ai.tools.claude-code;
              # usageRecord: the status line. Records {saved_at, rate_limits} (stdin's rate_limits as
              # given; saved_at in epoch seconds) into the running account's folder through a temp file
              # in that folder and a rename, so a reader never sees half a
              # file; input without rate_limits writes nothing and keeps the
              # last file. Always prints a line and exits 0.
              usageStatusLine = pkgs.writeShellScript "claude-usage-status-line" ''
                _jq=${pkgs.jq}/bin/jq
                _cu=${pkgs.coreutils}/bin
                _input=$($_cu/cat)
                _dir="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
                _rl=$(printf '%s' "$_input" | $_jq -c '.rate_limits // empty' 2>/dev/null) || _rl=
                if [ -n "$_rl" ] && $_cu/mkdir -p "$_dir" 2>/dev/null \
                  && _tmp=$($_cu/mktemp "$_dir/usage-latest.json.XXXXXX" 2>/dev/null); then
                  # account-balance reads .rate_limits.* and .saved_at (epoch
                  # seconds) to tell fresh usage from stale.
                  if $_jq -n --argjson rl "$_rl" --argjson t "$($_cu/date +%s)" \
                      '{saved_at: $t, rate_limits: $rl}' > "$_tmp" 2>/dev/null; then
                    $_cu/mv -f "$_tmp" "$_dir/usage-latest.json" 2>/dev/null || $_cu/rm -f "$_tmp"
                  else
                    $_cu/rm -f "$_tmp"
                  fi
                fi
                _line=$(printf '%s' "$_input" | $_jq -r '
                  def pct: if type == "number" then floor else . end | "\(.)%";
                  [ (.model.display_name // "Claude"),
                    (.rate_limits.five_hour.used_percentage // empty | "5h \(pct)"),
                    (.rate_limits.seven_day.used_percentage // empty | "7d \(pct)") ]
                  | join(" | ")' 2>/dev/null) || _line=
                printf '%s\n' "''${_line:-Claude}"
                exit 0
              '';
              mergedSettings = cfg.mergedSettings
                // optionalAttrs cfg.usageRecord.enable {
                statusLine = { type = "command"; command = "${usageStatusLine}"; };
              };
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

              # mergedSettings deep-merged into Claude Code's own
              # settings.json, not the file handed to home-manager: a store
              # link would leave Claude Code unable to save its settings
              # (/config, theme, permissions). Copied over in place (cp writes
              # through a link), so a settings.json that is a link -- a cloned
              # config repo's -- stays one. Unchanged settings are not
              # rewritten; a file that is not JSON is left as it is.
              (lib.mkIf (mergedSettings != { }) {
                home.activation.claudeMergedSettings = lib.hm.dag.entryAfter
                  ([ "writeBoundary" ] ++ lib.optional (cfg.cloneConfigRepo != null) "cloneClaudeConfig")
                  ''
                    _settings="$HOME/.claude/settings.json"
                    _jq=${pkgs.jq}/bin/jq
                    _new=$(mktemp)
                    if [ -s "$_settings" ]; then _cur=$(cat "$_settings"); else _cur='{}'; fi
                    if printf '%s' "$_cur" | $_jq --argjson m ${escapeShellArg (builtins.toJSON mergedSettings)} '. * $m' > "$_new" 2>/dev/null; then
                      if [ "$($_jq -S . "$_new")" != "$(printf '%s' "$_cur" | $_jq -S .)" ]; then
                        run mkdir -p "$HOME/.claude"
                        run cp "$_new" "$_settings"
                      fi
                    else
                      echo "WARNING: $_settings is not JSON; mynixos's Claude Code settings not merged" >&2
                    fi
                    rm -f "$_new"
                  '';
              })

              # accounts: ~/.claude-<name> per account, with projects,
              # sessions, CLAUDE.md and settings.json linked to ~/.claude's
              # (absolute links, not store paths). An activation step rather
              # than home.file, which refuses to clobber: if Claude Code ever
              # replaces settings.json by rename, a rebuild would fail. A
              # link already right is left alone (idempotent); a regular
              # file or directory in its place is account data, so it is
              # kept and reported, never deleted.
              (lib.mkIf (cfg.accounts != [ ]) {
                home.activation.claudeAccounts = lib.hm.dag.entryAfter
                  ([ "writeBoundary" ]
                    ++ lib.optional (cfg.cloneConfigRepo != null) "cloneClaudeConfig"
                    ++ lib.optional (mergedSettings != { }) "claudeMergedSettings")
                  ''
                    for _acct in ${concatMapStringsSep " " escapeShellArg cfg.accounts}; do
                      _dir="$HOME/.claude-$_acct"
                      [ -d "$_dir" ] || run mkdir -p "$_dir"
                      for _name in projects sessions CLAUDE.md settings.json; do
                        _link="$_dir/$_name"
                        _target="$HOME/.claude/$_name"
                        if [ -L "$_link" ] || [ ! -e "$_link" ]; then
                          if [ "$(readlink "$_link" 2>/dev/null)" != "$_target" ]; then
                            run ln -sfn "$_target" "$_link"
                          fi
                        elif ${lib.getExe' pkgs.util-linux "mountpoint"} -q "$_link"; then
                          : # bind-mounted on purpose (e.g. a shared projects dir): skipped silently
                        else
                          echo "WARNING: $_link is not a link -- left as it is (Claude account data is never deleted)" >&2
                        fi
                      done
                    done
                  '';
              })
            ])
        )
        (activeUsers config.my.users);
    }
  ];
}
