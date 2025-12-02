{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.development;

  # Get list of all user names from my.features.users
  userNames = attrNames config.my.users;
in
{
  config = mkIf cfg.enable (mkMerge [
    # Docker support
    (mkIf cfg.docker.enable {
      environment.systemPackages = with pkgs; [
        docker-compose
        minikube
        runc
        lazydocker
      ];

      # Add all users to docker group
      users.groups.docker.members = userNames;

      virtualisation.docker = {
        enable = true;
        enableOnBoot = false;
        rootless = {
          enable = true;
          setSocketVariable = true;
        };
      };
    })

    # Direnv support
    (mkIf cfg.direnv.enable {
      environment.systemPackages = with pkgs; [
        direnv
      ];

      programs.direnv = {
        enable = true;
        silent = true;
        direnvrcExtra = ''
          echo "Loaded direnv!"
        '';
      };
    })

    # Binfmt emulation support
    (mkIf cfg.binfmt.enable {
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];
      };
    })

    # AppImage support (now under binfmt)
    (mkIf cfg.binfmt.appimage {
      boot.binfmt.registrations.appimage = {
        wrapInterpreterInShell = false;
        interpreter = "${pkgs.appimage-run}/bin/appimage-run";
        recognitionType = "magic";
        offset = 0;
        mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
        magicOrExtension = ''\x7fELF....AI\x02'';
      };
    })
  ]);
}
