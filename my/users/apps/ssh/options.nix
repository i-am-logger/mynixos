# Agent forwarding targets.
#
# Declared beside ./default.nix, the only thing that reads it. ssh is always on
# and has no `enable`, so the option lives in this sibling file — the same shape
# git, claude-code and 1password use.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.terminal.network.ssh.forwardAgentHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "yoga" ];
        description = ''
          Hosts that get `ForwardAgent yes`.

          Forwarding hands the far end a socket that signs with this machine's
          key for the life of the connection, so root there can ask for any
          signature the agent will make. That is a per-host trust decision:
          this is a list of named hosts, and `*` does not belong in it.

          The far end consumes it by setting `my.security.sshAgentSudo`, which
          authenticates sudo against the forwarded agent instead of against a
          security key plugged into that machine.
        '';
      };
    });
  };
}
