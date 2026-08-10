# zellij's entry in the terminal.multiplexer enum, declared beside the module
# that implements it rather than in my/users/terminal/options.nix.
#
# lib.types.enum merges across declarations, so this adds "zellij" to whatever
# the other multiplexers contribute. Deliberately no description and no default:
# mergeOptionDecls rejects a second one of either, and the base declaration
# already carries the description.
#
# This is still not an on/off switch -- see ./default.nix for why a second way
# to say the same thing is exactly the bug that was fixed there.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.terminal = lib.mkOption {
        type = lib.types.submodule {
          options.multiplexer = lib.mkOption {
            type = lib.types.enum [ "zellij" ];
          };
        };
      };
    });
  };
}
