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
        description = userCfg.description or userCfg.fullName;
        hashedPassword = userCfg.hashedPassword;
        extraGroups = [ "wheel" "networkmanager" ];  # Base groups, features add more
        shell = if userCfg.shell == "fish" then pkgs.fish
                else if userCfg.shell == "zsh" then pkgs.zsh
                else if userCfg.shell == "bash" then pkgs.bash
                else pkgs.bash;  # Default to bash
        packages = userCfg.packages;
      }) usersToCreate;

      # Enable required programs based on user shells
      programs.fish.enable = mkIf (any (u: u.shell or null == "fish") (attrValues usersToCreate)) true;
      programs.zsh.enable = mkIf (any (u: u.shell or null == "zsh") (attrValues usersToCreate)) true;

      # Set up user avatars for AccountsService (display manager)
      system.activationScripts = listToAttrs (
        flatten (mapAttrsToList (name: userCfg:
          optional (userCfg.avatar != null) {
            name = "userAvatar-${name}";
            value = {
              text = ''
                # Create directory for user icons if it doesn't exist
                mkdir -p /var/lib/AccountsService/icons
                mkdir -p /var/lib/AccountsService/users

                # Copy the user avatar to the standard location
                cp ${userCfg.avatar} /var/lib/AccountsService/icons/${name}
                chmod 644 /var/lib/AccountsService/icons/${name}

                # Create AccountsService user configuration
                cat > /var/lib/AccountsService/users/${name} << EOF
                [User]
                Icon=/var/lib/AccountsService/icons/${name}
                EOF
                chmod 644 /var/lib/AccountsService/users/${name}
              '';
              deps = [ "users" ];
            };
          }
        ) usersToCreate)
      );
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
