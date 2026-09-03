# Turning off the mount-based hardening, for units that run inside a role.
#
# SHARED because it applies to every unit this domain defines, and the reason is
# a property of the MACHINE rather than of any one unit: a rootless container
# has no CAP_SYS_ADMIN, so anything systemd implements with mount(2) fails at
# step NAMESPACE. Fixing only the unit that failed first is how the CI broker
# and the seeding oneshot were left broken after radicle-node was repaired.
#
# It lived as a `let` binding in ./default.nix, invisible to ./mirror.nix and
# ./ci.nix. Copying it into each would be two copies of something subtle, which
# on this fleet has already meant one copy silently wrong.
{ lib, config }:

lib.mkIf config.boot.isContainer {
  confinement.enable = lib.mkForce false;

  # Disabling confinement is NOT enough. The base units carry more directives
  # that systemd implements with mount(2), and every one fails the same way.
  # They fall into two kinds, and only one is a loss:
  #
  #   DELIVERY -- BindReadOnlyPaths puts files at the paths a unit reads. Those
  #   files are already in the image; the mount is only how upstream gets them
  #   into place, and symlinks do the same job with no capability at all.
  #
  #   HARDENING -- ProtectSystem, PrivateTmp, ProtectHome, ProtectProc,
  #   ProcSubset. These have no substitute without mount namespacing, and they
  #   are genuinely lost. What remains is the container boundary: rootless, a
  #   user namespace, no SYS_ADMIN, no-new-privileges, a bounded capability set.
  #   One boundary, not two.
  serviceConfig = {
    BindReadOnlyPaths = lib.mkForce [ ];
    PrivateTmp = lib.mkForce false;
    ProtectHome = lib.mkForce false;
    ProtectSystem = lib.mkForce false;
    ProtectProc = lib.mkForce "default";
    ProcSubset = lib.mkForce "all";
  };
}
