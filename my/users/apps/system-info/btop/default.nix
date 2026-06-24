args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.sysinfo.btop";
  home = { pkgs, lib, config, userCfg, ... }:
    let
      vogixEnabled = userCfg.theming.vogix.enable or false;
      # Match btop's GPU backend to the host GPU (my.hardware.gpu): ROCm for AMD,
      # CUDA for NVIDIA, neither otherwise. The default pulls CUDA, which is
      # unfree, large, and monitors nothing on a non-NVIDIA GPU.
      gpu = config.my.hardware.gpu or null;
    in
    lib.mkMerge [
      {
        programs.btop = {
          enable = true;
          settings = {
            update_ms = 100;
            show_gpu_info = "On";
            shown_boxes = "cpu mem net proc gpu0";
          };
          package = pkgs.btop.override {
            rocmSupport = gpu == "amd";
            cudaSupport = gpu == "nvidia";
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
