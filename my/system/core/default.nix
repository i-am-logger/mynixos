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
  config = mkMerge [
    # Windows dual-boot (independent of system.enable — hardware concern)
    (mkIf cfg.dualBoot.windows {
      time.hardwareClockInLocalTime = true;
      boot.supportedFilesystems = [ "ntfs" ];
    })

    (mkIf cfg.enable (mkMerge [
      # Base system configuration
      {
        # Distribution identity and branding
        system = {
          nixos = {
            distroId = "mynixos";
            distroName = "mynixos";
            vendorId = "mynixos";
            vendorName = "mynixos";

            # Additional os-release fields for mynixos branding
            # Override VERSION and PRETTY_NAME to use mynixos version from release-please
            extraOSReleaseArgs = {
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
              # Keep ID_LIKE as nixos so that applications (like Hyprland's start-hyprland)
              # can detect NixOS-based systems for compatibility checks
              ID_LIKE = "nixos";
              # IMPORTANT: NAME must be "NixOS" for Hyprland's start-hyprland to detect
              # that we're on a NixOS-based system (it checks NAME == "NixOS" exactly)
              # See: https://github.com/hyprwm/Hyprland/blob/main/start/src/helpers/Nix.cpp
              NAME = "NixOS";
            };
          };

          # Override system derivation name to use mynixos branding
          systemBuilderArgs = {
            name = "mynixos-system-${config.system.name}-${mynixosVersion}";
          };

          # Auto-upgrade configuration
          autoUpgrade = {
            enable = mkDefault true;
            channel = mkDefault "https://nixos.org/channels/nixos-unstable";
          };
        };

        # Plymouth boot splash (opinionated)
        boot = {
          plymouth = {
            enable = true;
            extraConfig = ''
              [Daemon]
              ShowDelay=0
              DeviceTimeout=8
            '';
          };

          initrd.enable = true;
          kernelParams = [
            # Plymouth boot splash
            "splash"
            "quiet"
            "vt.global_cursor_default=0"
            "loglevel=3"
            "rd.systemd.show_status=false"
            "rd.udev.log_level=3"
            "acpi_osi=Linux"
          ];

          # Boot loader configuration (opinionated)
          loader = {
            timeout = lib.mkDefault 2;
            efi = {
              canTouchEfiVariables = lib.mkDefault true;
              efiSysMountPoint = lib.mkDefault "/boot";
            };
            systemd-boot.consoleMode = lib.mkDefault "max";
            grub.configurationLimit = mkDefault 100;
          };

          tmp.cleanOnBoot = mkDefault true;
        };

        systemd = {
          services.plymouth-quit-wait.enable = lib.mkDefault true;
          services.plymouth-quit.enable = lib.mkDefault true;

          oomd = {
            enable = true;
            enableRootSlice = true;
            enableUserSlices = true;
          };
        };

        # PAM fixes for SSH/GPG agent
        environment = {
          sessionVariables = {
            SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$(gpgconf --list-dirs agent-ssh-socket)}";
          };

          # Prevent NetworkManager from managing container interfaces
          etc."NetworkManager/conf.d/99-unmanaged-cni.conf".text = ''
            [keyfile]
            unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*;interface-name:docker*;interface-name:br-*
          '';

          # System packages
          systemPackages = with pkgs; [
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
        };

        programs.gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
        };

        # DRM device permissions (generic, not NVIDIA-specific)
        services = {
          udev.extraRules = ''
            # Fix X11 socket permissions for all GPUs
            KERNEL=="card[0-9]*", SUBSYSTEM=="drm", GROUP="video", MODE="0666"
          '';

          # Opinionated system services (can be disabled with mkForce)
          usbmuxd.enable = lib.mkDefault true; # iOS device support
          fwupd.enable = lib.mkDefault true; # Firmware updates
          trezord.enable = lib.mkDefault true; # Trezor hardware wallet
          timesyncd.enable = lib.mkDefault true; # Network time synchronization

          # Power management - prevent unwanted sleep/suspend (opinionated for workstations)
          # Desktop workstations shouldn't auto-suspend
          logind.settings.Login = {
            HandleLidSwitch = mkDefault "ignore";
            HandleLidSwitchDocked = mkDefault "ignore";
            HandleLidSwitchExternalPower = mkDefault "ignore";
            HandlePowerKey = mkDefault "ignore";
            HandlePowerKeyLongPress = mkDefault "poweroff";
            HandleSuspendKey = mkDefault "ignore";
            HandleHibernateKey = mkDefault "ignore";
            IdleAction = mkDefault "ignore";
            IdleActionSec = mkDefault 0;
          };
        };

        # Performance tunables moved to my.features.performance

        # Timezone and locale (configured below with mkDefault for easy override)

        # Console configuration
        console = {
          enable = true;
          earlySetup = true;
          useXkbConfig = true;
        };

        # Graphics hardware support
        hardware.graphics.enable = true;

        # Network configuration (NetworkManager is a system service, not hardware)
        networking.networkmanager.enable = lib.mkDefault true;

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

    ]))
  ];
}
