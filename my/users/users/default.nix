{ activeUsers, config, lib, pkgs, ... }:

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
  usersToCreate = activeUsers cfg;

  # Get users that want sops-managed passwords
  usersWithSopsPassword = filterAttrs
    (_name: userCfg: userCfg.secrets.hashedPassword or false)
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
    # ACCOUNTS ARE DATA, SO THE ACCOUNT DATABASE IS AN OUTPUT.
    #
    # Every password this DSL knows about is declarative: a sops
    # hashedPasswordFile, or a hashedPassword stated in the user's own
    # profile. `mutableUsers = true` -- nixpkgs' default, and what this was
    # before -- says the opposite: that /etc/shadow is authoritative and
    # `passwd` is how you change a password.
    #
    # On a host whose root is a tmpfs that is a LIE WITH NO ERROR. `passwd`
    # succeeds, prints nothing alarming, and update-users-groups.pl
    # regenerates /etc/shadow from this config at the next activation --
    # so the change is gone at the next boot and nothing ever said so.
    # Persisting /etc/shadow is the obvious-looking fix and it is worse: it
    # makes a second source of truth that a rotated sops secret no longer
    # overrides, so the OLD password keeps working after you rotate it.
    #
    # So the database is stated to be derived. `passwd` now fails outright,
    # which is the honest answer, and a host that genuinely keeps mutable
    # accounts says so by setting this back to true -- see
    # systems/skyspy-dev in the consumer flake, whose root is real ext4.
    #
    # mkDefault, not a hard definition: this is an opinion, and it is the
    # one place where being wrong locks every account out of a machine.
    { users.mutableUsers = mkDefault false; }

    # Define sops secrets for user passwords when secrets are enabled and user opts in
    (mkIf (secretsCfg.enable && usersWithSopsPassword != { }) {
      sops.secrets = listToAttrs (
        map
          (name: {
            name = "users/${name}/password";
            value = {
              neededForUsers = true;
            };
          })
          (attrNames usersWithSopsPassword)
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
            hashedPassword =
              if passwordFile == null
              then userCfg.hashedPassword
              else null;
            home = "/home/${name}";
            group = name; # Create a group with the same name as the user
            # Base groups; each feature adds its own, for the users who turned
            # it on. Only an admin is in wheel (root via sudo, nix trust).
            extraGroups = optional userCfg.admin "wheel"
              ++ optional config.networking.networkmanager.enable "networkmanager";
            shell =
              if userCfg.shell == "fish" then pkgs.fish
              else if userCfg.shell == "zsh" then pkgs.zsh
              else if userCfg.shell == "bash" then pkgs.bash
              else pkgs.bash; # Default to bash
            inherit (userCfg) packages;
          })
        usersToCreate;

      # Create matching groups for each user
      users.groups = mapAttrs (_name: _: { }) usersToCreate;

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
                  set -e
                  mkdir -p /var/lib/AccountsService/icons
                  mkdir -p /var/lib/AccountsService/users

                  # Atomic copy: write to temp then move
                  cp ${userCfg.avatar} /var/lib/AccountsService/icons/${name}.tmp
                  chmod 644 /var/lib/AccountsService/icons/${name}.tmp
                  mv /var/lib/AccountsService/icons/${name}.tmp /var/lib/AccountsService/icons/${name}

                  # Atomic config write
                  cat > /var/lib/AccountsService/users/${name}.tmp << EOF
                  [User]
                  Icon=/var/lib/AccountsService/icons/${name}
                  EOF
                  chmod 644 /var/lib/AccountsService/users/${name}.tmp
                  mv /var/lib/AccountsService/users/${name}.tmp /var/lib/AccountsService/users/${name}
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
      assertions = map
        (mount: {
          assertion = hasPrefix "/" mount.mountPoint;
          message = "Mount point must be an absolute path, got: '${mount.mountPoint}' (user: ${mount.user})";
        })
        allMounts;

      fileSystems = listToAttrs (map
        (mount: {
          name = mount.mountPoint;
          value = {
            device =
              if hasPrefix "/dev/" mount.device
              then mount.device
              else "/dev/disk/by-uuid/${mount.device}";
            inherit (mount) fsType;
            inherit (mount) options;
            inherit (mount) noCheck;
          };
        })
        allMounts);
    })

  ];
}
