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

            # Gigabyte TRX50 AERO D (sTR5 / AMD TRX50). Same sub-option set as the
            # board above, with two deliberate differences in the DEFAULTS, both
            # facts about this board rather than preferences:
            #   - sata defaults TRUE: the board has an active AMD 600-series SATA
            #     controller, where on the X870E it is left off.
            #   - networking.wireless defaults FALSE as elsewhere, because the
            #     Qualcomm WCN785x is driven through NetworkManager, not
            #     networking.wireless (wpa_supplicant).
            trx50-aero-d = {
              enable = lib.mkEnableOption "Gigabyte TRX50 AERO D motherboard";

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
                    default = true;
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
