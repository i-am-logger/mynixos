# The base CLI set, on every platform.
#
# Split out of my/system/core (which is Linux-only) so a Mac is not left with
# nothing but nix-darwin infrastructure. Everything here builds on both
# x86_64-linux and aarch64-darwin and does the same job on each.
#
# Only what every host needs before anyone has chosen anything. The rest has an
# owner: sops comes with my.secrets, pass with the password app
# (apps.security.passwords.pass), and mc, yazi, helix, fastfetch, btop and
# screen are per-user apps -- so turning one off removes it.
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
      tree
      wget
      curl
    ];
  };
}
