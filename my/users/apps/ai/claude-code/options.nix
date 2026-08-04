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
        };
      };
    });
  };
}
