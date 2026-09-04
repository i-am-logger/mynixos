# my.virtualisation.containers, which had no coverage at all.
#
# Two things are asserted, and both are about what happens AFTER something has
# already gone wrong:
#
#   * the restart pacing, which is the only thing that tells a role healing
#     itself from a role crash-looping. The two shapes are separated by timing
#     alone, so the numbers ARE the mechanism and a silent revert to the NixOS
#     defaults (100ms / 10s / 5) would collapse them into each other;
#   * the passt overlay, because the fix for the crash that started all of this
#     reaches the runtime through pkgs.passt and nothing else says so.
#
# The overlay check is paired against unpatched nixpkgs on purpose: without the
# pairing it would pass just as happily if upstream started carrying a patch
# with a similar name, and this suite would then be measuring nixpkgs instead of
# this repo.
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
    pkgs.runCommand "virtualisation-containers-${name}" { }
      (if cond then "echo 'PASS: ${name}' > $out"
      else builtins.throw "FAIL: ${name} -- ${detail}");

  # The guest. Deliberately the smallest role that still evaluates: nothing here
  # knows what a guest does, so a container of `my.system` alone exercises the
  # same host-side plumbing a radicle seed would.
  guest = self.lib.mkSystem {
    system = "x86_64-linux";
    hostname = "guest-role";
    # The role names ITSELF: `name` defaults to the guest's own
    # my.system.hostname, which is what stopped a role once being called
    # `radicle-radicle-yoga-seed`. No `my.system.enable`, for the same reason a
    # real role does not set it: its opinionated host defaults include an
    # initrd, and the image has no boot to run one in.
    my.system.hostname = "guest-role";
  };

  # The host that runs it. The whole EVALUATION is kept rather than just
  # `.config`, because the overlay checks below need the `pkgs` the modules
  # actually saw -- `config.nixpkgs.pkgs` is the input option and is empty here.
  hostWith = roles: self.lib.mkSystem {
    platform = "linux";
    hostname = "container-host";
    my.virtualisation.containers = roles;
    extraModules = [{
      boot.loader.grub.devices = [ "nodev" ];
      fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
      system.stateVersion = "24.11";
      nixpkgs.hostPlatform = "x86_64-linux";
    }];
  };

  guestHost = hostWith [{ system = guest; }];
  withGuest = guestHost.config;
  withoutGuest = hostWith [ ];

  unit = withGuest.systemd.services."podman-guest-role";
in
{
  # --- Restart pacing: the two failure shapes ------------------------------

  # A liveness-driven restart is a slow cycle -- guest boot, then the probe's
  # start delay, then its hysteresis -- so at 30s apart inside a 300s window it
  # never reaches the burst and the role self-heals for as long as the tailnet
  # stays away. A fast crash (a bad identity, a missing mount) is five starts
  # inside two minutes, which trips the limit, latches `failed` and shows up in
  # `systemctl --failed`. Those are the same mechanism separated only by these
  # three numbers.
  virtualisation-containers-restart-pacing =
    check "restart-pacing"
      (
        unit.serviceConfig.RestartSec or null == "30s"
        && unit.startLimitIntervalSec or null == 300
        && unit.startLimitBurst or null == 5
        # nixpkgs' own Restart must survive: these three MERGE with it rather
        # than replacing it, and a role that stopped restarting at all would
        # pass every number above.
        && unit.serviceConfig.Restart or null == "on-failure"
      )
      ("a role's podman unit must pace restarts at 30s inside a 300s window with a "
        + "burst of 5, on top of nixpkgs' Restart=on-failure -- the NixOS defaults "
        + "(100ms/10s/5) cannot tell a self-healing role from a crash loop");

  # StartLimitAction takes FailureAction's value set, so `exit` here would be
  # read by the HOST's PID 1, fail its container check, and POWER THE MACHINE
  # OFF. The default (`none`) is the only correct value and the way to get it is
  # to never write the directive.
  virtualisation-containers-start-limit-action-stays-default =
    check "start-limit-action-stays-default"
      (
        !(unit.unitConfig ? StartLimitAction)
        && !(unit.serviceConfig ? StartLimitAction)
        # Control: this unit really is the one being paced, so the absences
        # above are about a unit that exists.
        && unit.serviceConfig.RestartSec or null == "30s"
      )
      "StartLimitAction must stay unset: on a host's PID 1 its `exit` falls through to poweroff";

  # --- The guest journal the operator has to be able to read ---------------

  # journald inside the guest writes 0640 owned by container root and a gid in
  # the role's SUBORDINATE range, so no mode and no group membership on the host
  # can ever reach it -- an ACL is the only mechanism left. `setfacl` does not
  # resolve in this unit's stock PATH, and a Type=oneshot reports that as a bare
  # "command not found", so the package and the call are asserted together.
  virtualisation-containers-journal-is-readable-by-acl =
    let prepare = withGuest.systemd.services."guest-role-prepare"; in
    check "journal-is-readable-by-acl"
      (
        lib.any (p: lib.hasInfix "acl" (baseNameOf (toString p))) prepare.path
        && lib.hasInfix "setfacl" prepare.script
        # The DEFAULT entry is the load-bearing half: an access entry alone
        # covers the tree that exists now and nothing journald creates later,
        # which is the machine-id directory and every rotated file.
        && lib.hasInfix "-m d:g:wheel:rX" prepare.script
        # And the state directory itself keeps 0700 -- traversal is granted by
        # the ACL, not by widening the mode into the other volumes.
        && lib.hasInfix "install -d -m 0700" prepare.script
      )
      ("the prepare unit must carry pkgs.acl and grant wheel/adm a DEFAULT ACL on "
        + "the journal while leaving the state directory at 0700");

  # --- The passt overlay ---------------------------------------------------

  # pasta is podman's rootless network helper, and the crash that started this
  # takes every guest's only path to the network with it. The overlay is how the
  # patched binary reaches the runtime.
  virtualisation-containers-passt-is-patched =
    let
      ours = guestHost.pkgs.passt.patches or [ ];
      upstream = nixpkgs.legacyPackages.${system}.passt.patches or [ ];
      carries = ps: lib.any (p: baseNameOf (toString p) == "udp-sock-errs-null-flow.patch") ps;
    in
    check "passt-is-patched"
      (
        carries ours
        # The pairing. When nixpkgs picks up the upstream fix this keeps
        # passing, but tests/passt-null-flow.nix stops -- between them, "the
        # overlay is live" and "the overlay is still needed" are separate
        # questions with separate answers.
        && !(carries upstream)
      )
      ("pkgs.passt on a host must carry udp-sock-errs-null-flow.patch and plain "
        + "nixpkgs must not, or this is measuring upstream rather than the overlay");

  # The overlay ships with the containers module, not with a host that happens
  # to run a guest: pasta is podman's helper, so any Linux host that could run
  # one needs the patched binary whether or not it declares a role today.
  virtualisation-containers-passt-patch-is-fleet-wide =
    check "passt-patch-is-fleet-wide"
      (lib.any (p: baseNameOf (toString p) == "udp-sock-errs-null-flow.patch")
        (withoutGuest.pkgs.passt.patches or [ ]))
      "the passt overlay must apply to every Linux host, not only ones declaring a container role";
}
