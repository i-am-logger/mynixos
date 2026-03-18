{ activeUsers, config, lib, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          cfg = userCfg.apps.terminal.shells.bash;
        in
        mkIf cfg.enable {
          programs.bash = {
            enable = true;
            enableCompletion = true;

            # Configuration from user options
            inherit (cfg) historyControl;
            historyFile = "$HOME/.bash_history";
            inherit (cfg) historyFileSize;
            inherit (cfg) historySize;
            inherit (cfg) shellOptions;
          };

          # fzf integration for enhanced history search (Ctrl+R, Ctrl+T, Alt+C)
          programs.fzf = {
            enable = true;
            enableBashIntegration = true;
          };
        })
      (activeUsers config.my.users);
  };
}
