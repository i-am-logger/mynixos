{ lib, ... }:

{
  hardware = lib.mkOption {
    type = lib.types.submodule {
      options = {
        cpu = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "amd" "intel" ]);
          default = null;
          description = "CPU vendor";
        };

        gpu = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ "amd" "nvidia" "intel" ]);
          default = null;
          description = "GPU vendor";
        };

        bluetooth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable bluetooth";
          };
        };

        audio = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable audio";
          };
        };

        motherboards = {
          gigabyte = {
            x870e-aorus-elite-wifi7 = {
              enable = lib.mkEnableOption "Gigabyte X870E AORUS Elite WiFi7 motherboard";

              bluetooth = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
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

        laptops = {
          lenovo = {
            legion-16irx8h = {
              enable = lib.mkEnableOption "Lenovo Legion 16IRX8H laptop";

              bluetooth = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
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

        cooling = {
          nzxt = {
            kraken-elite-rgb = {
              elite-240-rgb = {
                enable = lib.mkEnableOption "NZXT Kraken Elite 240 RGB AIO cooler";

                lcd = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable LCD screen support";
                  };

                  brightness = lib.mkOption {
                    type = lib.types.int;
                    default = 100;
                    description = "LCD screen brightness (0-100)";
                  };
                };

                rgb = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Enable RGB ring around LCD screen";
                  };
                };

                liquidctl = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Install liquidctl CLI tool";
                  };

                  autoInitialize = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Automatically run liquidctl initialize on boot";
                  };
                };

                monitoring = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Install lm_sensors for monitoring";
                  };
                };
              };
            };
          };
        };

        peripherals = {
          elgato = {
            streamdeck = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Enable Elgato Stream Deck support (all models).

                  Provides udev rules, streamdeck-ui package, and Qt/Wayland integration
                  for Stream Deck programmable macro pads (Original, Mini, XL, V2, MK.2, Plus).

                  Vendor: Elgato Systems (0fd9)
                  Device type: USB HID programmable control surface
                '';
              };
            };
          };
        };
      };
    };
    default = { };
    description = "Hardware configuration";
  };
}
