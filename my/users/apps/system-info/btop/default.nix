args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.sysinfo.btop";
  home = { pkgs, lib, userCfg, ... }:
    let
      vogixEnabled = userCfg.theming.vogix.enable or false;
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
            cudaSupport = true;
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
