# The base CLI set, on every platform.
#
# Split out of my/system/core (which is Linux-only) so a Mac is not left with
# nothing but nix-darwin infrastructure. Everything here builds on both
# x86_64-linux and aarch64-darwin and does the same job on each.
#
# Only what every host needs before anyone has chosen anything. The rest has an
# owner: sops and pass are per-user apps (apps.security.secrets.sops,
# apps.security.passwords.pass), as are yazi, helix, fastfetch, btop and
# screen -- so turning one off removes it. mc is here: it is the rescue file
# manager, wanted on a host before (or without) any user's apps.
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
      mc
    ];
  };
}
