{ config, lib, pkgs, ... }:

with lib;

{
  # Jujutsu configuration - always enabled for all users
  # This is opinionated: jujutsu is provided as an alternative to git
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: {
        programs.jujutsu = {
          enable = true;

          settings = {
            # Pull user data from my.users (if available)
            user = optionalAttrs (config.my.users.${name}.fullName or null != null)
              {
                name = config.my.users.${name}.fullName;
              } // optionalAttrs (config.my.users.${name}.email or null != null) {
              email = config.my.users.${name}.email;
            };

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

            # Opinionated settings (with mkDefault for easy override)
            git = {
              auto-local-bookmark = mkDefault true;
              push-bookmark-prefix = mkDefault "${name}/push-";
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
      })
      config.my.users;
  };
}
