# tmux's entry in the terminal.multiplexer enum, declared beside the module that
# implements it rather than in my/users/terminal/options.nix.
#
# lib.types.enum merges across declarations, so this adds "tmux" to whatever the
# other multiplexers contribute. Deliberately no description and no default:
# mergeOptionDecls rejects a second one of either, and the base declaration
# already carries the description.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.terminal = lib.mkOption {
        type = lib.types.submodule {
          options.multiplexer = lib.mkOption {
            type = lib.types.enum [ "tmux" ];
          };
        };
      };
    });
  };
}
