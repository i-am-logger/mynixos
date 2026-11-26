# Peripheral device profiles.
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
        peripherals = {
          apple = {
            dfu = {
              enable = lib.mkEnableOption ''
                Apple iOS/iPadOS devices in DFU, Recovery, or WTF mode.

                Provides udev rules (uaccess) so a device enumerating in
                DFU/Recovery/WTF mode, or checkra1n/pongoOS DFU mode, is
                usable by a non-root user -- e.g. libirecovery/irecovery,
                idevicerestore, or dfu-probe.

                Vendor: Apple (05ac)
                Product IDs: WTF/DFU/Recovery 1222, 1227, 1280-1283
                Product ID: checkra1n/pongoOS DFU 1338
              '';

              udev = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Install this device's udev rules.";
              };
            };

            ios = {
              enable = lib.mkEnableOption ''
                iPhone/iPad over USB in normal mode: usbmuxd, the daemon every
                libimobiledevice tool (idevicebackup2, ideviceinfo, and mvt's
                iOS backups through them) reaches the device through.

                Vendor: Apple (05ac)
              '';
            };
          };

          keychron = {
            k2-he = {
              enable = lib.mkEnableOption ''
                Keychron K2 HE Hall Effect keyboard.

                Provides udev rules for hidraw access (OpenRGB) and DFU flashing (STM32).

                Vendor: Keychron (3434)
                Product: K2 HE (0e20)
                Bootloader: STM32 DFU (0483:df11)
              '';

              udev = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Install this device's udev rules.";
              };
            };
          };

          logitech = {
            bolt = {
              enable = lib.mkEnableOption ''
                Logi Bolt wireless receiver and the devices paired to it.

                udev rules and ltunify (nixpkgs hardware.logitech.wireless), and
                Solaar (programs.solaar) for pairing, battery levels and button
                settings, which the kernel's plain HID input does not cover.

                Vendor: Logitech (046d)
                Product: Logi Bolt Receiver (c548)
              '';

              tray = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Start Solaar hidden in the tray with each graphical session (its per-user service), so battery levels and button settings are live.";
              };
            };
          };

          sipeed = {
            tangPrimer25k = {
              enable = lib.mkEnableOption ''
                Sipeed Tang Primer 25K FPGA board's onboard USB-JTAG/UART dock.

                Provides udev rules (uaccess) so openFPGALoader and other
                tools can talk to the dock's FTDI FT2232 interface without
                root -- nixpkgs' openFPGALoader package ships no udev rules
                of its own. Also covers other FT2232-based FPGA programmers
                since the chip/USB ID isn't Sipeed-specific.

                Vendor: FTDI (0403)
                Product: FT2232C/D/H (6010)
              '';

              udev = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Install this device's udev rules.";
              };

              users = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "alice" ];
                description = ''
                  Accounts added to `dialout`, for the board's UART
                  (/dev/ttyUSB*). The group opens every serial port on the
                  host, so the list is explicit, never every user. JTAG needs
                  no group: uaccess covers it.
                '';
              };
            };
          };

          trezor = {
            enable = lib.mkEnableOption ''
              Trezor hardware wallets: trezord, the bridge Trezor Suite and
              browser wallets talk to, with its udev rules.

              Vendor: SatoshiLabs (1209:53c1, 534c:0001)
            '';
          };
        };
      };
    };
  };
}
