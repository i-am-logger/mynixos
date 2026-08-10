{ lib, ... }:

{
  options.terminal = lib.mkOption {
    description = "Terminal-centric tools (multiplexers, TUI apps)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable terminal tools";
        };

        # Only "screen" and "none" are named here, because ./default.nix is what
        # implements them. Every other multiplexer contributes its own name from
        # its own options.nix (my/users/apps/multiplexers/*/options.nix):
        # lib.types.enum merges across declarations, so the value set is the
        # union of whatever platforms/*.nix actually imported.
        #
        # The default is owned the same way, by the multiplexer that claims it.
        # It must stay ungated -- the multiplexer modules read this option for
        # every active user, and a declared-but-undefined option throws on read
        # rather than yielding null.
        multiplexer = lib.mkOption {
          type = lib.types.enum [ "screen" "none" ];
          description = "Terminal multiplexer";
        };
      };
    };
  };
}
