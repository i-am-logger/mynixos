{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  # XDG configuration - always enabled for all users
  # This is opinionated: XDG directories are essential for a well-configured system
  config = {
    home-manager.users = mapAttrs
      (_name: _userCfg: {
        home.packages = with pkgs; [
          xdg-utils
        ];

        xdg = {
          enable = true;
          mime.enable = true;
          userDirs.enable = true;
          userDirs.createDirectories = true;
        };
      })
      (activeUsers config.my.users);
  };
}
