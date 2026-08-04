# Lenovo laptop profiles.
#
# Declared beside the implementation rather than in the central
# my/hardware/options.nix, so the option exists only where something reads it.
# platforms/linux.nix imports this; the other platform does not, so setting it
# there is the module system's own "does not exist" error rather than silence.
#
# Type-only: my/hardware/options.nix carries `default` and `description` for the
# `hardware` submodule. Two declarations may merge, but only one may carry those,
# or it is a conflicting declaration rather than a merge.

{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        laptops = {
          lenovo = {
            legion-16irx8h = {
              enable = lib.mkEnableOption "Lenovo Legion 16IRX8H laptop";

              bluetooth = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable bluetooth hardware";
                };
              };

              storage = {
                nvme = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable NVMe storage support";
                  };
                };

                usb = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable USB storage support";
                  };
                };
              };

              usb = {
                xhci = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable xHCI (USB 3.0) support";
                  };
                };

                thunderbolt = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable Thunderbolt support";
                  };
                };

                hid = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable USB HID support";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
