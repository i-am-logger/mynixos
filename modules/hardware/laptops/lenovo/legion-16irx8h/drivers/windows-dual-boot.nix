{ config, lib, pkgs, ... }:

{
  # Windows dual-boot hardware configuration
  # Hardware-level settings needed for dual-boot with Windows

  # Keep hardware clock in local time (Windows expects this)
  time.hardwareClockInLocalTime = true;

  # Support NTFS filesystem (for Windows partition)
  boot.supportedFilesystems = [ "ntfs" ];

  # Note: To mount Windows partition, add to your system config:
  # fileSystems."/home/<username>/mnt/windows" = {
  #   device = "/dev/disk/by-uuid/<YOUR-UUID>";
  #   fsType = "ntfs";
  #   options = [ "ro" "uid=1000" "gid=100" "dmask=022" "fmask=133" ];
  #   noCheck = true;
  # };
}
