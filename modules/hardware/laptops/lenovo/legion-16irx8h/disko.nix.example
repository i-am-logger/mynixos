{ ... }:
# Disko configuration for skyspy-dev system that matches existing partitions
{
  disk = {
    main = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          # EFI boot partition (nvme0n1p1) - existing UUID
          ESP = {
            start = "1M";
            size = "1.1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
              extraArgs = [ "-F32" "-n" "" ];
            };
          };

          # Unknown/reserved partition (nvme0n1p2) - preserve as-is
          reserved = {
            size = "16M";
            type = "8300";
          };

          # Windows partition (nvme0n1p3) - preserve existing
          windows = {
            size = "1.9T";
            type = "0700";
            content = {
              type = "filesystem";
              format = "ntfs";
              mountpoint = "/home/logger/mnt/windows";
              mountOptions = [ "ro" "uid=1000" "gid=100" "dmask=022" "fmask=133" ];
            };
          };

          # Windows recovery partition (nvme0n1p4) - preserve
          winre = {
            size = "642M";
            type = "2700";
          };

          # Main NixOS root and data partition (nvme0n1p5) - existing UUID  
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "defaults" ];
            };
          };
        };
      };
    };
  };
}
