{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.storage.impermanence;
  persistPath = cfg.persistPath;

  # Get all user names from my.features.users
  userNames = attrNames config.my.users;

  # Get app-specific directories for a user from aggregation
  getUserAppDirectories =
    userName: config.my.system.persistence.aggregated.${userName}.directories or [ ];
in
{
  config = mkIf cfg.enable {
    # Note: Impermanence module is imported separately by the system

    # Setup persist filesystem
    fileSystems."${persistPath}" = mkIf cfg.useDedicatedPartition {
      neededForBoot = true;
    };

    # Bind-mount ccache from persist to /tmp/ccache
    fileSystems."/tmp/ccache" = mkIf cfg.enableCcache {
      device = "${persistPath}/cache/ccache";
      fsType = "none";
      options = [ "bind" ];
      neededForBoot = false; # ccache isn't needed for boot
    };

    # Enable ccache system-wide with proper configuration
    programs.ccache = mkIf cfg.enableCcache {
      enable = true;
      cacheDir = "/tmp/ccache";
      # Note: This will automatically set up proper permissions (0770 root:nixbld)
      # and wrap compilers system-wide
    };

    # Set CCACHE_DIR environment variable system-wide for all users
    # This ensures manual use of ccache (e.g., in nix-shell) uses the system cache
    environment.sessionVariables = mkIf cfg.enableCcache {
      CCACHE_DIR = "/tmp/ccache";
    };

    # Create persist directory if not using dedicated partition
    systemd.tmpfiles.rules =
      (optionals (!cfg.useDedicatedPartition) (
        [
          "d ${persistPath} 0755 root root -"
          "d ${persistPath}/home 0755 root root -"
        ]
        ++ (map (user: "d ${persistPath}/home/${user} 0755 ${user} users -") userNames)
      ))
      ++ (optionals cfg.enableCcache [
        "d ${persistPath}/cache 0755 root root -"
        "d ${persistPath}/cache/ccache 0775 root nixbld -"
        "d /tmp/ccache 0775 root nixbld -"
      ]);

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
      ++ cfg.extraSystemDirectories # Allow custom additions
      ++ config.my.system.persistence.features.systemDirectories; # Feature-declared system directories

      # Per-user persistence
      users = mkMerge (
        map
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
              # App-specific directories from aggregation
              ++ (getUserAppDirectories userName)
              # Feature-declared user directories
              ++ config.my.system.persistence.features.userDirectories
              ++ cfg.extraUserDirectories; # Custom additions (applied to all users)

              files = cfg.extraUserFiles # Custom files (applied to all users)
                ++ config.my.system.persistence.features.userFiles; # Feature-declared user files
            };
          })
          userNames
      );
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
        deps = [
          "users"
          "groups"
        ];
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
        deps = [
          "users"
          "groups"
          "cloneRepoIfEmpty"
        ];
      };
    };
  };
}
