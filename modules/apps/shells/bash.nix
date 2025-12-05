{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.shells.bash {
      programs.bash = {
        enable = true;
        enableCompletion = true;

        # Basic bash configuration
        historyControl = [ "ignoredups" "ignorespace" ];
        historyFile = "$HOME/.bash_history";
        historyFileSize = 10000;
        historySize = 10000;

        shellOptions = [
          "histappend"
          "checkwinsize"
          "extglob"
          "globstar"
          "checkjobs"
        ];
      };
        }
      )
      config.my.users;
  };
}
