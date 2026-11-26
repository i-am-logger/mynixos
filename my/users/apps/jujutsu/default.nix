{ activeUsers, config, lib, ... }:

with lib;

let
  osConfig = config; # the system config; `config` below is the user's HM config
in

{
  # Jujutsu configuration for every user -- config only. jj itself is a
  # development tool and comes from the dev workspace's devenv
  # (apps.dev.tools.devenv.workspace), not the host.
  #
  # programs.jujutsu.settings stays the merge point (my/hardware/security-keys
  # adds signing to it), but HM's module itself stays OFF: with its package
  # null it still reads that package's version on darwin to pick a config
  # directory, and fails. The merged settings are rendered here instead, to
  # ~/.config/jj, which jj 0.29+ reads on both platforms.
  config = {
    home-manager.users = mapAttrs
      (name: _userCfg: { config, pkgs, ... }: {
        xdg.configFile."jj/config.toml".source =
          (pkgs.formats.toml { }).generate "jj-config.toml" config.programs.jujutsu.settings;

        programs.jujutsu.settings = {
          # Pull user data from my.users (if available)
          user = optionalAttrs (osConfig.my.users.${name}.fullName or null != null)
            {
              name = osConfig.my.users.${name}.fullName;
            } // optionalAttrs (osConfig.my.users.${name}.email or null != null) {
            inherit (osConfig.my.users.${name}) email;
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
            key = osConfig.my.users.${name}.email;
          };

          ui = {
            default-command = "log";
            diff.tool = [ "difft" "--color=always" "$left" "$right" ];
          };
        };
      })
      (activeUsers config.my.users);
  };
}
