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

  # `claude` routed to a Claude.ai account. Claude Code reads CLAUDE_CONFIG_DIR
  # once, from the environment it starts in, and keeps one credential per such
  # directory: so an account is a directory, and the wrapper's only job is to
  # choose it before exec. The default account is ~/.claude itself; every
  # other account is ~/.claude-accounts/<alias>, holding its own credential
  # and symlinks to everything else in ~/.claude, refreshed on each start so
  # sessions, memory, settings, plugins and history stay shared.
  #
  # Precedence: CLAUDE_ACCOUNT, then the longest declared directory prefix of
  # the working directory, then the default account. A CLAUDE_CONFIG_DIR that
  # is already set and no CLAUDE_ACCOUNT means the caller chose a directory
  # itself; the wrapper leaves it alone.
  mkAccountsWrapper = cfg:
    let
      routeLines = concatLists (mapAttrsToList
        (alias: acct: map (dir: "${dir}\t${alias}") acct.directories)
        cfg.accounts);
      emailLines = mapAttrsToList (alias: acct: "${alias}\t${acct.email}") cfg.accounts;

      common = ''
        base="$HOME/.claude"
        accounts_root="$HOME/.claude-accounts"
        default_alias=${escapeShellArg cfg.defaultAccount}

        # alias<TAB>email
        emails=${escapeShellArg (concatStringsSep "\n" emailLines)}
        # directory<TAB>alias; ~/ is the home directory
        routes=${escapeShellArg (concatStringsSep "\n" routeLines)}

        expand_home() {
          case "$1" in
            "~") printf '%s' "$HOME" ;;
            "~/"*) printf '%s' "$HOME/''${1#\~/}" ;;
            *) printf '%s' "$1" ;;
          esac
        }

        email_of() {
          printf '%s\n' "$emails" | while IFS=$'\t' read -r alias email; do
            [ "$alias" = "$1" ] && printf '%s' "$email"
          done
        }

        known_alias() {
          printf '%s\n' "$emails" | cut -f1 | grep -qx -- "$1"
        }

        dir_of() {
          if [ "$1" = "$default_alias" ]; then
            printf '%s' "$base"
          else
            printf '%s' "$accounts_root/$1"
          fi
        }

        # Longest declared prefix of the physical working directory.
        route_for_cwd() {
          local cwd best="" best_len=0 dir alias
          cwd=$(pwd -P)
          while IFS=$'\t' read -r dir alias; do
            [ -n "$dir" ] || continue
            dir=$(expand_home "$dir")
            case "$cwd" in
              "$dir" | "$dir"/*)
                if [ "''${#dir}" -gt "$best_len" ]; then
                  best=$alias
                  best_len=''${#dir}
                fi
                ;;
            esac
          done <<< "$routes"
          printf '%s' "''${best:-$default_alias}"
        }

        # Mirror ~/.claude into an account directory as symlinks, except what
        # is the account's own (credential, per-directory state) or noise.
        sync_farm() {
          local dir=$1 alias=$2 entry name target
          mkdir -p "$dir"
          chmod 700 "$dir"
          for entry in "$base"/* "$base"/.[!.]*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            name=''${entry##*/}
            case "$name" in
              .credentials.json | .claude.json | .git | .gitignore | stats-cache.json | \
              cache | debug | backups | telemetry | statsig | .last-cleanup)
                continue
                ;;
            esac
            target="$dir/$name"
            if [ -L "$target" ]; then
              [ "$(readlink "$target")" = "$entry" ] || ln -sfn "$entry" "$target"
            elif [ -e "$target" ]; then
              echo "claude: account $alias keeps its own $name; it is not shared with ~/.claude" >&2
            else
              ln -s "$entry" "$target"
            fi
          done
        }
      '';
    in
    {
      claude = pkgs.writeShellApplication {
        name = "claude";
        runtimeInputs = [ pkgs.coreutils pkgs.gnugrep ];
        text = ''
          ${common}

          if [ -n "''${CLAUDE_CONFIG_DIR:-}" ] && [ -z "''${CLAUDE_ACCOUNT:-}" ]; then
            exec ${pkgs.claude-code}/bin/claude "$@"
          fi

          alias=''${CLAUDE_ACCOUNT:-$(route_for_cwd)}
          if ! known_alias "$alias"; then
            echo "claude: unknown account '$alias'; declared: $(printf '%s\n' "$emails" | cut -f1 | tr '\n' ' ')" >&2
            exit 2
          fi

          dir=$(dir_of "$alias")
          if [ "$alias" != "$default_alias" ]; then
            sync_farm "$dir" "$alias"
            if [ "$(uname -s)" != Darwin ] && [ ! -s "$dir/.credentials.json" ]; then
              echo "claude: account $alias has no login yet; sign in as $(email_of "$alias") when prompted" >&2
            fi
          fi

          CLAUDE_ACCOUNT=$alias
          CLAUDE_CONFIG_DIR=$dir
          export CLAUDE_ACCOUNT CLAUDE_CONFIG_DIR
          exec ${pkgs.claude-code}/bin/claude "$@"
        '';
      };

      claude-accounts = pkgs.writeShellApplication {
        name = "claude-accounts";
        runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.jq ];
        text = ''
          ${common}

          printf '%-14s %-32s %-10s %s\n' ALIAS EMAIL LOGIN DIRECTORY
          printf '%s\n' "$emails" | while IFS=$'\t' read -r alias email; do
            dir=$(dir_of "$alias")
            if [ "$(uname -s)" = Darwin ]; then
              login=keychain
            elif [ -s "$dir/.credentials.json" ]; then
              expires=$(jq -r '.claudeAiOauth.refreshTokenExpiresAt // empty' "$dir/.credentials.json" 2>/dev/null || true)
              if [ -n "$expires" ]; then
                login="until $(date -d "@$((expires / 1000))" +%F)"
              else
                login=yes
              fi
            else
              login=none
            fi
            mark=""
            [ "$alias" = "$default_alias" ] && mark=" (default)"
            printf '%-14s %-32s %-10s %s%s\n' "$alias" "$email" "$login" "$dir" "$mark"
          done

          if [ -n "$routes" ]; then
            echo
            echo "Routes (longest prefix wins; CLAUDE_ACCOUNT overrides):"
            printf '%s\n' "$routes" | while IFS=$'\t' read -r dir alias; do
              printf '  %-40s -> %s\n' "$dir" "$alias"
            done
          fi
        '';
      };
    };

  # The installed package: upstream claude-code with bin/claude replaced by
  # the routing wrapper, plus claude-as and claude-accounts beside it. Keeps
  # upstream's version and meta so home-manager's version gates still apply.
  mkAccountsPackage = cfg:
    let
      w = mkAccountsWrapper cfg;
      claudeAs = pkgs.writeShellApplication {
        name = "claude-as";
        text = ''
          if [ $# -lt 1 ]; then
            echo "usage: claude-as <account> [claude arguments...]" >&2
            exit 2
          fi
          CLAUDE_ACCOUNT=$1
          export CLAUDE_ACCOUNT
          shift
          exec ${w.claude}/bin/claude "$@"
        '';
      };
    in
    pkgs.symlinkJoin {
      name = "claude-code-accounts-${pkgs.claude-code.version}";
      inherit (pkgs.claude-code) version meta;
      paths = [ pkgs.claude-code ];
      postBuild = ''
        rm "$out/bin/claude"
        ln -s ${w.claude}/bin/claude "$out/bin/claude"
        ln -s ${claudeAs}/bin/claude-as "$out/bin/claude-as"
        ln -s ${w.claude-accounts}/bin/claude-accounts "$out/bin/claude-accounts"
      '';
    };
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
          name: userCfg:
            # Use module function to access home-manager's lib (provides lib.hm.dag)
            { lib, ... }:
            let
              cfg = userCfg.apps.ai.tools.claude-code;
              multiAccount = cfg.accounts != { };
            in
            lib.mkIf cfg.enable (lib.mkMerge [
              {
                assertions = [
                  {
                    assertion = !multiAccount || (cfg.defaultAccount != null && cfg.accounts ? ${toString cfg.defaultAccount});
                    message = "my.users.${name}.apps.ai.tools.claude-code.defaultAccount must name one of the declared accounts (${concatStringsSep ", " (attrNames cfg.accounts)})";
                  }
                ];

                programs.claude-code = {
                  enable = true;
                  package = if multiAccount then mkAccountsPackage cfg else pkgs.claude-code;
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
