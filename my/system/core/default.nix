{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.system;

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
      # No development or install-time tooling on a running system: NixOS'
      # defaults bring perl and strace (rsync stays, it is a usage tool), and
      # the installer's tools (nixos-install, -enter, -generate-config,
      # -build-vms) belong to the installer ISO. nixos-rebuild, nixos-option
      # and nixos-version stay.
      {
        environment.defaultPackages = mkDefault [ pkgs.rsync ];
        system.tools = genAttrs [ "nixos-install" "nixos-enter" "nixos-generate-config" "nixos-build-vms" ]
          (_: { enable = mkDefault false; });
      }

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
          # The ramoops reservation and module are my.forensics' (my/forensics).
          kernelParams = [
            # Plymouth boot splash
            "splash"
            "quiet"
            "vt.global_cursor_default=0"
            # Console verbosity is a boot/display concern, kept quiet here and
            # decoupled from my.forensics.level - the forensic retention lever is
            # journald MaxLevelStore (set from the level in my/forensics).
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

        environment = {
          # Prevent NetworkManager from managing container interfaces.
          #
          # podman* is netavark's default bridge (podman0, plus podman1..n for
          # additional networks). Left managed, NetworkManager autoconnects and
          # runs DHCP on it and can take it down under a running container,
          # which breaks both container connectivity and the aardvark-dns
          # resolution the podman engine (my.virtualisation.containers) turns on.
          #
          # The list is static rather than derived from which engines are on
          # (my.virtualisation): my/system/core has no business reading it, and
          # the entries already there (cni*, flannel*, docker*, incusbr*,
          # virbr*) are not conditional on an engine either.
          #
          # THIS FILE IS THE SINGLE OWNER of `unmanaged-devices`, and the cilium_*
          # and lxc* entries are here rather than in my/infra/rke2 for that
          # reason. NetworkManager reads conf.d in lexical order and a later file
          # wins for one key, so a second writer does not merge -- it replaces,
          # silently, taking the podman*/br-* exclusions that protect the live
          # Radicle forge with it. my/infra/rke2 forces nixpkgs' own
          # rke2-canal.conf off instead of writing a competing file
          # (docs/k8s-fleet-constraints.md, C64/C74).
          # NetworkManager reads conf.d only at start or on SIGHUP, and nixpkgs'
          # own restartTriggers cover NetworkManager.conf -- NOT the drop-ins
          # (nixos/modules/services/networking/networkmanager.nix). So without the
          # reloadTrigger below, the switch that first brings a CNI up leaves NM
          # running the PREVIOUS list: it would manage cilium_host, cilium_net,
          # cilium_vxlan and the lxc* veths it has just been told to ignore. The
          # forge's podman*/br-* exclusions are already live from the current
          # generation, so what this protects is the new cluster, not the forge.
          etc."NetworkManager/conf.d/99-unmanaged-cni.conf".text = ''
            [keyfile]
            unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*;interface-name:docker*;interface-name:podman*;interface-name:br-*;interface-name:cilium_host;interface-name:cilium_net;interface-name:cilium_vxlan;interface-name:lxc*;interface-name:incusbr*;interface-name:virbr*
          '';

          # Linux-only half of the base set. The portable half lives in
          # my/system/base-packages, which platforms/common.nix imports so the
          # Mac gets it too.
          systemPackages = with pkgs; [
            # Hardware inspection: lsusb/lspci have no meaning on macOS, which
            # exposes the same information through system_profiler and ioreg.
            usbutils
            pciutils

            # Packet capture needs a Linux capability model to be useful here.
            tcpdump

            # Boot splash
            plymouth
          ];
        };

        # Device services (trezord, usbmuxd) are my.hardware.peripherals'.
        services = {
          # Opinionated system services (can be disabled with mkForce)
          fwupd.enable = lib.mkDefault true; # Firmware updates
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

        # Network configuration (NetworkManager is a system service, not hardware)
        networking.networkmanager.enable = lib.mkDefault true;

        # Make NM actually pick up the unmanaged-devices drop-in declared above.
        # nixpkgs triggers a restart on NetworkManager.conf only, never on the
        # conf.d drop-ins, so a change here would otherwise sit unread until the
        # next reboot -- and the switch that first brings a CNI up would leave NM
        # managing the very interfaces it has just been told to ignore. Reload is
        # SIGHUP: it re-reads conf.d without dropping connections, which matters
        # on a machine whose network is in use while the switch runs.
        systemd.services.NetworkManager.reloadTriggers =
          lib.mkIf config.networking.networkmanager.enable
            [ config.environment.etc."NetworkManager/conf.d/99-unmanaged-cni.conf".source ];

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

            # Trust is root-equivalent (substituters, unsigned imports), so it
            # follows the admin role rather than every account.
            trusted-users = [ "root" "@wheel" ];

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
          '';
        };
      }

    ]))
  ];
}
