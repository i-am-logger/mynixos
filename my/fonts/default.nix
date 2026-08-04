# System fonts, on both platforms.
#
# NixOS installs into the fontconfig path; nix-darwin rsyncs real files (not
# symlinks) into "/Library/Fonts/Nix Fonts", because macOS only scans
# /Library/Fonts and ~/Library/Fonts and never looks inside a Nix profile.
# `fonts.packages` is the option both platforms declare, so one module serves
# both and this is imported by platforms/common.nix.
{ config, pkgs, ... }:

let
  cfg = config.my.fonts;
in
{
  config = {
    # A host that names its own fonts replaces the default outright -- listOf
    # would otherwise concatenate, and "I chose Iosevka" should not silently mean
    # "Iosevka and FiraCode".
    fonts.packages =
      if cfg.packages != [ ] then cfg.packages else [ pkgs.nerd-fonts.fira-code ];
  };
}
