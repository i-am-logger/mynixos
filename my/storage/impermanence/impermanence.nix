{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.storage.impermanence;
  persistPath = cfg.persistPath;

  # Get all user names from my.features.users
  userNames = attrNames config.my.users;
in
{
  config = mkIf cfg.enable {
    # Note: Impermanence module is imported separately by the system

    # Setup persist filesystem
    fileSystems."${persistPath}" = mkIf cfg.useDedicatedPartition {
      neededForBoot = true;
    };

    # Create persist directory if not using dedicated partition
    systemd.tmpfiles.rules = mkIf (!cfg.useDedicatedPartition) ([
      "d ${persistPath} 0755 root root -"
      "d ${persistPath}/home 0755 root root -"
    ] ++ (map (user: "d ${persistPath}/home/${user} 0755 ${user} users -") userNames));

    # Persistence configuration
    environment.persistence."${persistPath}" = {
      hideMounts = true;

      # System directories - opinionated defaults
      directories = [
        "/etc/nixos"
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/log"
      ]
      ++ (optionals config.my.graphical.enable [
        "/var/lib/gnome"
        "/var/lib/AccountsService"
        "/var/lib/colord"
        "/var/lib/power-profiles-daemon"
        "/var/lib/upower"
      ])
      ++ (optionals (config.my.hardware.bluetooth.enable or false) [
        "/var/lib/bluetooth"
      ])
      ++ (optionals config.my.dev.enable [
        "/var/lib/docker"
        "/var/lib/containers"
      ])
      ++ (optionals (config.my.ai.enable or false) [
        {
          directory = "/var/lib/ollama";
          user = "ollama";
          group = "ollama";
          mode = "0755";
        }
      ])
      ++ (optionals (config.my.infra.github-runner.enable or false) [
        "/var/lib/rancher"
        "/var/lib/kubelet"
        "/var/lib/cni"
      ])
      ++ (optionals ((config.my.hardware.gpu or null) == "nvidia") [
        "/var/lib/nvidia-persistenced"
      ])
      ++ (optionals (config.my.security.yubikey.enable or false) [
        "/yubikey"
      ])
      ++ cfg.extraSystemDirectories; # Allow custom additions

      # Per-user persistence
      users = mkMerge (map
        (userName: {
          ${userName} = {
            directories = [
              ".local"
              ".cache"
              ".config"
              ".secrets"
              "Documents"
              "Downloads"
            ]
            ++ (optionals cfg.persistUserData [
              "Media"
              "Code"
            ])
            ++ (optionals (config.my.apps.browsers.firefox or false) [
              ".mozilla"
            ])
            ++ (optionals config.my.dev.enable [
              ".docker"
              ".npm"
              ".cargo"
              ".rustup"
              ".gradle"
              ".m2"
              ".vscode"
            ])
            ++ (optionals (config.my.security.yubikey.enable or false) [
              ".gnupg"
              ".password-store"
              ".yubico"
              ".ssh"
            ])
            ++ cfg.extraUserDirectories; # Custom additions (applied to all users)

            files = [
              ".bash_history"
            ] ++ cfg.extraUserFiles; # Custom files (applied to all users)
          };
        })
        userNames);
    };

    # Optional: Clone NixOS config on first boot
    system.activationScripts = mkIf (cfg.cloneFlakeRepo != null) {
      cloneRepoIfEmpty = {
        text = ''
          if [ ! -e /etc/nixos ] || [ -z "$(ls -A /etc/nixos 2>/dev/null)" ]; then
            echo "Cloning flake repository into /etc/nixos..."
            mkdir -p /etc/nixos
            git clone ${cfg.cloneFlakeRepo} /etc/nixos
          fi
        '';
        deps = [ "users" "groups" ];
      };

      createFlakeSymlink = mkIf cfg.symlinkFlakeToHome {
        text = ''
          # Create ~/.flake symlink for all users (auto-detected from my.users)
          ${concatMapStringsSep "\n" (userName: ''
            if [ ! -L /home/${userName}/.flake ]; then
              ln -sfn /etc/nixos /home/${userName}/.flake
              chown ${userName}:users /home/${userName}/.flake
            fi
          '') userNames}
        '';
        deps = [ "users" "groups" "cloneRepoIfEmpty" ];
      };
    };
  };
}
