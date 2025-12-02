{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps;
in
{
  config = mkIf cfg.jujutsu {
    home-manager.users = mapAttrs (name: userCfg: {
      programs.jujutsu = {
        enable = true;

        settings = {
          # Pull user data from my.features.users (if available)
          user = mkMerge [
            (mkIf (config.my.users.${name}.fullName or null != null) {
              name = config.my.users.${name}.fullName;
            })
            (mkIf (config.my.users.${name}.email or null != null) {
              email = config.my.users.${name}.email;
            })
          ];

          # Opinionated aliases
          aliases = {
            l = [ "log" "-r" "(main..@):: | (main..@)-" ];
            s = [ "status" ];
            co = [ "new" ];
            sw = [ "edit" ];
            b = [ "bookmark" ];
            c = [ "commit" ];
            a = [ "squash" ];
          };

          # Opinionated settings
          git = {
            auto-local-bookmark = true;
            push-bookmark-prefix = "logger/push-";
          };

          signing = {
            behavior = "own";
            backend = "gpg";
            # Let GPG choose key based on email
            key = config.my.users.${name}.email;
          };

          ui = {
            default-command = "log";
            diff.tool = [ "difft" "--color=always" "$left" "$right" ];
          };
        };
      };
    }) config.my.users;
  };
}
