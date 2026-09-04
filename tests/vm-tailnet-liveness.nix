# The liveness escalation, end to end, on a real tailnet and a real container.
#
# tests/tailnet-liveness-probe.nix proves the probe reaches the right VERDICT;
# tests/tailnet-liveness.nix proves the units are SHAPED to act on it. Neither
# can reach the thing the whole design rests on, which is that the verdict
# actually leaves the guest:
#
#   tailnet-datapath-dead fails
#     -> FailureAction=exit / FailureActionExitStatus=69 in [Unit]
#     -> guest PID 1 exits 69
#     -> conmon returns it
#     -> the host's Type=notify unit records ExecMainStatus=69, Result=exit-code
#     -> nixpkgs' Restart=on-failure brings the role back
#
# Every link there is a runtime fact. The one this test exists for most is the
# section: `FailureAction=` in [Service] is still reported by `systemctl show`
# and simply never fires, which is the same silent non-failure the probe was
# written to remove.
#
# It also carries the one assertion no fixture can make. A fake `tailscale` and
# the probe's parser drift together, so a renamed field in
# `tailscale status --json` would pass every scenario in the probe suite and
# fail in production exactly like the bug being fixed. Here the netmap is real,
# produced by a real tailscaled that really joined a control plane, and the
# fields the probe reads are asserted against it.
#
# THE NEGATIVE HALF IS THE POINT. A probe that only ever proves it fires is
# half a test: it says nothing about whether it fires on a peer outage, on a
# node that was never logged in, or on a blip that clears inside the
# hysteresis -- and every one of those, escalated, is a role rebooting itself
# over something a reboot cannot fix. So this asserts NRestarts stays put
# across a datapath outage that clears at half the threshold, and across a
# backend that is not Running at all.
#
# The tailnet is hermetic: my.network.headscale ships a DERP map with no public
# relays, and the two machines sit on the test driver's isolated LAN, so
# "private network" is true by construction rather than by configuration.
#
# Heavy (boots 2 VMs, streams a role image, needs /dev/kvm) => `tests` output:
#   nix build .#tests.<sys>.vm-tailnet-liveness -L
{ self, inputs, system, nixpkgs, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  roleName = "liveness-role";
  roleUser = "${roleName}-user";
  stateDir = "/var/lib/machines/${roleName}";
  loginServer = "http://control:8080";

  # Scaled down from the production 10 x 60s, which would put ten minutes
  # between a silent tailnet and a container exit. The arithmetic itself is
  # covered attempt-by-attempt in tests/tailnet-liveness-probe.nix against the
  # real defaults, so what is left to prove here is the chain, and the chain
  # does not care how long the hysteresis is.
  retries = 6;
  retryDelay = 5;

  # The role. A machine that exists to be on the tailnet and nothing else --
  # `my.infra.radicle` would only add closure to stream.
  roleSystem = self.lib.mkSystem {
    inherit system;
    hostname = roleName;
    my = {
      # No `my.system.enable`: a role is not a workstation, and the opinionated
      # host defaults it turns on include an initrd, which a container has no
      # boot to run one in.
      system.hostname = roleName;
      theming.enable = false;
      network.tailscale = {
        enable = true;
        controlPlane = "headscale-remote";
        inherit loginServer;
        # No authKeyFile: these roles register interactively on the real fleet
        # too, so the test joins them the way an operator does. That also makes
        # the first subtest below meaningful -- an unregistered role must not
        # reboot-loop while it waits to be logged in.
        liveness = {
          peers = [ "control" ];
          startDelay = "20s";
          interval = "15s";
          inherit retries retryDelay;
        };
      };
    };
  };
in
pkgs.testers.runNixOSTest {
  name = "mynixos-vm-tailnet-liveness";

  node.specialArgs = {
    inherit inputs self pkgs;
    inherit (inputs)
      disko
      impermanence
      vogix
      hypr-vogix
      lanzaboote
      sops-nix
      ;
  };

  nodes = {
    # The control plane, and the peer the role round-trips against. One machine
    # for both because the probe never asks which node answered -- only that
    # something on the tailnet did.
    control = { lib, ... }: {
      imports = [
        self.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
      ];

      boot.loader.grub.enable = false;
      system.stateVersion = "24.11";
      networking.hostName = lib.mkForce "control";
      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };
      networking.firewall.allowedTCPPorts = [ 8080 ];

      home-manager.sharedModules = [{ home.stateVersion = "24.11"; }];

      my = {
        system.enable = true;
        system.hostname = "control";
        theming.enable = false;
        network.headscale = {
          enable = true;
          address = "0.0.0.0";
          port = 8080;
          serverUrl = loginServer;
          users = [ "test" ];
          # Without a rule the generated policy denies everything. Disco pings
          # are below the packet filter, so an empty policy would not actually
          # break this test -- which is the point of writing the permissive one
          # explicitly rather than relying on that.
          acl.rules = [{ action = "accept"; src = [ "*" ]; dst = [ "*:*" ]; }];
        };
        network.tailscale = {
          enable = true;
          controlPlane = "headscale-remote";
          inherit loginServer;
        };
      };

      environment.systemPackages = [ pkgs.jq ];
    };

    # The host that runs the role. It has no tailscale of its own: a role knows
    # nothing about the machine underneath it, and the machine underneath is not
    # allowed to be the thing that makes the role's probe pass.
    host = { lib, ... }: {
      imports = [
        self.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
      ];

      boot.loader.grub.enable = false;
      system.stateVersion = "24.11";
      networking.hostName = lib.mkForce "host";
      virtualisation = {
        memorySize = 4096;
        cores = 4;
        # The image is streamed into podman's store at first start.
        diskSize = 12288;
      };

      home-manager.sharedModules = [{ home.stateVersion = "24.11"; }];

      my = {
        system.enable = true;
        system.hostname = "host";
        theming.enable = false;
        virtualisation.containers = [{
          system = roleSystem;
          # /var/lib/tailscale outlives the container object, which
          # `Restart=on-failure` destroys and recreates on every cycle. Without
          # it a restart would drop the node's registration and the role would
          # come back needing a hand-run `tailscale up` -- so the restart this
          # test induces would never be observable as a recovery.
          stateVolumes.tailscale = "/var/lib/tailscale";
        }];
      };

      environment.systemPackages = [ pkgs.iptables pkgs.jq ];
    };
  };

  testScript = ''
    import json

    ROLE = "${roleName}"
    USER = "${roleUser}"
    UNIT = f"podman-{ROLE}.service"
    JOURNAL = "${stateDir}/journal"
    LOGIN = "${loginServer}"

    def podman_cmd(cmd):
        """podman, as the role's own account. One account per guest is the
        isolation rule, so there is no host-wide podman that reaches this."""
        return (
            f"runuser -u {USER} -- env XDG_RUNTIME_DIR=/run/user/$(id -u {USER})"
            f" HOME=/var/lib/{USER} podman {cmd}"
        )

    def guest_cmd(cmd):
        return podman_cmd(f"exec {ROLE} {cmd}")

    def podman(cmd, method="succeed"):
        return getattr(host, method)(podman_cmd(cmd))

    def guest(cmd, method="succeed"):
        return getattr(host, method)(guest_cmd(cmd))

    def restarts():
        return int(host.succeed(f"systemctl show -P NRestarts {UNIT}").strip())

    def probe_journal():
        """The guest's own account of the run, read from the host. The journal
        is a bind mount for exactly this: a role that has taken itself down
        cannot be asked what it concluded."""
        return host.execute(
            f"journalctl -D {JOURNAL} -u tailnet-liveness -u tailnet-datapath-dead"
            " --no-pager | tail -40"
        )[1]

    def exit69_lines():
        """How many times the host's service manager has recorded the guest
        exiting 69. Read from the JOURNAL rather than from `systemctl show`:
        `Result` and `ExecMainStatus` describe the unit's CURRENT invocation, so
        both are reset the moment `Restart=on-failure` brings the role back --
        and with RestartSec=30s that happens before any poll can see them."""
        return int(host.succeed(
            f"journalctl -u {UNIT} --no-pager"
            " | grep -c 'Main process exited, code=exited, status=69' || true"
        ).strip())

    def silent_peer_lines():
        """How many per-peer failures the probe has recorded. A `Result=success`
        proves nothing on its own -- an outage the probe never actually saw
        would produce exactly the same reading -- so the negative case counts
        these too."""
        return int(host.succeed(
            f"journalctl -D {JOURNAL} -u tailnet-liveness --no-pager"
            " | grep -c 'did not answer' || true"
        ).strip())

    def off_tailnet_verdicts():
        """How many times the probe has concluded the datapath is dead. The
        journal is a host bind mount, so it OUTLIVES the restarts this test
        induces -- grepping for the sentence alone would match the previous
        outage and prove nothing about the current one."""
        return int(host.succeed(
            f"journalctl -D {JOURNAL} -u tailnet-liveness --no-pager"
            " | grep -c 'this node is off the tailnet' || true"
        ).strip())

    def await_probe_finished(timeout=600):
        """A oneshot's SubState is `dead` when it succeeded and `failed` when it
        did not, so this waits for a VERDICT rather than for a good one."""
        host.wait_until_succeeds(
            guest_cmd("systemctl show -P SubState tailnet-liveness.service")
            + " | grep -qE '^(dead|failed)$'",
            timeout=timeout,
        )

    def authkey():
        uid = control.succeed(
            "headscale users list -o json | jq -r '.[] | select(.name == \"test\") | .id'"
        ).strip()
        out = control.succeed(
            f"headscale preauthkeys create --user {uid} --reusable --expiration 24h"
        )
        return [l.strip() for l in out.splitlines() if l.strip()][-1]

    start_all()

    with subtest("control plane is up on an isolated LAN"):
        control.wait_for_unit("headscale.service")
        control.wait_for_open_port(8080)
        control.wait_for_unit("headscale-create-users.service")

    with subtest("control joins its own tailnet and becomes the peer"):
        control.succeed(
            f"tailscale up --login-server {LOGIN!r} --auth-key {authkey()}"
        )
        control.wait_until_succeeds(
            "tailscale status --json | jq -e '.BackendState == \"Running\"'", timeout=120
        )

    with subtest("the role's container comes up"):
        host.wait_for_unit(UNIT, timeout=900)
        host.wait_until_succeeds(f"test -d {JOURNAL}", timeout=300)
        # Not `systemctl is-system-running --wait`: a role is `degraded` for
        # reasons this test is not about, and the wait blocks on units that have
        # nothing to do with the tailnet. What has to be true is that the daemon
        # the probe reads is up.
        host.wait_until_succeeds(
            guest_cmd("systemctl is-active tailscaled.service") + " | grep -qx active",
            timeout=600,
        )

    # The correctness finding this design was corrected for. A role on a fresh
    # /var/lib/tailscale has no registration, and that CANNOT be repaired by
    # restarting it -- the repair is a hand-run `tailscale up`, which a reboot
    # every few minutes would race and lose. So NeedsLogin must fail the unit
    # and stop there.
    with subtest("an unregistered role fails the probe and does NOT reboot itself"):
        host.wait_until_succeeds(
            f"journalctl -D {JOURNAL} -u tailnet-liveness --no-pager"
            " | grep -q 'BackendState=NeedsLogin'",
            timeout=180,
        )
        host.fail(
            f"journalctl -D {JOURNAL} -u tailnet-datapath-dead --no-pager | grep -q datapath"
        )
        assert restarts() == 0, "a role that was never logged in restarted itself"

    # The gate, taken against the rendered unit rather than against the module
    # that generated it: in [Service] these keys are still reported and simply
    # never fire.
    with subtest("the escalation is armed in [Unit], on the escalation unit only"):
        rendered = guest("systemctl cat tailnet-datapath-dead.service")
        unit_section = rendered.split("[Unit]", 1)[1].split("[Service]", 1)[0]
        assert "FailureAction=exit" in unit_section, rendered
        assert "FailureActionExitStatus=69" in unit_section, rendered
        assert "FailureAction" not in guest("systemctl cat tailnet-liveness.service")
        assert guest(
            "systemctl show -P FailureActionExitStatus tailnet-datapath-dead.service"
        ).strip() == "69"

    with subtest("the role joins the tailnet and the probe goes green"):
        guest(f"tailscale up --login-server {LOGIN!r} --auth-key {authkey()}")
        host.wait_until_succeeds(
            guest_cmd("tailscale status --json")
            + " | jq -e '.BackendState == \"Running\"'",
            timeout=180,
        )
        # From here the runs are driven by hand. The timer path is already
        # exercised above -- the NeedsLogin verdict came from a run nothing
        # asked for -- and leaving it armed would put unattended runs in the
        # middle of the induced outages below, where a run that started before
        # an outage and ended after it would make the negative case say nothing.
        guest("systemctl stop tailnet-liveness.timer")
        guest("systemctl start tailnet-liveness.service")
        assert restarts() == 0

    # The one assertion a fixture cannot make. Everything the probe's jq reads
    # is read here out of a netmap a real tailscaled really built, so an
    # upstream field rename fails HERE instead of in production.
    with subtest("the live status document still has the fields the probe reads"):
        status = json.loads(guest("tailscale status --json"))
        assert status["BackendState"] == "Running", status["BackendState"]
        assert "Health" in status
        assert "Online" in status["Self"] and "DNSName" in status["Self"]
        peers = list(status["Peer"].values())
        assert peers, "the role's netmap has no peers, so nothing below is being tested"
        match = [
            p for p in peers
            if p.get("HostName") == "control" or (p.get("DNSName") or "").startswith("control.")
        ]
        assert match, f"no peer resolvable as 'control': {[p.get('DNSName') for p in peers]}"
        assert match[0]["TailscaleIPs"], "the peer carries no TailscaleIPs to ping"
        # The probe resolves DNSName BEFORE HostName because HostName is not
        # unique on a real tailnet. Both must therefore still exist.
        assert "HostName" in match[0] and "DNSName" in match[0]

    # The guest reaches the LAN through the host's own network namespace, so
    # this is the host-side equivalent of the network helper dying: every path
    # off the tailnet is gone while tailscaled itself is untouched.
    #
    # BOTH ADDRESS FAMILIES, and the interface rather than the peer's address.
    # The test LAN is dual-stacked and this tailnet's underlay picked IPv6, so
    # an IPv4-only rule left the round trip working and the probe (correctly)
    # green -- an outage that is not an outage, which would have made every
    # assertion below meaningless. The driver talks to these machines over a
    # serial backdoor, not the LAN, so cutting eth1 costs nothing here.
    def cut_datapath():
        host.succeed("iptables -I OUTPUT -o eth1 -j DROP")
        host.succeed("ip6tables -I OUTPUT -o eth1 -j DROP")

    def restore_datapath():
        host.succeed("iptables -D OUTPUT -o eth1 -j DROP")
        host.succeed("ip6tables -D OUTPUT -o eth1 -j DROP")

    # HALF THE THRESHOLD. An outage that clears inside the hysteresis must cost
    # nothing: this is the DERP failover, the relay reselection and the host
    # uplink still coming up after a reboot, and rebooting a builder over any of
    # them would lose every CI job it had in flight.
    with subtest("an outage that clears inside the hysteresis does not restart the role"):
        before = restarts()
        silent = silent_peer_lines()
        guest("systemctl reset-failed tailnet-liveness.service", "execute")
        cut_datapath()
        guest("systemctl --no-block start tailnet-liveness.service")
        # Roughly half of retries x retryDelay, so the run is under way and has
        # already seen the peer go silent at least once.
        host.sleep(${toString (retries * retryDelay / 2)})
        restore_datapath()
        await_probe_finished()
        result = guest("systemctl show -P Result tailnet-liveness.service").strip()
        assert result == "success", (
            "the probe must recover when the round trip comes back inside the "
            f"hysteresis, got Result={result}\n{probe_journal()}"
        )
        # Without this the subtest passes just as happily when the outage never
        # reached the probe at all, which would make "it did not escalate" mean
        # nothing.
        assert silent_peer_lines() > silent, (
            "the induced outage never reached the probe -- a run that saw no "
            f"silent peer proves nothing about the hysteresis\n{probe_journal()}"
        )
        assert restarts() == before, f"a transient outage restarted the role\n{probe_journal()}"

    # THE CHAIN, one link at a time, because a single "did it restart?" cannot
    # say WHICH link broke -- and the two halves fail for completely different
    # reasons. First half: the escalation unit really does take PID 1 down and
    # the status really does reach the host's service manager. Started by hand,
    # with no outage at all, so nothing about the tailnet is in the way.
    with subtest("the escalation unit takes guest PID 1 down and the host records 69"):
        before = restarts()
        seen69 = exit69_lines()
        guest("systemctl --no-block start tailnet-datapath-dead.service")
        try:
            # 69 is EX_UNAVAILABLE, and every digit of it is load-bearing: 0
            # would be read as success and leave the container parked, 125-127
            # are podman's, 137/143 are signals. This is the whole reason the
            # exit status is chosen rather than left to systemd.
            host.wait_until_succeeds(
                f"test $(journalctl -u {UNIT} --no-pager"
                " | grep -c 'Main process exited, code=exited, status=69'"
                f" || true) -gt {seen69}",
                timeout=300,
            )
            host.wait_until_succeeds(
                f"journalctl -u {UNIT} --no-pager | grep -q \"Failed with result 'exit-code'\"",
                timeout=60,
            )
            host.wait_until_succeeds(
                f"test $(systemctl show -P NRestarts {UNIT}) -gt {before}", timeout=300
            )
        except Exception:
            print("=== host unit ===")
            print(host.execute(f"systemctl status {UNIT} --no-pager -l | tail -30")[1])
            print("=== guest journal ===")
            print(probe_journal())
            raise

        host.wait_for_unit(UNIT, timeout=600)
        host.wait_until_succeeds(
            guest_cmd("systemctl is-active tailscaled.service") + " | grep -qx active",
            timeout=600,
        )
        host.wait_until_succeeds(
            guest_cmd("tailscale status --json")
            + " | jq -e '.BackendState == \"Running\"'",
            timeout=600,
        )
        guest("systemctl stop tailnet-liveness.timer", "execute")

    # Second half: a dead datapath is what makes the probe reach for that unit.
    # Nothing on the tailnet answers while tailscaled is alive and Running --
    # exactly the shape that left a role `active (running)` with NRestarts=0 for
    # three hours.
    with subtest("a datapath that stays dead reaches that verdict and restarts the role"):
        cut_datapath()

        # The characterisation, taken from inside before anything escalates.
        assert guest("systemctl is-active tailscaled.service").strip() == "active"
        assert json.loads(guest("tailscale status --json"))["BackendState"] == "Running"

        before = restarts()
        seen = off_tailnet_verdicts()
        seen69 = exit69_lines()
        guest("systemctl --no-block start tailnet-liveness.service")

        try:
            host.wait_until_succeeds(
                f"test $(journalctl -D {JOURNAL} -u tailnet-liveness --no-pager"
                f" | grep -c 'this node is off the tailnet' || true) -gt {seen}",
                timeout=600,
            )
            host.wait_until_succeeds(
                f"test $(journalctl -u {UNIT} --no-pager"
                " | grep -c 'Main process exited, code=exited, status=69'"
                f" || true) -gt {seen69}",
                timeout=300,
            )
            host.wait_until_succeeds(
                f"test $(systemctl show -P NRestarts {UNIT}) -gt {before}", timeout=600
            )
        except Exception:
            print("=== probe journal ===")
            print(probe_journal())
            print("=== host unit ===")
            print(host.execute(f"systemctl status {UNIT} --no-pager -l | tail -30")[1])
            raise

    with subtest("the role self-heals once the tailnet comes back"):
        restore_datapath()
        host.wait_for_unit(UNIT, timeout=600)
        host.wait_until_succeeds(
            guest_cmd("tailscale status --json")
            + " | jq -e '.BackendState == \"Running\"'",
            timeout=600,
        )
        guest("systemctl stop tailnet-liveness.timer", "execute")
        guest("systemctl start tailnet-liveness.service")
        settled = restarts()
        # The pacing is what keeps this shape self-healing: at 30s apart inside
        # a 300s window a liveness-driven cycle never reaches the burst of 5, so
        # the unit must never have latched. Read from the journal because
        # `Result` is reset by the very restart that would have to have
        # happened -- the latch would only ever be visible as this line.
        host.fail(
            f"journalctl -u {UNIT} --no-pager | grep -q 'Start request repeated too quickly'"
        )
        host.sleep(60)
        assert restarts() == settled, "the role kept restarting after the tailnet returned"

    # THE OBSERVED FAILURE ITSELF, reproduced rather than described.
    #
    # pasta is podman's rootless network helper and it is the guest's ONLY path
    # to the network. It took SIGSEGV on the real host (audit ANOM_ABEND sig=11,
    # inside udp_sock_errs); podman neither restarts it nor notices, conmon
    # never exits because guest PID 1 never does, and so the host unit read
    # `active (running)` with NRestarts=0 for three hours with `systemctl
    # --failed` empty on both sides. This asserts that silence still happens --
    # nothing else catches it -- and that the probe is what ends it.
    with subtest("a dead network helper is caught and healed"):
        # Every one of them, not the first: the role has restarted several times
        # by now and a helper left behind by an earlier container generation
        # would otherwise absorb the signal while the live one carried on. It
        # also makes the assertion below exact -- afterwards there must be NO
        # network helper at all.
        helpers = host.succeed(
            f"pgrep -u {USER} -f 'libexec/podman/pasta'"
        ).split()
        before = restarts()
        seen = off_tailnet_verdicts()
        seen69 = exit69_lines()
        # SIGKILL, even though the audit record on the real host was sig=11: a
        # SIGSEGV delivered with kill(2) does NOT terminate pasta here (measured
        # -- the process is still alive a minute later), and what the probe is
        # being tested against is a guest with no network helper, not the signal
        # that removed it.
        host.succeed("kill -KILL " + " ".join(helpers))
        # Wait for THOSE pids to be gone rather than for a moment with no helper
        # at all: the two differ if anything respawns one, and only the first is
        # actually what was asked for.
        try:
            host.wait_until_fails("kill -0 " + " ".join(helpers), timeout=60)
        except Exception:
            print("=== helpers ===")
            print(host.execute(f"ps -o pid,ppid,stat,args -u {USER}")[1])
            raise

        # The silence: the guest has no network at all and every layer above it
        # still reports health.
        host.succeed(f"systemctl is-active {UNIT}")
        assert restarts() == before, "the container exited on its own -- then the probe is not what is being tested"
        assert guest("systemctl is-active tailscaled.service").strip() == "active"

        # Driven by the TIMER, not by hand: the point is that nothing has to be
        # watching for this to be caught.
        guest("systemctl start tailnet-liveness.timer")
        try:
            host.wait_until_succeeds(
                f"test $(journalctl -D {JOURNAL} -u tailnet-liveness --no-pager"
                f" | grep -c 'this node is off the tailnet' || true) -gt {seen}",
                timeout=600,
            )
            host.wait_until_succeeds(
                f"test $(journalctl -u {UNIT} --no-pager"
                " | grep -c 'Main process exited, code=exited, status=69'"
                f" || true) -gt {seen69}",
                timeout=300,
            )
            host.wait_until_succeeds(
                f"test $(systemctl show -P NRestarts {UNIT}) -gt {before}", timeout=600
            )
        except Exception:
            print("=== probe journal ===")
            print(probe_journal())
            raise

        host.wait_for_unit(UNIT, timeout=600)
        healed = host.wait_until_succeeds(
            f"pgrep -u {USER} -f 'libexec/podman/pasta'", timeout=300
        ).split()
        assert healed and not set(healed) & set(helpers), (
            f"the restart did not bring up a fresh network helper: {healed} vs {helpers}"
        )
        host.wait_until_succeeds(
            guest_cmd("tailscale status --json")
            + " | jq -e '.BackendState == \"Running\"'",
            timeout=600,
        )
        guest("systemctl stop tailnet-liveness.timer", "execute")

    # The other half of the corrected predicate, live: a backend that is not
    # Running is not a dead datapath, and restarting a role destroys the only
    # repair those states have.
    with subtest("a backend that is not Running fails the unit and escalates nothing"):
        before = restarts()
        guest("tailscale down")
        guest("systemctl reset-failed tailnet-datapath-dead.service", "execute")
        marker = guest(
            "journalctl -u tailnet-datapath-dead --no-pager -o cat | wc -l"
        ).strip()
        guest("systemctl start tailnet-liveness.service", "fail")
        assert "a restart repairs none of the states" in guest(
            "journalctl -u tailnet-liveness --no-pager -o cat | tail -20"
        )
        assert guest(
            "journalctl -u tailnet-datapath-dead --no-pager -o cat | wc -l"
        ).strip() == marker, "a non-Running backend started the escalation unit"
        assert restarts() == before, "a logged-out role restarted itself"
  '';
}
