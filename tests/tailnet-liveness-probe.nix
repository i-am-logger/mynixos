# The probe's VERDICTS, driven as sequences against the script systemd really
# runs -- `serviceConfig.ExecStart`, preamble and all, not a copy of it.
#
# The one thing that matters here is which verdicts escalate. Escalation is the
# only path that takes a role's PID 1 down, and everything else the probe can
# conclude has to stop at a failed unit:
#
#   every peer answered                       exit 0, no escalation
#   some answered, some did not               a peer's outage, not this node's
#   BackendState is not Running               NeedsLogin, Stopped, a revoked
#                                             node, a control-plane outage --
#                                             a restart repairs none of them and
#                                             destroys the hand-run repair path
#   the probe could not run at all            an OOM-killed jq, a fork refused
#                                             at pidsLimit: guest-local pressure
#                                             is not an unreachable tailnet
#   nobody answered, backend Running          ESCALATE
#
# And the verdict is the RUN's, not any attempt's: one attempt that could not
# run takes escalation off the table for the whole run, because mixed evidence
# is not evidence of a dead datapath.
#
# WHAT THIS CANNOT REACH, so it is not claimed: the fixture and the parser drift
# together, so no scenario here would notice `tailscale status --json` renaming
# a field. tests/vm-tailnet-liveness.nix asserts the schema against a real
# tailscaled for exactly that reason.
{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs;

  peers = [ "peer0" "peer1" ];

  roleCfg = (self.lib.mkSystem {
    system = "x86_64-linux";
    hostname = "liveness-probe";
    my.network.tailscale = {
      enable = true;
      tags = [ "tag:test" ];
      liveness = {
        inherit peers;
        # Ten attempts, so a mixed run has somewhere to be mixed. The delay
        # between them is what the fake `sleep` below turns into an attempt
        # boundary, and it never actually elapses.
        retries = 10;
        retryDelay = 60;
      };
    };
  }).config.virtualisation.ociVariant;

  probe = roleCfg.systemd.services.tailnet-liveness;

  # The exact file systemd execs. `lib.removeSuffix` keeps the string context,
  # so the script is a real build input rather than a path that happens to
  # exist; the assertion is what stops that silently becoming a truncated
  # command line if ExecStart ever grows arguments.
  probeScript =
    let s = lib.removeSuffix " " probe.serviceConfig.ExecStart; in
    assert !(lib.hasInfix " " s); s;

  # The single line the probe uses to escalate, rewritten below so the test can
  # SEE it fire. Rewriting rather than observing a log line is deliberate: the
  # message and the systemctl call sit next to each other and could drift, and
  # it is the call that takes the role down. tests/tailnet-liveness.nix asserts
  # this line exists exactly once, and the rewrite below fails loudly if it
  # stops matching.
  escalationLine = "${roleCfg.systemd.package}/bin/systemctl --no-block start tailnet-datapath-dead.service";

  # `tailscale status --json` shapes. `.Peer` is an OBJECT keyed by public key
  # in the real thing, and the probe's jq iterates it with `.Peer[]?` -- so the
  # fixture is an object too, or the test would be exercising a parser the real
  # output never meets. DNSName carries a trailing dot, as it does live.
  peerEntry = name: ip: {
    HostName = name;
    DNSName = "${name}.tail0000.ts.net.";
    TailscaleIPs = [ ip "fd7a::${ip}" ];
    Online = true;
  };

  statusJSON = { state, withPeers }: builtins.toJSON {
    BackendState = state;
    Health = [ ];
    Self = { Online = true; DNSName = "self.tail0000.ts.net."; };
    Peer =
      if withPeers then {
        "nodekey:aaa" = peerEntry "peer0" "100.64.0.2";
        "nodekey:bbb" = peerEntry "peer1" "100.64.0.3";
        # A third node whose HostName is `localhost`, which is what phones
        # report on a real tailnet. It is here so the DNSName-first resolution
        # is exercised against a netmap where HostName is not unique.
        "nodekey:ccc" = peerEntry "localhost" "100.64.0.9" // { DNSName = "phone.tail0000.ts.net."; };
      } else { };
  };

  runningWithPeers = statusJSON { state = "Running"; withPeers = true; };
  runningNoPeers = statusJSON { state = "Running"; withPeers = false; };
  stopped = statusJSON { state = "Stopped"; withPeers = true; };
  needsLogin = statusJSON { state = "NeedsLogin"; withPeers = true; };

  # The scripted `tailscale`. One MODE per attempt, taken from `plan`:
  #
  #   ok        every peer answers
  #   some      peer0 answers, peer1 does not
  #   none      the netmap has both, neither answers
  #   absent    the backend is Running and the peers are not in the netmap
  #   stopped   BackendState=Stopped
  #   login     BackendState=NeedsLogin
  #   unread    `tailscale status` exits non-zero (it could not run)
  #   garbage   `tailscale status` succeeds and prints something that is not a
  #             status document
  #   flip      the first status read of the attempt is Running and no peer
  #             answers; the SECOND -- the one the probe takes before calling
  #             the datapath dead -- reports Stopped
  #   flipdead  same, but the second read fails outright
  #
  # `flip`/`flipdead` are the guard that stops guest-local pressure presenting
  # itself as an unreachable tailnet, and they are the reason this fake counts
  # status reads WITHIN an attempt as well as attempts.
  fakeTailscale =
    let
      running = pkgs.writeText "status-running.json" runningWithPeers;
      empty = pkgs.writeText "status-no-peers.json" runningNoPeers;
      halted = pkgs.writeText "status-stopped.json" stopped;
      login = pkgs.writeText "status-needslogin.json" needsLogin;
    in
    pkgs.writeShellScript "fake-tailscale" ''
      n=$(cat "$STATE/attempt")
      mode=$(${pkgs.gnused}/bin/sed -n "''${n}p" "$STATE/plan")
      [ -n "$mode" ] || { echo "fake tailscale: no plan line $n" >&2; exit 90; }

      case "$1" in
        status)
          reads=$(( $(cat "$STATE/reads") + 1 ))
          echo "$reads" > "$STATE/reads"
          case "$mode" in
            unread)  exit 1 ;;
            garbage) echo 'this is not a status document' ;;
            stopped) cat ${halted} ;;
            login)   cat ${login} ;;
            absent)  cat ${empty} ;;
            flip)
              if [ "$reads" -ge 2 ]; then cat ${halted}; else cat ${running}; fi ;;
            flipdead)
              if [ "$reads" -ge 2 ]; then exit 1; else cat ${running}; fi ;;
            *)       cat ${running} ;;
          esac
          ;;
        ping)
          target=""
          for a in "$@"; do target=$a; done
          echo "ping $target ($mode)" >> "$STATE/pings"
          case "$mode" in
            ok)   exit 0 ;;
            some) if [ "$target" = "100.64.0.2" ]; then exit 0; else exit 1; fi ;;
            *)    exit 1 ;;
          esac
          ;;
        *)
          echo "fake tailscale: unexpected subcommand $*" >&2; exit 91 ;;
      esac
    '';

  # The attempt boundary. The probe sleeps between attempts and nowhere else, so
  # shadowing `sleep` both advances the plan and keeps a ten-attempt run
  # instant -- which is what lets the production retries/retryDelay be tested
  # rather than a scaled-down pair that proves nothing about them.
  fakeSleep = pkgs.writeShellScript "fake-sleep" ''
    echo $(( $(cat "$STATE/attempt") + 1 )) > "$STATE/attempt"
    echo 0 > "$STATE/reads"
  '';

  # plan     one mode per attempt, first attempt first
  # exit     the run's expected exit status
  # escalate whether tailnet-datapath-dead must have been started
  # stderr   sentences the operator has to be able to tell the verdicts apart by
  # attempts how far the run got, when stopping early is the property
  scenario =
    { name
    , plan
    , exit
    , escalate
    , stderr ? [ ]
    , attempts ? null
    }:
    pkgs.runCommand "tailnet-liveness-probe-${name}"
      {
        nativeBuildInputs = [ pkgs.jq pkgs.gnused ];
        inherit escalationLine;
      } ''
      export STATE=$PWD/state
      mkdir -p "$STATE" fakebin
      printf '%s\n' ${lib.escapeShellArgs plan} > "$STATE/plan"
      echo 1 > "$STATE/attempt"
      echo 0 > "$STATE/reads"
      : > "$STATE/pings"

      cp ${probeScript} probe.sh
      chmod +w probe.sh

      # The escalation is rewritten into something observable. If the line ever
      # stops matching, this fails HERE rather than quietly turning every
      # "must not escalate" scenario into a tautology.
      hits=$(grep -cF -- "$escalationLine" probe.sh || true)
      if [ "$hits" != 1 ]; then
        echo "FAIL: expected exactly one escalation line in the probe, found $hits" >&2
        echo "  looked for: $escalationLine" >&2
        exit 1
      fi
      sed -i "s|$escalationLine|touch \"\$STATE/escalated\"|" probe.sh

      ln -s ${fakeTailscale} fakebin/tailscale
      ln -s ${fakeSleep} fakebin/sleep
      export PATH=$PWD/fakebin:$PATH

      rc=0
      ./probe.sh > out.log 2> err.log || rc=$?
      echo "--- stdout ---"; cat out.log
      echo "--- stderr ---"; cat err.log
      echo "--- pings ---"; cat "$STATE/pings"
      echo "--- attempts reached: $(cat "$STATE/attempt") ---"

      if [ "$rc" != ${toString exit} ]; then
        echo "FAIL: ${name} exited $rc, expected ${toString exit}" >&2
        exit 1
      fi

      ${if escalate then ''
        if [ ! -e "$STATE/escalated" ]; then
          echo "FAIL: ${name} must escalate -- tailnet-datapath-dead was never started" >&2
          exit 1
        fi
      '' else ''
        if [ -e "$STATE/escalated" ]; then
          echo "FAIL: ${name} must NOT escalate -- this verdict may only fail the unit," \
               "and escalating it takes the role's PID 1 down" >&2
          exit 1
        fi
      ''}

      ${lib.concatMapStringsSep "\n" (s: ''
        if ! grep -qF -- ${lib.escapeShellArg s} err.log; then
          echo "FAIL: ${name} must say why -- missing from stderr: "${lib.escapeShellArg s} >&2
          exit 1
        fi
      '') stderr}

      ${lib.optionalString (attempts != null) ''
        got=$(cat "$STATE/attempt")
        if [ "$got" != ${toString attempts} ]; then
          echo "FAIL: ${name} reached attempt $got, expected ${toString attempts}" >&2
          exit 1
        fi
      ''}

      echo "PASS: ${name}" > $out
    '';

  ten = mode: lib.genList (_: mode) 10;
in
lib.listToAttrs (map (s: lib.nameValuePair "tailnet-liveness-probe-${s.name}" (scenario s)) [
  # --- healthy ---------------------------------------------------------------

  {
    name = "all-peers-answer-passes";
    plan = ten "ok";
    exit = 0;
    escalate = false;
    attempts = 1; # first attempt succeeded, so the run never slept
  }

  # The hysteresis is what it is for: a silent round trip that comes back
  # inside the window is not a dead datapath. Nine failures then an answer is
  # still a pass, and that is the whole difference between this and a probe
  # that reboots a builder over a DERP failover.
  {
    name = "recovers-on-the-last-attempt";
    plan = (lib.genList (_: "none") 9) ++ [ "ok" ];
    exit = 0;
    escalate = false;
    attempts = 10;
  }

  # Consecutive, not cumulative: the run ENDS at the first success, so the two
  # failures before it are not carried anywhere.
  {
    name = "stops-at-the-first-success";
    plan = [ "none" "none" "ok" ] ++ (lib.genList (_: "unread") 7);
    exit = 0;
    escalate = false;
    attempts = 3;
  }

  # --- the one verdict that may take the role down ---------------------------

  {
    name = "nobody-answers-escalates";
    plan = ten "none";
    exit = 1;
    escalate = true;
    stderr = [ "this node is off the tailnet" "peer peer0 (100.64.0.2) did not answer" ];
    attempts = 10;
  }

  # A peer that is not in the netmap at all, with the backend Running, is the
  # same fact: this node's view of the tailnet has nothing in it.
  {
    name = "peers-absent-from-the-netmap-escalates";
    plan = ten "absent";
    exit = 1;
    escalate = true;
    stderr = [ "peer peer0 is absent from this node's netmap" "this node is off the tailnet" ];
  }

  # --- verdicts that must stop at a failed unit ------------------------------

  # peer0 answers, peer1 does not. This node is demonstrably ON the tailnet, so
  # restarting it cannot fix someone else's outage -- and with the seed listed
  # first, this is the shape a seed outage takes on a builder that also names a
  # second peer.
  {
    name = "partial-peer-outage-does-not-escalate";
    plan = ten "some";
    exit = 1;
    escalate = false;
    stderr = [ "on the tailnet, but a named peer stayed unreachable" ];
  }

  # A restart repairs none of these, and on a fresh /var/lib/tailscale it
  # destroys the hand-run `tailscale up` that is the only way back.
  {
    name = "needs-login-does-not-escalate";
    plan = ten "login";
    exit = 1;
    escalate = false;
    stderr = [ "BackendState=NeedsLogin" "a restart repairs none of the states" ];
  }

  {
    name = "backend-stopped-does-not-escalate";
    plan = ten "stopped";
    exit = 1;
    escalate = false;
    stderr = [ "BackendState=Stopped" ];
  }

  # An unreadable status is never a pass -- a guard that passes because it could
  # not run is the failure it exists to catch -- but it is not a dead datapath
  # either, and inside a builder it is what an OOM-killed CLI looks like.
  {
    name = "unreadable-status-does-not-escalate";
    plan = ten "unread";
    exit = 1;
    escalate = false;
    stderr = [ "could not read tailscaled's status" ];
  }

  {
    name = "unparseable-status-does-not-escalate";
    plan = ten "garbage";
    exit = 1;
    escalate = false;
    stderr = [ "could not read tailscaled's status" ];
  }

  # --- mixed runs: one contrary attempt disarms the whole run ----------------

  # The case the design was corrected for. Nine attempts agreeing that nothing
  # answered are NOT enough if the tenth could not run: under cgroup pressure
  # the failures are correlated, so "the probe kept failing" is exactly what a
  # fork-bombing CI recipe produces, and escalating it would hand repository-
  # supplied shell a reboot primitive over its own role.
  {
    name = "one-could-not-run-attempt-disarms-the-run";
    plan = [ "unread" ] ++ (lib.genList (_: "none") 9);
    exit = 1;
    escalate = false;
    stderr = [ "could not read tailscaled's status" ];
    attempts = 10;
  }

  # Same rule, contrary attempt last rather than first.
  {
    name = "a-late-could-not-run-attempt-disarms-the-run";
    plan = (lib.genList (_: "none") 9) ++ [ "unread" ];
    exit = 1;
    escalate = false;
    stderr = [ "could not read tailscaled's status" ];
  }

  {
    name = "one-partial-attempt-disarms-the-run";
    plan = [ "none" "some" ] ++ (lib.genList (_: "none") 8);
    exit = 1;
    escalate = false;
    stderr = [ "on the tailnet, but a named peer stayed unreachable" ];
  }

  {
    name = "one-not-running-attempt-disarms-the-run";
    plan = (lib.genList (_: "none") 5) ++ [ "login" ] ++ (lib.genList (_: "none") 4);
    exit = 1;
    escalate = false;
    stderr = [ "a restart repairs none of the states" ];
  }

  # --- the re-read taken before escalating -----------------------------------

  # Every attempt found nobody answering, but the confirming read at the end of
  # each one says the backend is no longer Running. That is not a dead datapath.
  {
    name = "re-read-finding-a-stopped-backend-disarms-the-run";
    plan = ten "flip";
    exit = 1;
    escalate = false;
    stderr = [ "a restart repairs none of the states" ];
  }

  # And if the confirming read cannot run at all, the probe has proved nothing
  # about the tailnet -- only that it is itself under pressure.
  {
    name = "re-read-that-cannot-run-disarms-the-run";
    plan = ten "flipdead";
    exit = 1;
    escalate = false;
    stderr = [ "could not read tailscaled's status" ];
  }
])
