{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  # xdg-utils (xdg-open, xdg-mime, ...) drives the freedesktop MIME/.desktop
  # system; macOS routes the same job through `open` and LaunchServices. userDirs
  # writes ~/.config/user-dirs.dirs, which nothing on macOS reads.
  #
  # `xdg.mime` is deliberately left unset even here: home-manager's own default is
  # already `pkgs.stdenv.hostPlatform.isLinux`, so stating it adds nothing.
  #
  # Imported only by platforms/linux.nix.
  config = {
    home-manager.users = mapAttrs
      (_name: _userCfg: {
        home.packages = [ pkgs.xdg-utils ];

        xdg.userDirs = {
          enable = true;
          createDirectories = true;
        };
      })
      (activeUsers config.my.users);
  };
}
