{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.shells.bash;
in
{
  config = mkIf cfg {
    # Enable bash for all users
    home-manager.users = mapAttrs (name: userCfg: {
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
    }) config.my.users;
  };
}
