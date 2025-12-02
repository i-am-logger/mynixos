{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.users;

  # Collect all user mounts
  allMounts = flatten (mapAttrsToList (userName: userCfg:
    map (mount: mount // { user = userName; }) userCfg.mounts
  ) cfg);

  # Only create users that have fullName defined (fully configured users)
  # Users with only mounts/email/yubikeys defined won't be created (they come from myLib.users)
  usersToCreate = filterAttrs (name: userCfg: userCfg.fullName or null != null) cfg;
in
{
  config = mkMerge [
    # Generate NixOS users from my.features.users (only those with fullName)
    (mkIf (usersToCreate != {}) {
      users.users = mapAttrs (name: userCfg: {
        isNormalUser = true;
        description = userCfg.fullName;
        extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
        shell = if userCfg.shell == "fish" then pkgs.fish
                else if userCfg.shell == "zsh" then pkgs.zsh
                else pkgs.bash;
        packages = userCfg.packages;
      }) usersToCreate;

      # Enable required programs based on user shells
      programs.fish.enable = mkIf (any (u: u.shell or null == "fish") (attrValues usersToCreate)) true;
      programs.zsh.enable = mkIf (any (u: u.shell or null == "zsh") (attrValues usersToCreate)) true;
    })

    # Create filesystem mounts for all users (regardless of how they're defined)
    (mkIf (allMounts != []) {
      fileSystems = listToAttrs (map (mount: {
        name = mount.mountPoint;
        value = {
          device = if hasPrefix "/dev/" mount.device
                   then mount.device
                   else "/dev/disk/by-uuid/${mount.device}";
          fsType = mount.fsType;
          options = mount.options;
          noCheck = mount.noCheck;
        };
      }) allMounts);
    })

    # TODO: Generate Home Manager configs
    # This will be added in Phase 2.2
  ];
}
