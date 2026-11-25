# my.virtualisation.vms — full VMs on KVM: the engines, and machines declared
# as data. Linux only. Type-only; ../options.nix owns `virtualisation`.
{ lib, ... }:

let
  usbDevice = import ../../../lib/types/usb-device.nix { inherit lib; };

  machine = lib.types.submodule ({ name, ... }: {
    options = {
      # The enum lists IMPLEMENTED engines only, as rke2's `cni`: a libvirt
      # value joins when libvirt machines are rendered (domain XML, define-only).
      engine = lib.mkOption {
        type = lib.types.enum [ "quickemu" ];
        default = "quickemu";
        description = "What runs this machine. quickemu: a per-user process, no daemon.";
      };

      owner = lib.mkOption {
        type = lib.types.str;
        example = "alice";
        description = ''
          The account the VM runs as. Its files live in ~owner/VMs/${name}/
          (persisted), its config is ~owner/VMs/${name}.conf, and the command
          `vm-${name}` starts it.
        '';
      };

      os = lib.mkOption {
        type = lib.types.enum [ "windows" "linux" ];
        description = ''
          The guest OS. Picks quickemu's device set; "windows" also attaches
          the VirtIO drivers and an unattended-setup disc (no TPM/Secure Boot
          check, no Microsoft account), and tells kvm to ignore the MSRs
          Windows probes.
        '';
      };

      install.iso = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/alice/Downloads/Win11_24H2_English_x64.iso";
        description = ''
          Install media, as a path on this machine. A string on purpose: an
          ISO is gigabytes and must never be copied into the Nix store. Null
          once installed, or for a machine that boots its existing disk.
        '';
      };

      cpus = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Virtual CPU cores.";
      };

      memory = lib.mkOption {
        type = lib.types.strMatching "[0-9]+[MG]";
        default = "8G";
        description = "Guest memory, e.g. \"8G\".";
      };

      disk.size = lib.mkOption {
        type = lib.types.strMatching "[0-9]+[MGT]";
        default = "64G";
        description = "Size of the system disk (qcow2, allocated as used).";
      };

      firmware = {
        uefi = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "UEFI (OVMF) rather than legacy BIOS.";
        };
        secureBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Secure Boot firmware with Microsoft keys enrolled. Requires uefi.
            Off by default: the unattended Windows setup bypasses the check.
          '';
        };
        tpm = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "An emulated TPM 2.0 (swtpm), as Windows 11 expects.";
        };
      };

      network = lib.mkOption {
        type = lib.types.enum [ "nat" "restrict" "none" ];
        default = "nat";
        description = ''
          nat: user-mode networking out through the host. restrict: no access
          to the host or the outside. none: no network device.
        '';
      };

      display = lib.mkOption {
        type = lib.types.enum [ "sdl" "spice" "none" ];
        default = "sdl";
        description = "How the VM's screen is shown. spice needs a viewer; none runs headless.";
      };

      usb = lib.mkOption {
        type = lib.types.listOf usbDevice;
        default = [ ];
        example = [ "413c:a503" ];
        description = ''
          Host USB devices passed through to the VM, by vendor:product. Each
          gets a udev rule giving the owner its device node, which quickemu
          needs to hand it over. A device that re-enumerates under another id
          (e.g. a firmware updater's bootloader mode) needs that id listed too.
        '';
      };
    };
  });

  engineUsers = what: lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "alice" ];
    description = what;
  };
in
{
  virtualisation = lib.mkOption {
    type = lib.types.submodule {
      options.vms = lib.mkOption {
        description = "Full VMs on KVM: engines, and machines declared as data";
        default = { };
        type = lib.types.submodule {
          options = {
            libvirt = {
              enable = lib.mkEnableOption "libvirtd with QEMU/KVM, an emulated TPM (Windows 11) and virt-manager";
              users = engineUsers ''
                Accounts added to the `libvirtd` group, which manages the system
                libvirt (qemu:///system) without a password. That is
                ROOT-EQUIVALENT -- a member can define a VM with any host disk
                attached -- so the list is explicit, never every user.
              '';
            };

            quickemu = {
              enable = lib.mkEnableOption "quickemu, VMs as per-user processes (no daemon, no privileged group)";
              users = engineUsers ''
                Accounts that get quickemu and quickget. Every machine's owner
                gets them anyway; this is for ad-hoc VMs outside `machines`.
              '';
            };

            machines = lib.mkOption {
              type = lib.types.attrsOf machine;
              default = { };
              description = "VMs declared as data, each run by its owner.";
            };
          };
        };
      };
    };
  };
}
