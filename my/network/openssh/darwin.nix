# Inbound SSH on macOS: authorized keys + sshd hardening.
#
# Keys come from each user's YubiKey public keys -- the same source the Linux
# module (./default.nix) uses -- and are handed to nix-darwin's
# `users.users.<name>.openssh.authorizedKeys.keys`. nix-darwin writes them to
# /etc/ssh/nix_authorized_keys.d/<user> and teaches sshd to read that with
#
#   AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u
#
# in its own sshd_config.d/101-authorized-keys.conf.
#
# WHY NOT environment.etc ANY MORE
#
# This file used to write /etc/ssh/authorized_keys.d/<user> by hand, because
# nix-darwin had no authorizedKeys option when it was written. nix-darwin has
# one now, and it also added an UNCONDITIONAL activation check
# (modules/system/checks.nix: `if [[ -d /etc/ssh/authorized_keys.d ]]`) that
# aborts while the legacy directory exists. Writing that path by hand therefore
# does not merely duplicate the option -- because environment.etc recreates the
# directory on every activation, it wedges the host into a state where every
# subsequent `darwin-rebuild switch` aborts. Use the option.
#
# Keys stay out of user homes either way, which is what the old hack was for:
# nix-darwin's AuthorizedKeysCommand is the only key source configured here.
# Note the deliberate ABSENCE of an AuthorizedKeysFile line below -- adding one
# would newly permit ~/.ssh/authorized_keys, which this module has always
# avoided (sshd's StrictModes rules about ownership along symlink chains).
#
# Hardening lives in sshd_config.d/010-mynixos.conf. The 010 prefix is
# load-bearing: macOS's stock sshd_config includes sshd_config.d/* FIRST and
# OpenSSH takes the first value for each keyword, so this file must sort before
# Apple's 100-macos.conf (which sets UsePAM yes and leaves password auth on).
# nix-darwin's own services.openssh.extraConfig writes 100-nix-darwin.conf,
# which sorts after Apple's file and loses -- that is why it is not used here.
# Apple's file sets neither AuthorizedKeysFile nor AuthorizedKeysCommand, so
# nix-darwin's 101 file is unopposed.
#
# Gated on services.openssh.enable == true: nix-darwin types that option as
# nullOr bool, where null means "leave Remote Login alone" -- a Mac that has
# not turned it on gets neither keys nor config. Imported only by
# platforms/darwin.nix.
{ config, lib, ... }:

with lib;

let
  usersWithKeys = filterAttrs
    (_: userCfg: (length (userCfg.yubikeys or [ ])) > 0)
    config.my.users;

  keysFor = userCfg:
    filter (k: k != "") (map (yk: yk.sshPublicKey) userCfg.yubikeys);
in
{
  config = mkIf (config.services.openssh.enable == true) {
    environment.etc."ssh/sshd_config.d/010-mynixos.conf".text = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AuthenticationMethods publickey
    '';

    users.users = mapAttrs
      (_: userCfg: { openssh.authorizedKeys.keys = keysFor userCfg; })
      usersWithKeys;
  };
}
