# herdr's entry in the terminal.multiplexer enum, and the default for the enum
# as a whole.
#
# The default lives here rather than in my/users/terminal/options.nix because
# this is mynixos's opinion about herdr specifically: this fleet runs coding
# agents, and herdr is the only member of the enum that shows which agent is
# running, which is waiting on you, and which is done. Drop herdr from
# platforms/common.nix and the option loses its default, which surfaces as a
# loud "used but not defined" -- the right failure, not a silent fallback to
# something nobody chose.
#
# Only one declaration may carry a default (mergeOptionDecls rejects a second),
# so this file and the base declaration are not interchangeable.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.terminal = lib.mkOption {
        type = lib.types.submodule {
          options.multiplexer = lib.mkOption {
            type = lib.types.enum [ "herdr" ];
            default = "herdr";
          };
        };
      };
    });
  };
}
