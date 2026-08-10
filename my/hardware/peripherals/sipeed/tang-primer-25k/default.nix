{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.peripherals.sipeed.tangPrimer25k;

  udevRules = pkgs.writeTextFile {
    name = "sipeed-tang-primer-25k-udev-rules";
    destination = "/lib/udev/rules.d/60-sipeed-tang-primer-25k.rules";
    text = ''
      # Sipeed Tang Primer 25K's onboard USB-JTAG/UART dock -- a generic
      # FTDI FT2232C/D/H (0403:6010), not Sipeed-specific silicon, so this
      # also covers other FT2232-based FPGA programmers/debug probes.
      # nixpkgs' openFPGALoader package ships no udev rules of its own.
      # Upstream's 99-openfpgaloader.rules also sets MODE/GROUP="plugdev";
      # dropped here because uaccess already grants the seat-local user access,
      # and plugdev exists only when my/hardware/security-keys/yubico happens to
      # be enabled -- a coupling this module should not inherit.
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", TAG+="uaccess"
    '';
  };
in
{
  config = {
    # Master switch propagates to device udev via mkDefault
    my.hardware.peripherals.sipeed.tangPrimer25k.udev = mkDefault config.my.system.udev.enable;

    # Only when device is enabled
    services.udev.packages = mkIf (cfg.enable && cfg.udev) [ udevRules ];
  };
}
