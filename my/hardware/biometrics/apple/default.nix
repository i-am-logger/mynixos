# Touch ID and Apple Watch for sudo.
#
# /etc/pam.d/sudo on macOS 14+ carries `auth include sudo_local` on line 2, and
# /etc/pam.d/sudo_local does not normally exist, so nix-darwin creates it cleanly
# with no patching. That indirection is the point of sudo_local: edits to
# /etc/pam.d/sudo itself are wiped by every macOS update.
#
# A hardware module doing its own wiring is the same shape as
# my/hardware/bluetooth/realtek -- the category option says the machine has the
# capability, the vendor directory implements it.
#
# Imported only by platforms/darwin.nix, so no isDarwin guard is needed.
#
# Not covered here: Touch ID for git/GitHub. That is a Secure Enclave SSH key via
# Secretive, which is per-user (home-manager) rather than hardware, and the key
# itself cannot be provisioned declaratively -- it is created in the app, and its
# public half uploaded to GitHub twice, once as an Authentication key and once as
# a Signing key.
{ config, lib, ... }:

let
  cfg = config.my.hardware.biometrics;
in
{
  config = lib.mkIf cfg.enable {
    security.pam.services.sudo_local = {
      enable = true;
      touchIdAuth = cfg.touchId.enable;
      reattach = cfg.touchId.enable && cfg.touchId.reattach;
      watchIdAuth = cfg.watchId.enable;
    };
  };
}
