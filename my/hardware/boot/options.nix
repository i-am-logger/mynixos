{ lib, ... }:

{
  boot = {
    uefi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable UEFI boot (default: true)";
    };
  };
}
