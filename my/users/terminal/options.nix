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
          default = "zellij";
          description = "Terminal multiplexer";
        };

        # fileManagers: REMOVED - use environment.fileManager(s) instead

        btop = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "btop system monitor";
        };

        htop = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "htop system monitor";
        };

        fastfetch = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "fastfetch system info";
        };

        neofetch = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "neofetch system info";
        };

        bat = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "bat file viewer";
        };

        lsd = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "lsd directory lister";
        };

        termscp = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "termscp TUI file transfer";
        };

        pipes = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Terminal eye candy";
        };

        cava = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "cava audio visualizer";
        };
      };
    };
  };
}
