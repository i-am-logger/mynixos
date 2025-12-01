{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.network;
in
{
  config = mkIf (cfg.enable) {
    # Generic network configuration
    networking.networkmanager.enable = lib.mkDefault true;
    networking.wireless.enable = lib.mkDefault false;

    # Prevent NetworkManager from managing CNI interfaces
    environment.etc."NetworkManager/conf.d/99-unmanaged-cni.conf".text = ''
      [keyfile]
      unmanaged-devices=interface-name:cni*;interface-name:flannel*;interface-name:veth*;interface-name:docker*;interface-name:br-*
    '';
  };
}
