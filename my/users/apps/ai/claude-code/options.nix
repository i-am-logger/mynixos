# Claude Code option.
#
# Declared beside ./default.nix, which is the only thing that reads it. Common,
# because the CLI runs on both platforms.

{ lib, ... }:

let
  appLib = import ../../../../../lib/app-options.nix { inherit lib; };

  # One Claude.ai login. Claude Code keeps exactly one credential per config
  # directory, so an account is a config directory: ~/.claude for the default
  # account, ~/.claude-accounts/<alias> for every other one.
  account = lib.types.submodule {
    options = {
      email = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Claude.ai login for this account (shown by `claude-accounts`; the token itself comes from `/login`)";
      };
      directories = lib.mkOption {
        type = lib.types.listOf lib.types.nonEmptyStr;
        default = [ ];
        example = [ "~/Code/client" ];
        description = ''
          Directory trees that select this account when `claude` starts inside
          them. A leading `~/` means the user's home. The longest matching
          prefix wins, so a tree can sit inside another account's tree.
        '';
      };
    };
  };
in
{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.ai.tools.claude-code = appLib.mkAppOption {
        name = "Claude Code";
        default = false;
        description = "Claude Code AI coding assistant";
        persistedDirectories = [ ".claude" ".claude-accounts" ];
        persistedFiles = [ ".claude.json" ];
        extraOptions = {
          cloneConfigRepo = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "Git URL to clone into ~/.claude on first boot (syncs settings, memory, todos across machines)";
          };
          accounts = lib.mkOption {
            type = lib.types.attrsOf account;
            default = { };
            example = lib.literalExpression ''
              {
                personal = { email = "me@example.com"; };
                client = { email = "me@client.example"; directories = [ "~/Code/client" ]; };
              }
            '';
            description = ''
              Claude.ai accounts by alias. With more than the default account
              declared, `claude` becomes a wrapper that picks the account from
              the working directory (or from `CLAUDE_ACCOUNT`, or via
              `claude-as <alias>`) and points `CLAUDE_CONFIG_DIR` at it. Every
              non-default account directory holds only its own credential;
              settings, sessions, memory, plugins and history are symlinks into
              ~/.claude, so switching accounts never splits them.
            '';
          };
          defaultAccount = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "Alias of the account that lives in ~/.claude itself. Required when `accounts` is non-empty";
          };
        };
      };
    });
  };
}
