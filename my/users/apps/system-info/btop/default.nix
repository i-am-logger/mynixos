{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          vogixEnabled = userCfg.themes.vogix.enable or false;
        in
        mkIf userCfg.apps.terminal.sysinfo.btop.enable (mkMerge [
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
          (mkIf vogixEnabled {
            xdg.configFile."btop/btop.conf".enable = mkDefault false;
          })
        ]))
      (activeUsers config.my.users);
  };
}
