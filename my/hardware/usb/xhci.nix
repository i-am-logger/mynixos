{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.usb.xhci;
in
{
  options.my.hardware.usb.xhci = {
    enable = mkEnableOption "xHCI (USB 3.0) host controller support";
  };

  config = mkIf cfg.enable {
    # xHCI USB 3.0 host controller kernel module
    boot.initrd.availableKernelModules = [ "xhci_pci" ];
  };
}
