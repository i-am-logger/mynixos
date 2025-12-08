{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.users;
  secretsCfg = config.my.secrets;

  # Collect all user mounts
  allMounts = flatten (mapAttrsToList
    (userName: userCfg:
      map (mount: mount // { user = userName; }) userCfg.mounts
    )
    cfg);

  # Only create users that have fullName defined (fully configured users)
  # Users with only mounts/email/yubikeys defined won't be created (they come from myLib.users)
  usersToCreate = filterAttrs (name: userCfg: userCfg.fullName or null != null) cfg;

  # Get users that want sops-managed passwords
  usersWithSopsPassword = filterAttrs
    (name: userCfg: userCfg.secrets.hashedPassword or false)
    usersToCreate;

  # Get password file path for a user
  # Priority: 1. hashedPasswordFile, 2. sops secret (if user.secrets.hashedPassword = true), 3. null (use hashedPassword)
  getPasswordFile = name: userCfg:
    if userCfg.hashedPasswordFile != null then
      userCfg.hashedPasswordFile
    else if secretsCfg.enable && (userCfg.secrets.hashedPassword or false) then
      config.sops.secrets."users/${name}/password".path
    else
      null;
in
{
  config = mkMerge [
    # Define sops secrets for user passwords when secrets are enabled and user opts in
    (mkIf (secretsCfg.enable && usersWithSopsPassword != { }) {
      sops.secrets = listToAttrs (
        map (name: {
          name = "users/${name}/password";
          value = {
            neededForUsers = true;
          };
        }) (attrNames usersWithSopsPassword)
      );
    })

    # Generate NixOS users from my.features.users (only those with fullName)
    (mkIf (usersToCreate != { }) {
      users.users = mapAttrs
        (name: userCfg:
          let
            passwordFile = getPasswordFile name userCfg;
          in
          {
            isNormalUser = true;
            description = userCfg.description or userCfg.fullName;
            # Prefer hashedPasswordFile (including sops) over hashedPassword for security
            hashedPasswordFile = passwordFile;
            hashedPassword = if passwordFile == null
              then userCfg.hashedPassword
              else null;
            home = "/home/${name}";
          group = name; # Create a group with the same name as the user
          extraGroups = [ "wheel" "networkmanager" ]; # Base groups, features add more
          shell =
            if userCfg.shell == "fish" then pkgs.fish
            else if userCfg.shell == "zsh" then pkgs.zsh
            else if userCfg.shell == "bash" then pkgs.bash
            else pkgs.bash; # Default to bash
          packages = userCfg.packages;
        })
        usersToCreate;

      # Create matching groups for each user
      users.groups = mapAttrs (name: _: { }) usersToCreate;

      # Enable required programs based on user shells
      programs.fish.enable = mkIf (any (u: u.shell or null == "fish") (attrValues usersToCreate)) true;
      programs.zsh.enable = mkIf (any (u: u.shell or null == "zsh") (attrValues usersToCreate)) true;

      # Set up user avatars for AccountsService (display manager)
      system.activationScripts = listToAttrs (
        flatten (mapAttrsToList
          (name: userCfg:
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
          )
          usersToCreate)
      );
    })

    # Create filesystem mounts for all users (regardless of how they're defined)
    (mkIf (allMounts != [ ]) {
      fileSystems = listToAttrs (map
        (mount: {
          name = mount.mountPoint;
          value = {
            device =
              if hasPrefix "/dev/" mount.device
              then mount.device
              else "/dev/disk/by-uuid/${mount.device}";
            fsType = mount.fsType;
            options = mount.options;
            noCheck = mount.noCheck;
          };
        })
        allMounts);
    })

    # TODO: Generate Home Manager configs
    # This will be added in Phase 2.2
  ];
}
