{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.memory.optimization;
in
{
  options.my.hardware.memory.optimization = {
    enable = mkEnableOption "memory management optimizations";

    swappiness = mkOption {
      type = types.int;
      default = 10;
      description = ''
        Swappiness value (0-100). Lower values reduce swapping to keep data in RAM.
        Default: 10 (minimal swapping, good for systems with adequate RAM)
      '';
    };

    dirtyRatio = mkOption {
      type = types.int;
      default = 5;
      description = ''
        Percentage of system memory that can be filled with dirty pages before processes are forced to write.
        Default: 5 (free memory faster)
      '';
    };

    dirtyBackgroundRatio = mkOption {
      type = types.int;
      default = 2;
      description = ''
        Percentage of system memory that can be filled with dirty pages before background writeback starts.
        Default: 2 (proactive background writeback)
      '';
    };

    hugepages = mkOption {
      type = types.enum [ "always" "madvise" "never" ];
      default = "madvise";
      description = ''
        Transparent hugepage mode:
        - always: Always use huge pages (may increase memory usage)
        - madvise: Use huge pages only when explicitly requested (recommended)
        - never: Never use huge pages
        Default: madvise (balanced approach)
      '';
    };
  };

  config = mkIf cfg.enable {
    # Memory management kernel parameters
    boot.kernelParams = [
      "vm.swappiness=${toString cfg.swappiness}"
      "vm.dirty_ratio=${toString cfg.dirtyRatio}"
      "vm.dirty_background_ratio=${toString cfg.dirtyBackgroundRatio}"
      "transparent_hugepage=${cfg.hugepages}"
    ];
  };
}
