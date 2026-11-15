{ config
, lib
, pkgs
, utils
, ...
}:

with lib;

let
  cfg = config.my.storage.impermanence;
  inherit (cfg) persistPath;
  etcNixosLink = config.my.system.etcNixos.link;

  # Get all user names from my.features.users
  userNames = attrNames config.my.users;

  # Get app-specific directories for a user from aggregation
  getUserAppDirectories =
    userName: config.my.system.persistence.aggregated.${userName}.directories or [ ];

  # Get app-specific files for a user from aggregation
  getUserAppFiles =
    userName: config.my.system.persistence.aggregated.${userName}.files or [ ];
in
{
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasPrefix "/" persistPath;
        message = "my.storage.impermanence.persistPath must be an absolute path, got: ${persistPath}";
      }
      {
        # The clone's tests would follow the link and act on the checkout.
        assertion = cfg.cloneFlakeRepo == null || etcNixosLink == null;
        message = "my.storage.impermanence.cloneFlakeRepo clones into /etc/nixos, which my.system.etcNixos.link makes a link to an existing checkout; set one or the other.";
      }
    ];

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

      # System directories - core NixOS infrastructure
      # Additional system directories are declared by feature modules
      # /etc/nixos is hardcoded deliberately. This module is Linux-only
      # (platforms/linux.nix), /etc/nixos is the NixOS convention, and both hosts
      # use it. It is NOT wired to my.system.flakeDir: that option exists so the
      # rebuild-system scripts can FIND the flake at runtime on darwin, where no
      # convention exists. Coupling them would mean a scripts-convenience setting
      # silently changes what a tmpfs-root host persists — and pointing it at a
      # /home path would put a user path in the SYSTEM persistence list. Data loss
      # is not worth the tidiness.
      # `unique` is load-bearing, not tidiness. Two independent features may each
      # need the same directory to survive a wipe, and both are right to say so:
      # my/dev/development persists /var/lib/containers for a developer's podman,
      # and a container-hosting role persists it because a forge must not depend
      # on developer tooling being enabled. impermanence rejects a repeated path
      # outright ("specified two or more times"), so without this the two cannot
      # coexist on one host — and the failure is a build error naming a directory,
      # with nothing to say which modules asked for it.
      #
      # The per-user path already does exactly this (aggregation.nix), so this
      # makes the system list agree with it rather than introducing a new rule.
      #
      # With my.system.etcNixos.link set, /etc/nixos is a link to a checkout
      # (my/system/etc-nixos) and is not persisted here: a bind mount would sit
      # where the link goes. The link's TARGET is not added in its place --
      # that is the user path the paragraph above keeps out of this list; a
      # checkout under /home is persisted as that person's own directory.
      directories = unique ((optional (etcNixosLink == null) "/etc/nixos") ++ [
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/log"
      ]
        # The state of NixOS services that are on but have no mynixos module
        # to declare it, keyed on the service itself so the list follows what
        # actually runs: NetworkManager's saved networks (0700, they hold
        # Wi-Fi and VPN secrets) and its secret_key (the IPv6 stable-privacy
        # seed); boltd's Thunderbolt/USB4 approvals; fwupd's update history;
        # OpenRGB's device configuration.
        ++ optionals config.networking.networkmanager.enable [
        { directory = "/etc/NetworkManager/system-connections"; mode = "0700"; }
        "/var/lib/NetworkManager"
      ]
        ++ optional config.services.hardware.bolt.enable "/var/lib/boltd"
        ++ optional config.services.fwupd.enable "/var/lib/fwupd"
        ++ optional config.services.hardware.openrgb.enable "/var/lib/OpenRGB"
        ++ cfg.extraSystemDirectories # Allow custom additions
        ++ config.my.system.persistence.features.systemDirectories); # Feature-declared system directories

      # machine-id is minted afresh on a tmpfs root at every boot, and
      # journald files each boot's logs under it, so without this
      # `journalctl --list-boots` never reaches past the current boot, DHCP
      # client ids move, and machine-keyed state sees a new host each boot.
      # Rotating it buys little: hostname, MACs, DMI and disk serials stay
      # put regardless.
      #
      # It stays local. machine-id(5) calls it confidential, not to be
      # exposed off the machine, so it is a persisted file and never a value
      # in a host's (possibly public) configuration; anything needing an id
      # that leaves the box derives one with sd_id128_get_machine_app_specific
      # (`systemd-id128 machine-id --app-specific=<uuid>`). Rotation is a
      # deliberate event: remove the persisted copy and run
      # systemd-machine-id-setup (or reboot). Stage 2 activation links it
      # before systemd starts.
      files = [ "/etc/machine-id" ];

      # Per-user persistence
      users = mkMerge (
        map
          (userName: {
            ${userName} = {
              # Base directories are declared by their respective feature modules
              # (environment, secrets, dev, etc.)
              directories =
                # This person's own folders. Software declares its own state
                # separately (below); this is only for directories that belong to
                # the human -- Code, Media and the like.
                (config.my.users.${userName}.persistedDirectories or [ ])
                # App-specific directories from aggregation
                ++ (getUserAppDirectories userName)
                # Feature-declared user directories
                ++ config.my.system.persistence.features.userDirectories
                ++ cfg.extraUserDirectories; # Custom additions (applied to all users)

              files = cfg.extraUserFiles # Custom files (applied to all users)
                ++ config.my.system.persistence.features.userFiles # Feature-declared user files
                ++ (getUserAppFiles userName); # App-declared user files
            };
          })
          userNames
      );
    };

    # Optional: Clone NixOS config on first boot
    system.activationScripts = mkMerge [
      (mkIf (cfg.cloneFlakeRepo != null) {
        cloneRepoIfEmpty = {
          text = ''
            if [ ! -e /etc/nixos ] || [ -z "$(ls -A /etc/nixos 2>/dev/null)" ]; then
              echo "Cloning flake repository into /etc/nixos..."
              mkdir -p /etc/nixos
              if ! ${pkgs.git}/bin/git clone ${cfg.cloneFlakeRepo} /etc/nixos; then
                echo "ERROR: Failed to clone ${cfg.cloneFlakeRepo} into /etc/nixos" >&2
              fi
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
      })

      # The switch that first persists /etc/machine-id runs on a root whose
      # /etc/machine-id is already a regular file -- the one systemd made at
      # boot -- and impermanence refuses to replace a non-empty file ("A file
      # already exists"), failing its persist unit on every switch until the
      # next boot. When the persisted copy holds the SAME id, bind it over the
      # live file: nothing is removed, impermanence finds the mount and keeps
      # it, and the running system's id does not change. A different id is
      # left alone: swapping a machine's identity under a running systemd is
      # a reboot's business, not a switch's.
      {
        machineIdAdopt = {
          text = ''
            _live=/etc/machine-id
            _kept=${escapeShellArg "${persistPath}/etc/machine-id"}
            if [ -f "$_live" ] && [ ! -L "$_live" ] && [ -s "$_kept" ] \
              && ! ${pkgs.util-linux}/bin/findmnt "$_live" >/dev/null \
              && ${pkgs.diffutils}/bin/cmp -s "$_live" "$_kept"; then
              ${pkgs.util-linux}/bin/mount -o bind "$_kept" "$_live"
              # A switch before this one left the persist unit failed; with
              # the mount in place it has nothing left to do, so clear it.
              # Before systemd runs (at boot) this is a no-op.
              ${config.systemd.package}/bin/systemctl reset-failed \
                ${escapeShellArg "persist-${utils.escapeSystemdPath "${persistPath}/etc/machine-id"}.service"} 2>/dev/null || true
            fi
          '';
          deps = [ "specialfs" ];
        };
        # Before impermanence's own pass over its files at activation.
        persist-files.deps = [ "machineIdAdopt" ];
      }
    ];
  };
}
