# clauth -- Claude Code account switcher and usage monitor (CLI + TUI).
#
# A standalone CLI, so an ordinary mkApp with its own option, imported from
# platforms/common.nix (it runs on both). Its herdr plugin is registered by
# the herdr module, through terminal.herdr.plugins.clauth, because a plugin
# only means something when herdr is the selected multiplexer.
#
# Which login it switches. clauth switches the ONE global Claude Code login:
# ~/.claude/.credentials.json, the `env`/`model`/`apiKeyHelper` keys of
# ~/.claude/settings.json, ~/.claude.json and, on macOS, the unsuffixed
# `Claude Code-credentials` Keychain item (clauth SECURITY.md, "A switch
# rewrites three files"). That is the login a plain `claude` reads, with
# CLAUDE_CONFIG_DIR unset; apps.ai.tools.claude-code declares no accounts of
# its own, so every account is a clauth profile.
#
# Owner checklist, runtime state that Nix does not and must not write:
#
# * Log in each account with `clauth login <name>` (browser OAuth). On macOS
#   use that, not Claude Code's /login plus `clauth capture`.
# * Installing clauth's Claude Code plugin (its TUI's Services tab) adds an
#   MCP server and hooks to every session. Its MCP command must stay bare
#   `clauth` on PATH: the herdr plugin tells delegate runs apart by matching
#   `clauth mcp` in argv.
# * Do not start `clauth daemon --listen`; nothing here does. That flag opens
#   a TLS API whose control tier can type into herdr panes.
#
# Auto-switch and the fallback chain run only where clauth's decision loop
# runs: an open TUI, or `clauth daemon` (wiki/Auto-Switch.md, wiki/Daemon.md).
# `daemon.enable` keeps a plain daemon (no listener) running as a user
# service. `--standby` because the TUI's own "start daemon" can coexist with
# the unit: a second plain daemon exits 0, which neither supervisor restarts,
# while a standby parks and takes over when the manual one exits.
#
# What this deliberately does not do:
#
# * Write ~/.clauth/profiles.toml. clauth owns that file and edits it from its
#   own TUI (its [herdr] knobs, the fallback chain); a store link would make
#   every one of those edits fail.
# * Write anything under ~/.claude.
# * Run `clauth herdr install`. It edits ~/.config/herdr/config.toml, which is
#   a store link here, and fetches the plugin from GitHub; the herdr module
#   writes the same key and row and links the packaged plugin.
#
# Self-update is off in the package (CLAUTH_NO_UPDATE=1, packages/clauth): a
# store binary cannot replace itself, and the same switch is what stops
# clauth reinstalling its herdr plugin from GitHub over the packaged one.
{ lib, ... }@args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "ai.tools.clauth";
  option = {
    name = "clauth";
    default = false;
    description = "clauth Claude Code account switcher and usage monitor";
    # Profiles, credential snapshots (0600), its config and usage cache.
    persistedDirectories = [ ".clauth" ];
    extraOptions = {
      daemon.enable = lib.mkEnableOption ''
        a plain `clauth daemon` as a user service (launchd on macOS, systemd
        on Linux), so auto-switch, the fallback chain and usage history run
        with no clauth TUI open. It never passes `--listen`
      '';
    };
  };
  home = { cfg, lib, pkgs, ... }:
    let
      clauth = pkgs.callPackage ../../../../../packages/clauth { };
      # One starter for both supervisors. `>>` opens daemon.log O_APPEND,
      # which the daemon's in-place size cap needs, and creates ~/.clauth on
      # a fresh account, where launchd would fail to open a log path in it.
      # argv0 stays `clauth`: clauth recognises its own daemon by argv
      # (`daemon --replace`, `daemon --status`).
      daemon = pkgs.writeShellScript "clauth-daemon" ''
        # launchd's PATH is the system's; clauth runs `herdr` from PATH.
        PATH="/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
        export PATH
        mkdir -p -m 700 "$HOME/.clauth"
        cd "$HOME/.clauth"
        exec -a clauth ${clauth}/bin/clauth daemon --standby >>"$HOME/.clauth/daemon.log" 2>&1
      '';
    in
    {
      home.packages = [ clauth ];
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      launchd.agents.clauth-daemon = lib.mkIf cfg.daemon.enable {
        enable = true;
        config = {
          ProgramArguments = [ "${daemon}" ];
          RunAtLoad = true;
          # Restart a crash, never a clean exit (wiki/Daemon.md).
          KeepAlive.SuccessfulExit = false;
        };
      };
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      systemd.user.services.clauth-daemon = lib.mkIf cfg.daemon.enable {
        Unit.Description = "clauth decision loop (plain daemon, no listener)";
        Service = {
          ExecStart = "${daemon}";
          Restart = "on-failure";
          # control-group would SIGTERM the gateway and proxies a second time
          # (wiki/Daemon.md).
          KillMode = "process";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
