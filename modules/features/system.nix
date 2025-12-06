{ config
, lib
, pkgs
, ...
}:

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
          after = [
            "sound.target"
            "pipewire.service"
            "wireplumber.service"
          ];
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

      # Boot configuration (with mkDefault for user override)
      boot.loader.grub.configurationLimit = mkDefault 100;
      boot.tmp.cleanOnBoot = mkDefault true;

      # SSD TRIM support
      services.fstrim.enable = mkDefault true;

      # Opinionated system services (can be disabled with mkForce)
      services.usbmuxd.enable = lib.mkDefault true; # iOS device support
      services.fwupd.enable = lib.mkDefault true; # Firmware updates
      services.trezord.enable = lib.mkDefault true; # Trezor hardware wallet

      # Graphics hardware support
      hardware.graphics.enable = true;

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
