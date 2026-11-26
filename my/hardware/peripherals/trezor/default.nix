# Trezor hardware wallets (my.hardware.peripherals.trezor). nixpkgs' trezord
# module brings the bridge daemon and the device's udev rules.
{ config, lib, ... }:

{
  config = lib.mkIf config.my.hardware.peripherals.trezor.enable {
    services.trezord.enable = true;
  };
}
