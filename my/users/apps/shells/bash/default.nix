{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          cfg = userCfg.apps.terminal.shells.bash;
        in
        mkIf (cfg.enable or false) {
          programs.bash = {
            enable = true;
            enableCompletion = true;

            # Configuration from user options
            historyControl = cfg.historyControl;
            historyFile = "$HOME/.bash_history";
            historyFileSize = cfg.historyFileSize;
            historySize = cfg.historySize;
            shellOptions = cfg.shellOptions;
          };

          # fzf integration for enhanced history search (Ctrl+R, Ctrl+T, Alt+C)
          programs.fzf = {
            enable = true;
            enableBashIntegration = true;
          };
        })
      config.my.users;
  };
}
