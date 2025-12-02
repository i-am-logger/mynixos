{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.system;

  # Get list of all user names from my.features.users
  userNames = attrNames config.my.users;
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base system configuration
    {
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
        # Audit system
        "audit_backlog_limit=2048"
        "audit=1"
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

      # Systemd fixes and improvements
      security.audit = {
        enable = true;
        rules = [
          "-a never,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime"
          "-a never,exit -F arch=b32 -S adjtimex -S settimeofday -S clock_settime"
        ];
      };

      services.udev.extraRules = ''
        # Better NVIDIA device handling
        KERNEL=="nvidia*", GROUP="video", MODE="0666"
        KERNEL=="nvidiactl", GROUP="video", MODE="0666"

        # Fix X11 socket permissions
        KERNEL=="card[0-9]*", SUBSYSTEM=="drm", GROUP="video", MODE="0666"
      '';

      systemd.services = {
        nvidia-persistenced = {
          serviceConfig = {
            Restart = lib.mkDefault "on-failure";
            RestartSec = lib.mkDefault "5s";
            ExecStartPre = "${pkgs.kmod}/bin/modprobe nvidia";
          };
        };

        fix-audio-speaker = {
          after = [ "sound.target" "pipewire.service" "wireplumber.service" ];
          wants = [ "pipewire.service" ];
        };
      };

      # Performance tunables moved to my.features.performance
      # Only set vm.max_map_count here for compatibility (high value needed for some apps)
      boot.kernel.sysctl = {
        "vm.max_map_count" = lib.mkForce 2147483642;
      };

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

      # Boot configuration
      boot.loader.grub.configurationLimit = 100;
      boot.tmp.cleanOnBoot = true;

      # SSD TRIM support
      services.fstrim.enable = true;

      # Opinionated system services (can be disabled with mkForce)
      services.usbmuxd.enable = lib.mkDefault true;  # iOS device support
      services.fwupd.enable = lib.mkDefault true;    # Firmware updates
      services.trezord.enable = lib.mkDefault true;  # Trezor hardware wallet

      # Graphics hardware support
      hardware.graphics.enable = true;

      # Network configuration (NetworkManager is a system service, not hardware)
      networking.networkmanager.enable = lib.mkDefault true;
      networking.wireless.enable = lib.mkDefault false;

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
        enable = true;
        channel = "https://nixos.org/channels/nixos-unstable";
      };

      # Nix configuration
      nix = {
        settings = {
          max-jobs = "auto";
          cores = 0; # auto detect
          build-cores = 0;
          sandbox = true;
          system-features = [
            "big-parallel"
          ];

          extra-platforms = [
            "x86_64-linux"
          ];

          # Add all users as trusted
          trusted-users = [ "root" ] ++ userNames;

          substituters = [
            "https://cache.nixos.org/"
          ];

          auto-optimise-store = true;
        };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
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

      # Environment variables
      environment.variables = {
        EDITOR = "hx";
        VIEWER = "hx";
        BROWSER = "brave";
        DEFAULT_BROWSER = "brave";
      };

      environment.pathsToLink = [ "libexec" ];
      environment.sessionVariables.DEFAULT_BROWSER = "brave";

      # XDG MIME defaults
      xdg.mime.defaultApplications = {
        "text/html" = "brave";
        "x-scheme-handler/http" = "brave";
        "x-scheme-handler/https" = "brave";
        "x-scheme-handler/about" = "brave";
        "x-scheme-handler/unknown" = "brave";
      };
    }

    # XDG portal configuration (for Wayland/Hyprland)
    (mkIf cfg.xdg.enable {
      xdg.portal = {
        enable = true;
        configPackages = [ pkgs.xdg-desktop-portal-gtk ];
        xdgOpenUsePortal = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
        config = {
          common = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Settings" = [
              "gtk"
            ];
          };
          hyprland = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Settings" = [
              "gtk"
            ];
          };
        };
      };

      environment.systemPackages = with pkgs; [
        qt6.qtwayland
      ];

      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1"; # For Electron apps
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
        XDG_SESSION_DESKTOP = "Hyprland";
        GDK_BACKEND = "wayland";
        QT_QPA_PLATFORM = "wayland;xcb";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        MOZ_ENABLE_WAYLAND = "1";
        WAYLAND_DISPLAY = "wayland-1";
      };

      services.dbus.enable = true;

      # Common system services (opinionated)
      services.hardware.bolt.enable = mkDefault true; # Thunderbolt support
      networking.networkmanager.enable = mkDefault true;
      networking.wireless.enable = mkDefault false; # Prefer NetworkManager

      # Dual-boot and filesystem support services
      services.udisks2.enable = mkDefault true; # Auto-mounting support
      services.timesyncd.enable = mkDefault true; # Network time sync
      services.fstrim.enable = mkDefault true; # SSD optimization

      # Locale and timezone (opinionated defaults - US English, Mountain Time)
      time.timeZone = mkDefault "America/Denver";
      i18n.defaultLocale = mkDefault "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = mkDefault "en_US.UTF-8";
        LC_IDENTIFICATION = mkDefault "en_US.UTF-8";
        LC_MEASUREMENT = mkDefault "en_US.UTF-8";
        LC_MONETARY = mkDefault "en_US.UTF-8";
        LC_NAME = mkDefault "en_US.UTF-8";
        LC_NUMERIC = mkDefault "en_US.UTF-8";
        LC_PAPER = mkDefault "en_US.UTF-8";
        LC_TELEPHONE = mkDefault "en_US.UTF-8";
        LC_TIME = mkDefault "en_US.UTF-8";
      };

      # Keyboard layout (opinionated US layout)
      services.xserver.xkb = {
        layout = mkDefault "us";
        variant = mkDefault "";
      };

      # Opinionated stateVersion - using 25.05 as baseline (can be overridden)
      system.stateVersion = mkDefault "25.05";
    })

    # Set home.stateVersion for all users (opinionated)
    {
      home-manager.users = mapAttrs (name: userCfg: {
        home.stateVersion = mkDefault "25.05";
      }) config.my.users;
    }
  ]);
}
