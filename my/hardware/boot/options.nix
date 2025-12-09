{ lib, ... }:

{
  boot = {
    uefi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable UEFI boot";
    };

    secure = lib.mkEnableOption "Secure Boot with Lanzaboote";

    dualBoot = {
      enable = lib.mkEnableOption "dual-boot support (Windows/Linux)";
    };
  };
}
