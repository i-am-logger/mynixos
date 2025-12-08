{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.system;

  # Get list of all user names from my.features.users
  userNames = attrNames config.my.users;
  
  # Read mynixos version from version.txt
  mynixosVersion = lib.strings.removeSuffix "\n" (builtins.readFile ../../../version.txt);
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base system configuration
    {
      # Distribution identity
      system.nixos.distroId = "mynixos";
      system.nixos.distroName = "mynixos";
      system.nixos.vendorId = "mynixos";
      system.nixos.vendorName = "mynixos";
      
      # Override system derivation name to use mynixos branding
      system.systemBuilderArgs = {
        name = "mynixos-system-${config.system.name}-${mynixosVersion}";
      };
      
      # Additional os-release fields for mynixos branding
      # Override VERSION and PRETTY_NAME to use mynixos version from release-please
      system.nixos.extraOSReleaseArgs = {
        HOME_URL = "https://github.com/i-am-logger/mynixos";
        VENDOR_URL = "https://github.com/i-am-logger/mynixos";
        DOCUMENTATION_URL = "https://github.com/i-am-logger/mynixos#readme";
        SUPPORT_URL = "https://github.com/i-am-logger/mynixos/discussions";
        BUG_REPORT_URL = "https://github.com/i-am-logger/mynixos/issues";
        ANSI_COLOR = "0;38;2;126;186;228";
        # Override version fields with mynixos version from release-please
        VERSION = "${mynixosVersion} (Bootstrapper)";
        VERSION_ID = mynixosVersion;
        VERSION_CODENAME = "bootstrapper";
        PRETTY_NAME = "mynixos ${mynixosVersion} (Bootstrapper)";
        # Override ID_LIKE to mynixos (not nixos) - mynixos is its own distribution
        ID_LIKE = "mynixos";
      };

      # Plymouth boot splash (opinionated)
      boot.plymouth = {
        enable = true;
        extraConfig = ''
          [Daemon]
          ShowDelay=0
          DeviceTimeout=8
        '';
      };

      boot.initrd.enable = true;
      boot.kernelParams = [
        # Plymouth boot splash
        "splash"
        "quiet"
        "vt.global_cursor_default=0"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "acpi_osi=Linux"
      ];

      systemd.services.plymouth-quit-wait.enable = lib.mkDefault true;
      systemd.services.plymouth-quit.enable = lib.mkDefault true;

      # Boot loader configuration (opinionated)
      boot.loader = {
        timeout = lib.mkDefault 2;
        efi = {
          canTouchEfiVariables = lib.mkDefault true;
          efiSysMountPoint = lib.mkDefault "/boot";
        };
        systemd-boot.consoleMode = lib.mkDefault "max";
      };

      # PAM fixes for SSH/GPG agent
      environment.sessionVariables = {
        SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$(gpgconf --list-dirs agent-ssh-socket)}";
      };

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      # DRM device permissions (generic, not NVIDIA-specific)
      services.udev.extraRules = ''
        # Fix X11 socket permissions for all GPUs
        KERNEL=="card[0-9]*", SUBSYSTEM=="drm", GROUP="video", MODE="0666"
      '';

      # Performance tunables moved to my.features.performance

      systemd.oomd = {
        enable = true;
        enableRootSlice = true;
        enableUserSlices = true;
      };

      # Timezone and locale (configured below with mkDefault for easy override)

      # Console configuration
      console = {
        enable = true;
        earlySetup = true;
        useXkbConfig = true;
      };

      # Boot configuration (with mkDefault for user override)
      boot.loader.grub.configurationLimit = mkDefault 100;
      boot.tmp.cleanOnBoot = mkDefault true;

      # Opinionated system services (can be disabled with mkForce)
      services.usbmuxd.enable = lib.mkDefault true; # iOS device support
      services.fwupd.enable = lib.mkDefault true; # Firmware updates
      services.trezord.enable = lib.mkDefault true; # Trezor hardware wallet
      services.timesyncd.enable = lib.mkDefault true; # Network time synchronization

      # Graphics hardware support
      hardware.graphics.enable = true;

      # Power management - prevent unwanted sleep/suspend (opinionated for workstations)
      # Desktop workstations shouldn't auto-suspend
      services.logind = {
        lidSwitch = mkDefault "ignore";
        lidSwitchDocked = mkDefault "ignore";
        lidSwitchExternalPower = mkDefault "ignore";
        powerKey = mkDefault "ignore";
        powerKeyLongPress = mkDefault "poweroff";
        suspendKey = mkDefault "ignore";
        hibernateKey = mkDefault "ignore";
        # Use settings.Login instead of deprecated extraConfig
        settings.Login = {
          IdleAction = mkDefault "ignore";
          IdleActionSec = mkDefault 0;
        };
      };

      # Network configuration (NetworkManager is a system service, not hardware)
      networking.networkmanager.enable = lib.mkDefault true;

      # Prevent NetworkManager from managing container interfaces
      environment.etc."NetworkManager/conf.d/99-unmanaged-cni.conf".text = ''
        [keyfile]
        unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*;interface-name:docker*;interface-name:br-*
      '';

      # System packages
      environment.systemPackages = with pkgs; [
        # Managing secrets
        sops
        pass

        # CLI tools
        mc
        yazi
        helix
        fastfetch
        tree
        btop

        # Hardware utilities
        usbutils
        pciutils
        screen

        # Network tools
        tcpdump
        wget
        curl

        # Boot splash
        plymouth
      ];

      # Auto-upgrade configuration
      system.autoUpgrade = {
        enable = mkDefault true;
        channel = mkDefault "https://nixos.org/channels/nixos-unstable";
      };

      # Nix configuration
      nix = {
        settings = {
          max-jobs = mkDefault "auto";
          cores = mkDefault 0; # auto detect
          build-cores = mkDefault 0;
          sandbox = mkDefault true;
          system-features = mkDefault [
            "big-parallel"
          ];

          extra-platforms = mkDefault [
            "x86_64-linux"
          ];

          # Add all users as trusted
          trusted-users = [ "root" ] ++ userNames;

          substituters = mkDefault [
            "https://cache.nixos.org/"
          ];

          auto-optimise-store = mkDefault true;
        };

        gc = {
          automatic = mkDefault true;
          dates = mkDefault "weekly";
          options = mkDefault "--delete-older-than 7d";
        };

        package = pkgs.nixVersions.latest;

        extraOptions = ''
          experimental-features = nix-command flakes auto-allocate-uids
          keep-outputs          = false
          keep-derivations      = false
          extra-substituters = https://devenv.cachix.org
          extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
        '';
      };
    }
  ]);
}
