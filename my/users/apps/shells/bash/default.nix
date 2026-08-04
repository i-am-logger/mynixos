{ lib, ... }@args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.shells.bash";
  option = {
    name = "Bash";
    default = false;
    description = "Bash shell";
    persistedFiles = [ ".bash_history" ];
    extraOptions = {
      historySize = lib.mkOption {
        type = lib.types.int;
        default = 10000;
        description = "Number of commands to keep in history";
      };
      historyFileSize = lib.mkOption {
        type = lib.types.int;
        default = 10000;
        description = "Number of lines to keep in history file";
      };
      historyControl = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "ignoredups"
          "ignorespace"
        ];
        description = "History control options";
      };
      shellOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "histappend"
          "checkwinsize"
          "extglob"
          "globstar"
          "checkjobs"
        ];
        description = "Shell options (shopt)";
      };
    };
  };
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
  };
}
