# my.virtualisation.libvirt -- full VMs through libvirtd and virt-manager.
#
# The system libvirt (qemu:///system), not a per-user session: it owns USB
# host-device passthrough, relabelling the usbfs node for the guest itself,
# and its NAT network needs no setup. OVMF (UEFI, Secure Boot) ships with
# QEMU and nixpkgs links it in; swtpm is the TPM 2.0 Windows 11 refuses to
# install without.
{ config, lib, ... }:

let
  cfg = config.my.virtualisation.libvirt;
  impermanence = config.my.storage.impermanence;
in
{
  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    programs.virt-manager.enable = true;

    users.users = lib.genAttrs cfg.users (_: { extraGroups = [ "libvirtd" ]; });

    # Disk images, VM definitions, NVRAM and TPM state. On a tmpfs root these
    # would vanish at reboot -- or fill RAM first.
    environment.persistence = lib.mkIf impermanence.enable {
      ${impermanence.persistPath}.directories = [ "/var/lib/libvirt" ];
    };
  };
}
