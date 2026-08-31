# The per-user radicle NODE option -- declared here, not in ./default.nix, so
# it exists on Linux ALONE.
#
# Reach is structural (CLAUDE.md): the implementation in ./linux.nix is a
# home-manager `systemd.user.services` pair, which nix-darwin does not provide.
# Declared cross-platform it would be settable-and-inert on the Mac -- exactly
# the silent no-op the invariant exists to prevent. The CLI itself IS
# cross-platform and stays in ./default.nix.
#
# Shaped like mkApp's own option module: a `my.users` submodule declaration,
# which MERGES with the one ./default.nix produces, adding `node` beneath the
# app option rather than redeclaring it.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf
      (lib.types.submodule {
        options.apps.dev.tools.radicle = {
          node = lib.mkOption {
            default = { };
            description = "This user's radicle node daemon (implemented on Linux only).";
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Run radicle-node as a systemd user service (Linux). Outbound
                    only: it listens nowhere and dials `connect`. Dormant until
                    `rad auth` has created ~/.radicle/keys. This option does not
                    exist on darwin -- run `rad node start` there instead.
                  '';
                };
                connect = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  example = [ "z6Mkgv…@yoga.tailnet.ts.net:8776" ];
                  description = "Static peers, <nid>@<host>:<port> (normally just the seed).";
                };
                alias = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Node alias in gossip; defaults to the user name.";
                };
              };
            };
          };
        };
      });
  };
}
