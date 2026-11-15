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
    type = lib.types.attrsOf (lib.types.submodule {
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
            };
            description = ''
              Keys deep-merged into ~/.claude/settings.json at activation.
              Every other key there stays Claude Code's own, and the file
              stays writable (it is never a store link), so Claude Code can
              still save its settings. An empty set leaves the file alone.
            '';
          };
        };
      };
    });
  };
}
