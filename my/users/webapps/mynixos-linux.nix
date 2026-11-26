# mynixos Opinionated Defaults: webapps that are really native apps.
#
# Three entries under `graphical.webapps` name programs that are not web apps at
# all -- Slack, Signal and 1Password ship desktop binaries, and this module used
# to install them itself while equivalent app modules sat unused at
# enable = false. The flags now SET those app options, so installation,
# persistence and unfree handling run through the app modules like everything
# else, and there is one place that decides what "slack is on" means.
#
# Linux only, like `graphical.webapps` itself (my/users/graphical/options-linux.nix):
# on a Mac those apps are set directly. Imported only by platforms/linux.nix.
#
# The rest of `graphical.webapps` really is browser-based and stays in
# ./default.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf config.graphical.webapps.enable {
        apps = {
          communication.messaging.slack.enable =
            lib.mkDefault config.graphical.webapps.slack;
          communication.messaging.signal.enable =
            lib.mkDefault config.graphical.webapps.signal;
          security.passwords.onePassword.enable =
            lib.mkDefault config.graphical.webapps.onePassword;
        };
      };
    }));
  };
}
