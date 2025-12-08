{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.boot.dualBoot;
in
{
  # Options are defined in flake.nix under my.boot namespace
  # This module only provides the implementation

  config = mkIf cfg.enable {
    # Keep hardware clock in local time (Windows expects this)
    time.hardwareClockInLocalTime = true;

    # Support NTFS filesystem (for Windows partitions)
    boot.supportedFilesystems = [ "ntfs" ];
  };
}
