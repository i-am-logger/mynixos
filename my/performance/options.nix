{ lib, ... }:

{
  performance = lib.mkOption {
    description = "Performance optimizations (kernel tunables, zram, vmtouch)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "performance optimizations";

        zramPercent = lib.mkOption {
          type = lib.types.int;
          default = 15;
          description = "Percentage of RAM to use for zram compressed swap";
        };

        vmtouchCache = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable vmtouch RAM caching for system closure";
        };
      };
    };
  };
}
