{ lib, ... }:

{
  nixGc = lib.mkOption {
    description = ''
      Periodic Nix garbage collection via launchd.

      Exists because nix-darwin asserts `nix.gc.automatic requires nix.enable`,
      so its own GC is unavailable on hosts where Nix stays owned by the
      installer. Plain launchd daemons have no such gating.
    '';
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "periodic Nix garbage collection via launchd";

        olderThan = lib.mkOption {
          type = lib.types.str;
          default = "30d";
          description = "Age threshold for `nix-collect-garbage --delete-older-than`";
        };

        optimise = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Also run `nix store optimise`, hard-linking identical store files.
            Slow the first time on a large store, cheap afterwards.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.attrs;
          default = { Weekday = 7; Hour = 3; Minute = 0; };
          description = "launchd StartCalendarInterval for the collection run";
        };

        optimiseInterval = lib.mkOption {
          type = lib.types.attrs;
          default = { Weekday = 7; Hour = 4; Minute = 0; };
          description = "launchd StartCalendarInterval for the optimise run";
        };
      };
    };
  };
}
