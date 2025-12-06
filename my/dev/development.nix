{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable dev tools when any user has dev.enable = true
  anyUserDev = any (userCfg: userCfg.dev.enable or false) (attrValues config.my.users);

  # Docker enabled if any user has dev enabled AND docker not explicitly disabled
  anyUserDocker = any (u: (u.dev.enable or false) && (u.dev.docker.enable or true)) (attrValues config.my.users);
in
{
  config = mkMerge [
    # Set system flag
    { my.dev.enable = anyUserDev; }

    # Base development groups
    (mkIf config.my.dev.enable {
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

      # Add users with dev enabled (and docker not disabled) to docker group
      users.users = mapAttrs (name: userCfg: {
        extraGroups = mkIf ((userCfg.dev.enable or false) && (userCfg.dev.docker.enable or true)) [ "docker" ];
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
    (mkIf config.my.dev.enable {
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
