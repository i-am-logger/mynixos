{ lib, ... }:

{
  performance = lib.mkOption {
    description = "Performance optimizations (kernel tunables, zram, vmtouch)";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "performance optimizations";

        zramPercent = lib.mkOption {
          type = lib.types.ints.between 0 100;
          default = 15;
          description = "Percentage of RAM to use for zram compressed swap";
        };

        vmtouchCache = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable vmtouch RAM caching for system closure";
        };

        runs.budget = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[0-9]+[KMGT]?");
          default = null;
          example = "128G";
          description = ''
            MemoryMax of every user's runs.slice, with no swap: the memory all
            of releasable's runs share (its nixosModules.runs contract, option
            releasable.runs.budget), and the slice baud's scripts/bounded
            scopes go in. Its own switch, independent of `enable`. null
            declares no runs.slice, and releasable then refuses every run.
            Sized per host from its RAM, so mynixos sets no default.
          '';
        };
      };
    };
  };
}
