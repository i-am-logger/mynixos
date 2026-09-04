# The SHAPE of the tailnet liveness probe: which unit is allowed to take a role
# down, which one must never be, and the handful of directives whose presence or
# absence silently switches the whole design off.
#
# tests/tailnet-liveness-probe.nix covers the probe's VERDICTS by running the
# generated script; this file covers what systemd is handed.
#
# Everything here is paired with a control, on the same rule the rest of this
# directory follows: an "X is absent" check passes just as happily when the unit
# was renamed, the option deleted or the module dropped. So each absence is
# asserted beside a presence that proves the accessor still reads something.
#
# The pairing that matters most is role-vs-host. `FailureAction=exit` inside a
# container asks PID 1 to exit; on a host's PID 1 the container check fails and
# systemd POWERS THE MACHINE OFF instead. The only thing standing between those
# two outcomes is that platforms/oci-variant.nix arms the escalation and
# my/network/tailscale does not -- which is exactly what is asserted below.
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
    pkgs.runCommand "tailnet-liveness-${name}" { }
      (if cond then "echo 'PASS: ${name}' > $out"
      else builtins.throw "FAIL: ${name} -- ${detail}");

  # A machine seen AS ITS CONTAINER IMAGE, the same accessor tests/oci-platform
  # uses: `virtualisation.ociVariant` is the extended configuration the image is
  # built from, so asserting on it is asserting on what a role actually boots.
  role = my: (self.lib.mkSystem {
    system = "x86_64-linux";
    hostname = "liveness-shape";
    inherit my;
  }).config.virtualisation.ociVariant;

  # The control. A real NixOS host with the SAME `my`, so any difference between
  # the two is attributable to platforms/oci-variant.nix and nothing else.
  host = my: (self.lib.mkSystem {
    platform = "linux";
    hostname = "liveness-shape-control";
    inherit my;
    extraModules = [{
      boot.loader.grub.devices = [ "nodev" ];
      fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
      system.stateVersion = "24.11";
      nixpkgs.hostPlatform = "x86_64-linux";
    }];
  }).config;

  # A role gets liveness from oci-variant's mkDefault; a host has to ask. Both
  # sides name the same peer so the two configurations differ in exactly one
  # thing: which platform file they went through.
  tailscale = liveness: {
    network.tailscale = {
      enable = true;
      tags = [ "tag:test" ];
      inherit liveness;
    };
  };

  roleCfg = role (tailscale { peers = [ "peer0" ]; });
  hostCfg = host (tailscale { enable = true; peers = [ "peer0" ]; });

  probe = c: c.systemd.services.tailnet-liveness;
  escalation = c: c.systemd.services.tailnet-datapath-dead;

  # Directive families that must not appear on the probe, each with the failure
  # it would produce. Matched by PREFIX because the point is the family, not a
  # list of spellings that a new systemd release can grow past.
  forbiddenPrefixes = [
    # A condition that is not met SKIPS the unit rather than failing it, so no
    # state transition happens and nothing downstream ever fires. It is the
    # quietest possible way to turn this design off.
    "Condition"
    "Assert"
    # Every one of these is implemented with mount(2), which a rootless role has
    # no CAP_SYS_ADMIN to call. Some report ENOANO and are skipped; the rest fail
    # the unit at NAMESPACE -- in every role at once.
    "Protect"
    "Private"
    "Restrict"
    "BindPaths"
    "BindReadOnlyPaths"
    "TemporaryFileSystem"
    "RootDirectory"
    "MountAPIVFS"
    "ProcSubset"
  ];

  hasForbidden = attrs:
    lib.any (n: lib.any (p: lib.hasPrefix p n) forbiddenPrefixes) (lib.attrNames attrs);

  # "Ns" -> N. The unit's start timeout is derived from retries/retryDelay, so
  # the checks below read it as a number rather than pinning a literal that
  # would have to be edited every time a default moves.
  seconds = s: lib.toInt (lib.removeSuffix "s" s);

  timeoutOf = { retries, retryDelay, peers }:
    seconds (probe (role (tailscale { inherit retries retryDelay peers; }))).serviceConfig.TimeoutStartSec;
in
{
  # --- The escalation, and the machine it is allowed to stop -----------------

  # `FailureAction=`/`FailureActionExitStatus=` are [Unit] keys. Put in
  # [Service] they are still reported by `systemctl show` and simply never
  # fire -- the same species of silent non-failure the probe exists to remove,
  # so the section is asserted, not the value alone.
  #
  # 69 is EX_UNAVAILABLE, chosen against three traps: not 0 (which
  # `Restart=on-failure` reads as success -- a `podman stop` on a systemd PID 1
  # yields exactly that), not podman's reserved 125-127, not a signal's 137/143.
  tailnet-liveness-escalation-armed-only-in-a-role =
    check "escalation-armed-only-in-a-role"
      (
        (escalation roleCfg).unitConfig.FailureAction or null == "exit"
        && (escalation roleCfg).unitConfig.FailureActionExitStatus or null == 69
        && !((escalation roleCfg).serviceConfig ? FailureAction)
        # The host runs the same module and MUST NOT get the action: on a host's
        # PID 1 `exit` fails systemd's container check and falls through to
        # poweroff, so this pairing is what stops a laptop's probe from powering
        # off the laptop.
        && (hostCfg.systemd.services ? tailnet-datapath-dead)
        && !((escalation hostCfg).unitConfig ? FailureAction)
        && !((escalation hostCfg).serviceConfig ? FailureAction)
      )
      ("a role's tailnet-datapath-dead must carry FailureAction=exit and "
        + "FailureActionExitStatus=69 in [Unit]; a plain host must get the same unit "
        + "with neither, or the directive powers the machine off instead of exiting");

  # The escalation is a unit of its own precisely because FailureAction fires on
  # ANY failure of the unit carrying it. On the probe it could not tell "no peer
  # answered" from "jq was OOM-killed" -- and the second is reachable from
  # repository-supplied shell inside a builder, which would hand it a reboot
  # primitive over its own role.
  tailnet-liveness-probe-never-carries-the-escalation =
    check "probe-never-carries-the-escalation"
      (
        !((probe roleCfg).unitConfig ? FailureAction)
        && !((probe roleCfg).unitConfig ? FailureActionExitStatus)
        && !((probe roleCfg).serviceConfig ? FailureAction)
        && !((probe roleCfg).serviceConfig ? FailureActionExitStatus)
        # Paired: the same role DOES arm the other unit, so this is measuring
        # placement rather than a module that failed to load.
        && (escalation roleCfg).unitConfig.FailureAction or null == "exit"
      )
      ("tailnet-liveness must carry no FailureAction in either section -- one unit "
        + "cannot express both verdicts, and the escalation belongs on "
        + "tailnet-datapath-dead, which this role does arm");

  # The probe only ever STARTS the escalation, and only from the one branch that
  # concluded the datapath is dead. If that call ever moves, grows a second
  # site, or is replaced by something else, this fails by name -- and so does
  # tests/tailnet-liveness-probe.nix, which rewrites exactly this line.
  tailnet-liveness-escalation-started-from-exactly-one-place =
    let
      inherit ((probe roleCfg)) script;
      needle = "start tailnet-datapath-dead.service";
    in
    check "escalation-started-from-exactly-one-place"
      (
        lib.length (lib.filter (l: lib.hasInfix needle l) (lib.splitString "\n" script)) == 1
        && lib.hasInfix "systemctl --no-block ${needle}" script
      )
      ("the probe must start tailnet-datapath-dead from exactly one line, with "
        + "--no-block so a probe run cannot block on the manager it is about to stop");

  # --- The two ways this silently stops working ------------------------------

  tailnet-liveness-probe-has-no-suppressors =
    let
      sc = (probe roleCfg).serviceConfig;
      uc = (probe roleCfg).unitConfig;
    in
    check "probe-has-no-suppressors"
      (
        # A Restart= would retry the unit instead of letting the run reach a
        # verdict, and would restart it out from under its own hysteresis.
        !(sc ? Restart)
        # RemainAfterExit leaves a oneshot `active (exited)` forever, so
        # OnUnitInactiveSec never re-arms -- the pairing that left the hourly
        # uid/gid drift check running exactly once per boot.
        && !(sc ? RemainAfterExit)
        && !(hasForbidden sc) && !(hasForbidden uc)
        && !((probe roleCfg).confinement.enable or false)
        # The control. Without it every line above passes when serviceConfig is
        # empty, renamed away, or never populated at all.
        && sc.Type == "oneshot"
        && (sc ? TimeoutStartSec)
        # A oneshot that DOES keep RemainAfterExit, from the same module and the
        # same mkIf branch, so the accessor is proven to see the directive when
        # it is there.
        && (roleCfg.systemd.services.tailscale-udp-gro.serviceConfig.RemainAfterExit or false)
      )
      ("the probe must declare no Restart, no RemainAfterExit, no Condition*/Assert*, "
        + "and no mount-based sandboxing -- while still being the oneshot with a "
        + "derived TimeoutStartSec that the design describes");

  # The probe must not be the first thing killed by pressure it is not the cause
  # of: inside a builder, repository-supplied shell can drive the cgroup to its
  # `memory` ceiling, and the probe losing that race is a guest-local event
  # reported as an unreachable tailnet.
  tailnet-liveness-probe-is-protected-from-guest-pressure =
    let sc = (probe roleCfg).serviceConfig; in
    check "probe-is-protected-from-guest-pressure"
      (sc.OOMScoreAdjust or 0 < 0 && (sc ? MemoryMin))
      "the probe needs a negative OOMScoreAdjust and a MemoryMin reservation, or guest-local memory pressure presents itself as a dead tailnet";

  tailnet-liveness-timer-rearms-from-inactive =
    let tc = roleCfg.systemd.timers.tailnet-liveness.timerConfig; in
    check "timer-rearms-from-inactive"
      (
        (tc ? OnUnitInactiveSec)
        && !(tc ? OnUnitActiveSec)
        # Control: the timer is really the one driving this unit, so the two
        # assertions above are about the probe and not about an empty attrset.
        && tc.Unit == "tailnet-liveness.service"
        && (tc ? OnBootSec)
      )
      "the probe's timer must re-arm from OnUnitInactiveSec: OnUnitActiveSec measures from the START of a run, so a run longer than the interval re-triggers the moment it ends";

  # The general form of the bug above, checked structurally rather than by
  # remembering to look. A timer-driven oneshot that keeps RemainAfterExit and
  # re-arms from OnUnitActiveSec never fires again after its first run, and
  # reports `active` the whole time.
  tailnet-liveness-no-unit-pairs-remain-after-exit-with-on-unit-active-sec =
    let
      offenders = c:
        lib.filter
          (n:
            let
              t = c.systemd.timers.${n}.timerConfig or { };
              unit = lib.removeSuffix ".service" (t.Unit or "${n}.service");
              s = c.systemd.services.${unit} or null;
            in
            (t ? OnUnitActiveSec)
            && s != null
            && (s.serviceConfig.RemainAfterExit or false))
          (lib.attrNames c.systemd.timers);
      scanned = c: lib.length (lib.attrNames c.systemd.timers);
    in
    check "no-unit-pairs-remain-after-exit-with-on-unit-active-sec"
      (
        offenders roleCfg == [ ] && offenders hostCfg == [ ]
        # Not vacuous: there really are timers to scan on both sides.
        && scanned roleCfg > 1 && scanned hostCfg > 1
      )
      ("a timer-driven oneshot that keeps RemainAfterExit and re-arms from "
        + "OnUnitActiveSec runs exactly once per boot while reporting active -- "
        + "offenders: "
        + lib.concatStringsSep ", " (offenders roleCfg ++ offenders hostCfg));

  # --- The knobs the design says may be widened ------------------------------

  # `retries` and `retryDelay` are user-settable, and widening them past the
  # 90s DefaultTimeoutStartSec would otherwise SIGTERM every run on a healthy
  # node and report a start timeout instead of a peer result -- a guaranteed
  # reboot loop with a journal line about the wrong thing. So the timeout is
  # derived, and this is what says so.
  tailnet-liveness-start-timeout-is-derived-from-the-hysteresis =
    let
      base = timeoutOf { retries = 10; retryDelay = 60; peers = [ "peer0" ]; };
      wide = timeoutOf { retries = 10; retryDelay = 300; peers = [ "peer0" ]; };
      many = timeoutOf { retries = 10; retryDelay = 60; peers = [ "peer0" "peer1" "peer2" ]; };
    in
    check "start-timeout-is-derived-from-the-hysteresis"
      (
        # Every configuration must leave room for its own sleeps, and the
        # widened one must clear the 90s default it would otherwise collide with.
        base > 9 * 60 && wide > 9 * 300 && wide > 90
        # More peers is more pings, so the budget has to grow with them too.
        && many > base
      )
      "TimeoutStartSec must be derived from retries, retryDelay and the peer count, or widening the hysteresis silently makes every run time out";

  # --- The peers the whole predicate rests on --------------------------------

  # With no peer the probe would report healthy on exactly the failure it was
  # added to catch, so this refuses to evaluate rather than shipping a guard
  # that cannot fail. `config.assertions` is not forced by reading other
  # attributes, so it is read explicitly.
  tailnet-liveness-peerless-role-is-refused =
    let
      failing = c: lib.filter (a: !a.assertion) c.assertions;
      peerless = role (tailscale { peers = [ ]; });
    in
    check "peerless-role-is-refused"
      (
        lib.any (a: lib.hasInfix "liveness.peers = [ ]" a.message) (failing peerless)
        # Control: the same role WITH a peer asserts nothing, so the check above
        # is not just observing a config that fails for another reason.
        && failing roleCfg == [ ]
      )
      "a role with liveness on and no peers must fail an assertion naming liveness.peers, and a role with one must raise none";

  # A peer is derived from radicle's own `connect` list so the two cannot drift.
  # An entry dialled by ADDRESS contributes nothing rather than contributing
  # nonsense: `z6...@100.65.29.53:8776` would otherwise yield the peer "100",
  # which matches no node, never answers, and reports a dead datapath forever.
  # Naming nothing instead makes the peers assertion above fire, which is an
  # eval error someone must answer.
  tailnet-liveness-peers-derive-from-radicle-connect =
    let
      radicle = connect: role {
        network.tailscale = { enable = true; tags = [ "tag:test" ]; };
        infra.radicle = {
          enable = true;
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest";
          node.connect = connect;
        };
      };
      named = radicle [ "z6Mktest@seed-host.tail0000.ts.net:8776" ];
      literal = radicle [ "z6Mktest@100.65.29.53:8776" ];
      mixed = radicle [ "z6Mktest@100.65.29.53:8776" "z6Mktest@seed-host.tail0000.ts.net:8776" ];
      peersOf = c: c.my.network.tailscale.liveness.peers;
    in
    check "peers-derive-from-radicle-connect"
      (
        peersOf named == [ "seed-host" ]
        && peersOf literal == [ ]
        && peersOf mixed == [ "seed-host" ]
        # An address-only node therefore names no peer, and the assertion is
        # what stops it booting a probe that can never pass.
        && lib.any (a: lib.hasInfix "liveness.peers = [ ]" a.message)
          (lib.filter (a: !a.assertion) literal.assertions)
      )
      "a connect entry must contribute its host's first label as a peer, and an entry dialled by IP must contribute nothing so the peers assertion fires";
}
