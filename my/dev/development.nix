{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable dev tools when any user has dev = true
  anyUserDev = any (userCfg: userCfg.dev or false) (attrValues config.my.users);

  # Docker enabled if any user has dev OR explicitly enables docker
  anyUserDocker = any (u: (u.dev or false) || (u.docker.enable or false)) (attrValues config.my.users);
in
{
  config = mkMerge [
    # Base development groups
    (mkIf anyUserDev {
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "disk" "dialout" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);
    })

    # Docker - runs as user (rootless)
    (mkIf anyUserDocker {
      virtualisation.docker = {
        enable = true;
        enableOnBoot = false;
        rootless = {
          enable = true;
          setSocketVariable = true;
        };
      };

      # Add users with dev or docker.enable to docker group
      users.users = mapAttrs (name: userCfg: {
        extraGroups = mkIf ((userCfg.dev or false) || (userCfg.docker.enable or false)) [ "docker" ];
      }) (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

      # Docker tools
      environment.systemPackages = with pkgs; [
        docker-compose
        minikube
        runc
        lazydocker
      ];
    })

    # Binfmt emulation (dev feature)
    (mkIf anyUserDev {
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];

        # AppImage support
        registrations.appimage = {
          wrapInterpreterInShell = false;
          interpreter = "${pkgs.appimage-run}/bin/appimage-run";
          recognitionType = "magic";
          offset = 0;
          mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
          magicOrExtension = ''\x7fELF....AI\x02'';
        };
      };
    })
  ];
}
