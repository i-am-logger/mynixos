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

        multiplexer = lib.mkOption {
          type = lib.types.enum [ "zellij" "tmux" "screen" "none" ];
          default = "tmux";
          description = "Terminal multiplexer";
        };
      };
    };
  };
}
