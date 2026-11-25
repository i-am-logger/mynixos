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

      # Install media pinned by checksum and kept WITH the VM, never in the Nix
      # store: a store path would put gigabytes into the system closure, so
      # every copy and GC would carry it. The file is ~owner/VMs/<name>/install.iso,
      # placed by `vm-<name> fetch` only if its SHA-256 matches.
      install.iso = lib.mkOption {
        default = null;
        description = ''
          Install media, pinned by SHA-256. `vm-<name> fetch [FILE|URL]` copies
          (reflinked on btrfs, so instant) or downloads it into
          ~owner/VMs/<name>/install.iso and refuses a mismatch; `vm-<name>`
          refuses to boot unverified media. Null once installed, or for a
          machine that boots its existing disk.
        '';
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            sha256 = lib.mkOption {
              type = lib.types.strMatching "[0-9a-f]{64}";
              example = "bd4307df32bc8af33b39ccecb1174aeb345386630f89a2b86c7a4e36b55ea650";
              description = "SHA-256 of the ISO, lowercase hex (what sha256sum prints).";
            };
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Where `vm-<name> fetch` downloads from when given no argument.
                Optional: Microsoft's Windows links expire within a day, so for
                Windows the hash is what is pinned and the file is supplied.
              '';
            };
          };
        });
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
