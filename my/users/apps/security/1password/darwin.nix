# 1Password on macOS.
#
# The Linux counterpart (./default.nix) turns on programs._1password{,-gui} --
# the CLI, the browser-integration helper and its SUID policy file. macOS ships
# all of that inside the .app bundle, so the whole implementation here is:
# install the bundle, and let the unfree predicate see it.
#
# environment.systemPackages rather than home.packages: system.build.applications
# is assembled from systemPackages, and nix-darwin rsyncs real .app bundles into
# "/Applications/Nix Apps", which Spotlight and LaunchServices index. A
# home.packages symlink under ~/Applications is not launchable the same way.
#
# The unfree names go through my.system.allowedUnfreePackages rather than
# nixpkgs.config directly, so my/system/unfree propagates the predicate to both
# the system pkgs and home-manager's separate instance.
#
# Imported only by platforms/darwin.nix.
{ config, lib, pkgs, ... }:

with lib;

let
  anyUser1Password = any
    (userCfg: userCfg.apps.security.passwords.onePassword.enable or false)
    (attrValues config.my.users);
in
{
  config = mkIf anyUser1Password {
    environment.systemPackages = [ pkgs._1password-gui ];

    # The CLI, same as the Linux side. nix-darwin's module installs `op` to
    # /usr/local/bin, which is where the desktop app looks for it when turning on
    # "Integrate with 1Password CLI" -- without it the GUI has nothing to talk to.
    programs._1password.enable = true;

    my.system.allowedUnfreePackages = [
      "1password-gui"
      "1password"
      "1password-cli"
    ];
  };
}
