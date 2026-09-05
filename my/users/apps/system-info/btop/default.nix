args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.sysinfo.btop";
  option = {
    name = "btop";
    default = false;
    description = "btop system monitor";
    persistedDirectories = [ ];
  };
  home =
    { pkgs
    , lib
    , config
    , userCfg
    , ...
    }:
    let
      vogixEnabled = userCfg.theming.vogix.enable or false;
      # btop's GPU backend follows the system signals: CUDA when cudaSupport is
      # on (the same flag ollama and opencv follow), ROCm on an AMD GPU, neither
      # otherwise. The upstream default pulls CUDA unconditionally -- unfree,
      # large, and monitoring nothing on a non-NVIDIA GPU.
      gpu = config.my.hardware.gpu or null;
      # Read off the resolved package set, not config.nixpkgs.config: the latter
      # forces the nixpkgs.config option, which clashes with read-only nixpkgs
      # (where pkgs is provided externally).
      cudaSupport = pkgs.config.cudaSupport or false;
    in
    lib.mkMerge [
      {
        programs.btop = {
          enable = true;
          settings = {
            update_ms = 100;
            show_gpu_info = "Auto";
            shown_boxes = "cpu mem net proc gpu0";
          };
          package = pkgs.btop.override {
            rocmSupport = gpu == "amd";
            inherit cudaSupport;
          };
        };
      }
      # When vogix is enabled, it manages btop.conf (merged with theme colors).
      # Suppress home-manager's own config file to avoid clobber conflict.
      (lib.mkIf vogixEnabled {
        xdg.configFile."btop/btop.conf".enable = lib.mkDefault false;
      })
    ];
}
