# Claude Code option.
#
# Declared beside ./default.nix, which is the only thing that reads it. Common,
# because the CLI runs on both platforms.

{ lib, ... }:

let
  appLib = import ../../../../../lib/app-options.nix { inherit lib; };
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options.apps.ai.tools.claude-code = appLib.mkAppOption {
        name = "Claude Code";
        default = false;
        description = "Claude Code AI coding assistant";
        persistedDirectories = [ ".claude" ];
        persistedFiles = [ ".claude.json" ];
        extraOptions = {
          cloneConfigRepo = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "Git URL to clone into ~/.claude on first boot (syncs settings, memory, todos across machines)";
          };

          mergedSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {
              # Session transcripts are kept, not deleted after 30 days:
              # about a thousand years.
              cleanupPeriodDays = 365000;
              # No co-author trailer or generated-by line in commits and PRs.
              includeCoAuthoredBy = false;
              attribution = { commit = ""; pr = ""; };
              # Compact the conversation only as it nears an 800k-token window.
              autoCompactWindow = 800000;
            };
            description = ''
              Keys deep-merged into ~/.claude/settings.json at activation.
              Every other key there stays Claude Code's own, and the file
              stays writable (it is never a store link), so Claude Code can
              still save its settings. An empty set leaves the file alone.
            '';
          };

          accounts = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "[a-z0-9][a-z0-9-]*");
            default = [ ];
            description = ''
              Extra Claude Code accounts. Each name gets its own folder,
              ~/.claude-<name>, to run with CLAUDE_CONFIG_DIR pointing at it;
              the default account keeps ~/.claude and runs with
              CLAUDE_CONFIG_DIR unset. Each folder is persisted like
              ~/.claude, and holds that account's login (.claude.json,
              .credentials.json); projects, sessions, CLAUDE.md and
              settings.json in it are links to ~/.claude's. Names are one
              path segment and unique. An empty list changes nothing.
            '';
          };
        };
      };

      # One more persisted folder per account, merged with the ".claude"
      # default (mkOptionDefault, the default's own priority; an ordinary
      # definition would replace ".claude" instead).
      config.apps.ai.tools.claude-code.persistedDirectories = lib.mkOptionDefault
        (map (n: ".claude-${n}") config.apps.ai.tools.claude-code.accounts);
    }));
  };
}
