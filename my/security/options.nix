{ lib, ... }:

{
  security = lib.mkOption {
    description = "Security stack configuration";
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "security stack";

        secureBoot = {
          enable = lib.mkEnableOption "secure boot with lanzaboote";
        };

        yubikey = {
          enable = lib.mkEnableOption "yubikey support";
        };

        auditRules = {
          enable = lib.mkEnableOption "audit rules";
        };
      };
    };
  };
}
