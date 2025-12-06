{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable dev tools when any user has dev = true
  anyUserDev = any (userCfg: userCfg.dev or false) (attrValues config.my.users);

  # Get list of all user names
  userNames = attrNames config.my.users;

  # Docker should be enabled when any user has dev = true OR explicitly enabled
  dockerEnabled = anyUserDev || (config.my.infra.docker.enable or false);
in
{
  config = mkIf anyUserDev (mkMerge [
    # Base development groups
    {
      # Add users to development-related groups
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "disk" "dialout" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

      # Auto-enable Docker infrastructure when any user has dev = true
      my.infra.docker.enable = mkDefault true;
    }

    # Docker support (enabled when dockerEnabled is true)
    (mkIf dockerEnabled {
      environment.systemPackages = with pkgs; [
        docker-compose
        minikube
        runc
        lazydocker
      ];

      # Add all users to docker group
      users.groups.docker.members = userNames;

      # Also add created users to docker group
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "docker" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

      virtualisation.docker = {
        enable = true;
        enableOnBoot = false;
        rootless = {
          enable = true;
          setSocketVariable = true;
        };
      };
    })

    # Binfmt emulation support - always enable for dev users
    {
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];
      };

      # AppImage support
      boot.binfmt.registrations.appimage = {
        wrapInterpreterInShell = false;
        interpreter = "${pkgs.appimage-run}/bin/appimage-run";
        recognitionType = "magic";
        offset = 0;
        mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
        magicOrExtension = ''\x7fELF....AI\x02'';
      };
    }
  ]);
}
