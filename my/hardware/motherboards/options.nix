# Motherboard profiles.
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
        motherboards = {
          gigabyte = {
            x870e-aorus-elite-wifi7 = {
              enable = lib.mkEnableOption "Gigabyte X870E AORUS Elite WiFi7 motherboard";

              bluetooth = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable bluetooth hardware";
                };
              };

              networking = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Enable network hardware";
                };

                useDHCP = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Use DHCP for network configuration";
                };

                wireless = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable wireless networking (use NetworkManager instead)";
                  };

                  useDHCP = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Use DHCP for wireless interface";
                  };
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

                sata = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable SATA/AHCI storage support";
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

              memory = {
                optimization = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable memory optimizations";
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
