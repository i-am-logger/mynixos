# Inbound SSH on macOS: authorized keys + sshd hardening.
#
# The Linux module (./default.nix) sets users.users.<name>.openssh.authorizedKeys
# from each user's YubiKey public keys; nix-darwin's openssh module has no such
# option, so before this file NOTHING put a public key on a Mac and every inbound
# hop was password-only. Keys land in /etc/ssh/authorized_keys.d/<user> -- the
# same pattern NixOS uses -- rather than home-manager files in ~/.ssh, keeping a
# system-level concern out of user homes and away from sshd's StrictModes rules
# about ownership along symlink chains.
#
# Hardening lives in sshd_config.d/010-mynixos.conf. The 010 prefix is
# load-bearing: macOS's stock sshd_config includes sshd_config.d/* FIRST and
# OpenSSH takes the first value for each keyword, so this file must sort before
# Apple's 100-macos.conf (which sets UsePAM yes and leaves password auth on).
# nix-darwin's own services.openssh.extraConfig writes 100-nix-darwin.conf,
# which sorts after Apple's file and loses -- that is why it is not used here.
#
# Gated on services.openssh.enable: a Mac that has not turned on Remote Login
# gets neither keys nor config. Imported only by platforms/darwin.nix.
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
  config = mkIf config.services.openssh.enable {
    environment.etc =
      {
        "ssh/sshd_config.d/010-mynixos.conf".text = ''
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          PermitRootLogin no
          AuthenticationMethods publickey
          AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
        '';
      }
      // mapAttrs'
        (name: userCfg:
          nameValuePair "ssh/authorized_keys.d/${name}" {
            text = concatStringsSep "\n" (keysFor userCfg) + "\n";
          })
        usersWithKeys;
  };
}
