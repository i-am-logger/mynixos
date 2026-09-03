# What platforms/oci.nix has to undo, and the guard that makes a silent failure
# loud.
#
# tests/mksystem.nix covers the DISPATCH -- which evaluator runs, which
# arguments are rejected. This covers the SHAPE of the resulting role: the host
# defaults linux.nix turns on that a container must not run, and the one unit
# that exists purely to convert silence into a failure.
#
# Every check that asserts "a role does not have X" is paired with a control
# proving a plain Linux host DOES have X. Without that pairing the check passes
# just as happily when the option is renamed, the module is dropped, or the
# default flips upstream -- which is the exact failure mode this whole area of
# the repo keeps producing.
{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs;

  check = name: cond: detail:
    pkgs.runCommand "oci-platform-${name}" { }
      (if cond then "echo 'PASS: ${name}' > $out"
      else builtins.throw "FAIL: ${name} -- ${detail}");

  # A role takes no extraModules: platforms/oci.nix supplies the stateVersion
  # and the docker-container profile relaxes the `fileSystems."/"` requirement.
  # A role needing a prelude here would be a role a consumer could not write.
  # A machine seen AS ITS CONTAINER IMAGE. `virtualisation.ociVariant` is the
  # extended configuration that image is built from -- the same relationship
  # `virtualisation.vmVariant` has to system.build.vm -- so asserting on it is
  # asserting on exactly what lands in the image.
  role = my: (self.lib.mkSystem {
    system = "x86_64-linux";
    hostname = "oci-shape";
    inherit my;
  }).config.virtualisation.ociVariant;

  # The control. A real NixOS host, same `my`, so a difference between the two
  # is attributable to platforms/oci-variant.nix and nothing else.
  host = my: (self.lib.mkSystem {
    platform = "linux";
    hostname = "oci-shape-control";
    users = [{
      name = "alice";
      homeManager = { home.stateVersion = "24.11"; };
      nixosUser = { users.users.alice = { isNormalUser = true; group = "users"; }; };
    }];
    inherit my;
    extraModules = [{
      boot.loader.grub.devices = [ "nodev" ];
      fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
      system.stateVersion = "24.11";
      nixpkgs.hostPlatform = "x86_64-linux";
    }];
  }).config;

  tailscale = {
    network.tailscale = { enable = true; tags = [ "tag:test" ]; authKeyFile = "/run/x"; };
  };
in
{
  # --- The failure that reports success ------------------------------------

  # firewall.service carries ConditionCapability=CAP_NET_ADMIN, and systemd
  # SKIPS a unit whose condition is unmet rather than failing it. A role given
  # no NET_ADMIN therefore comes up `running`, with zero failed units and an
  # EMPTY ruleset -- nothing anywhere reports that the packet filter never
  # loaded. firewall-enforced.service is the only thing standing between that
  # and a role that looks healthy while filtering nothing.
  oci-platform-firewall-guard-exists =
    let r = role { }; h = host { }; in
    check "firewall-guard-exists"
      (
        r.systemd.services ? firewall-enforced
        && r.systemd.services.firewall-enforced.after == [ "firewall.service" ]
        && r.systemd.services.firewall-enforced.wantedBy == [ "multi-user.target" ]
        && (r.systemd.services.firewall-enforced.script or "") != ""
        && !(h.systemd.services ? firewall-enforced)
      )
      ("the guard must exist in a role, run after firewall.service, be pulled in by "
        + "multi-user.target and actually check something -- and must NOT be a nixpkgs "
        + "default, or this check is measuring upstream rather than platforms/oci.nix");

  # Not disabled, enforced. Switching the firewall off would make the guard
  # pointless and was explicitly rejected: if a role needs a port, the feature
  # that needs it opens it.
  oci-platform-keeps-the-firewall =
    check "keeps-the-firewall"
      (role { }).networking.firewall.enable
      "a role must still run the packet filter -- the guard exists to prove it loaded, not to excuse turning it off";

  # --- Host daemons a container must not run --------------------------------

  # openrgb is the one that matters: it runs as root with a TCP listener and
  # I2C/SMBus access, and it is on by DEFAULT fleet-wide. In the one role that
  # runs repository-supplied shell it is pure attack surface.
  oci-platform-drops-host-daemons =
    let r = role { }; h = host { }; in
    check "drops-host-daemons"
      (
        !r.services.hardware.openrgb.enable && h.services.hardware.openrgb.enable
        && !r.my.hardware.audio.enable && h.my.hardware.audio.enable
        && !r.systemd.oomd.enable && h.systemd.oomd.enable
      )
      "a role must not run openrgb, audio or systemd-oomd, and a plain host must still run all three (otherwise this check proves nothing)";

  # sshd is off on a bare host too, so comparing bare configs would prove
  # nothing. With tailscale on -- which AUTO-ENABLES sshd -- the difference is
  # real, and it also pins the port-ownership rule: the tailnet port belongs to
  # my/network/openssh, gated on services.openssh.enable, so a role that
  # switches sshd off advertises nothing rather than opening 22 anyway.
  oci-platform-no-sshd-and-no-port =
    let r = role tailscale; h = host tailscale; in
    check "no-sshd-and-no-port"
      (
        r.services.tailscale.enable && h.services.tailscale.enable
        && !r.services.openssh.enable && h.services.openssh.enable
        && r.networking.firewall.interfaces.tailscale0.allowedTCPPorts or [ ] == [ ]
        && builtins.elem 22 h.networking.firewall.interfaces.tailscale0.allowedTCPPorts
      )
      "with tailscale enabled a host must get sshd and port 22 on tailscale0, and a role must get neither";

  # --- Two fixes that are easy to get wrong in the obvious direction --------

  # nscd failing in a rootless container reads as a permissions problem and is
  # not one: it drops to a User= AND installs a seccomp filter, and dies at step
  # USER without CAP_SYS_ADMIN. The fix is RestrictSUIDSGID, not disabling the
  # service -- disabling it was tried first and was wrong, so this pins it.
  oci-platform-keeps-nscd =
    let r = role { }; in
    check "keeps-nscd"
      (r.services.nscd.enable && r.systemd.services.nscd.serviceConfig.RestrictSUIDSGID == false)
      "nscd must stay ENABLED with RestrictSUIDSGID off -- switching the service off instead breaks NSS lookups in the role";

  # /run/wrappers cannot be a mount without CAP_SYS_ADMIN, so the mount unit is
  # masked and a tmpfiles rule makes the directory instead. The tempting
  # shortcut -- `security.wrappers = mkForce { }` -- empties the set, deleting
  # wrappers that things genuinely use. Both halves are asserted because either
  # alone is a broken role.
  oci-platform-wrappers-replaced-not-deleted =
    let r = role { }; in
    check "wrappers-replaced-not-deleted"
      (
        r.systemd.units."run-wrappers.mount".enable == false
        && builtins.elem "d /run/wrappers 0755 root root -" r.systemd.tmpfiles.rules
        && builtins.length (builtins.attrNames r.security.wrappers) > 0
      )
      "the mount must be masked, a tmpfiles rule must replace it, and security.wrappers must NOT be emptied";

  # A container gets no machine-id from the host, and several units refuse to
  # start without one. It is generated during activation rather than baked into
  # the image, so every container from one image is a distinct machine.
  oci-platform-generates-machine-id =
    let r = role { }; h = host { }; in
    check "generates-machine-id"
      ((r.system.activationScripts ? machineId) && !(h.system.activationScripts ? machineId))
      "a role must generate /etc/machine-id at activation, and a real host must not need to";
}
