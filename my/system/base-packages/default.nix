# The base CLI set, on every platform.
#
# Split out of my/system/core (which is Linux-only) so a Mac is not left with
# nothing but nix-darwin infrastructure. Everything here builds on both
# x86_64-linux and aarch64-darwin and does the same job on each.
#
# Deliberately NOT here: usbutils, pciutils, tcpdump and plymouth. They stay in
# my/system/core because lsusb/lspci report nothing useful on macOS (which has
# system_profiler and ioreg), and plymouth is a Linux boot splash.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.system;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Secrets
      sops
      pass

      # CLI tools
      mc
      yazi
      helix
      fastfetch
      tree
      btop
      screen

      # Network
      wget
      curl
    ];
  };
}
