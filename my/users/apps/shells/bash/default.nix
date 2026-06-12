args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.shells.bash";
  home = { cfg, ... }: {
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
  };
}
