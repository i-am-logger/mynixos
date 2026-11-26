args:

# gopass, a pass-compatible password manager with team stores and git sync,
# over the same ~/.password-store as pass, plus its Brave bridge
# (gopass-jsonapi as a native-messaging host).
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "security.passwords.gopass";
  option = {
    name = "gopass";
    default = false;
    description = "gopass, a pass-compatible password manager";
    persistedDirectories = [ ".password-store" ];
  };
  # `config` here is the system's, so the home comes from the account.
  home = { config, name, pkgs, ... }:
    let
      home = config.users.users.${name}.home;
      wrapper = pkgs.writeShellScript "gopass-wrapper" ''
        GPG_TTY="$(tty 2>/dev/null)" && export GPG_TTY
        exec ${pkgs.gopass-jsonapi}/bin/gopass-jsonapi listen
      '';
    in
    {
      home.packages = [ pkgs.gopass pkgs.gopass-jsonapi ];

      home.file = {
        ".config/gopass/config.yml" = {
          text = ''
            core:
              autopush: true
              autosync: true
              cliptimeout: 45
              exportkeys: true
              notifications: true
              follow-references: false
            pwgen:
              xkcd-lang: en
            mounts:
              path: ${home}/.password-store
          '';
          force = true;
        };

        ".config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.justwatch.gopass.json" = {
          text = builtins.toJSON {
            name = "com.justwatch.gopass";
            description = "Gopass wrapper to search and return passwords";
            path = "${wrapper}";
            type = "stdio";
            allowed_origins = [ "chrome-extension://kkhfnlkhiapbiehimabddjbimfaijdhk/" ];
          };
          force = true;
        };
      };
    };
}
