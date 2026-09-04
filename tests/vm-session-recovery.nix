# Booting VM test for Hyprland session recovery — that a systemd user manager
# replaced UNDER a live compositor gets its session back without anyone touching
# it.
#
# The failure this protects against, observed on yoga: user@1000.service exited
# while Hyprland kept running, and a later login re-created it. Hyprland exports
# WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE into the user manager from a
# `hyprland.start` hook that fires once per compositor process, and that same
# hook is the only thing that ever starts hyprland-session.target. So the new
# manager had neither: the graphical session stayed down for four hours, and when
# the target was finally raised by hand every Wayland user unit died — quickshell
# hardest, because with no display Qt's init_platform calls qFatal and aborts.
#
# WHY THERE IS NO COMPOSITOR HERE. The fault is an ENVIRONMENT fault, so it is
# fully observable without drawing a pixel: what matters is whether the manager
# regains WAYLAND_DISPLAY and whether the target re-raises itself. Both are text
# assertions. The heavier variant — a real headless Hyprland under qemu — is
# deliberately not attempted: as tests/vm-login.nix already records, "the SESSION
# behind a successful login is Hyprland, which the qemu node cannot reliably
# run".
#
# What stands in for the compositor is a FAKE INSTANCE rather than a fake
# hyprctl, which is what lets the real code path run end to end. `hyprctl
# instances -j` reports any instance directory under $XDG_RUNTIME_DIR/hypr whose
# hyprland.lock names a live pid (the lock carries "<pid>\n<wl socket>"), and
# `hyprctl version` is a real IPC round-trip against that instance's
# .socket.sock. Supplying both means the REAL hyprctl, the REAL JSON and the
# REAL jq expression are exercised — and, in the negative case, the REAL
# malformed no-instance output, instead of this test's idea of it.
#
# The fake runs as root in its own transient system unit, deliberately OUTSIDE
# the user manager's cgroup. That is not a convenience: it is the whole
# mechanism. Hyprland survived the manager's death on yoga for exactly that
# reason, and a fake living inside the user slice would be killed by the very
# restart this test performs.
#
# What this cannot prove, stated plainly: that quickshell itself comes up. It
# proves the environment quickshell needs is present and keeps being restored.
#
# HEAVY (boots a VM with the graphical closure; needs /dev/kvm), so it lives
# under the `tests` output: `nix build .#tests.<sys>.vm-session-recovery -L`.
{ self, inputs, system, nixpkgs, ... }:

let
  # Host pkgs for the test driver. allowUnfree mirrors tests/vm-system.nix.
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  # Serves just enough of Hyprland's IPC that `hyprctl version` answers and
  # exits 0, which is the liveness round-trip the session units use to decide a
  # signature is real. mode=0777 because the socket is created by root and
  # connected to by the test user.
  fakeCompositorIpc = pkgs.writeShellScript "fake-hyprland-ipc" ''
    exec ${pkgs.socat}/bin/socat \
      "UNIX-LISTEN:$1,fork,unlink-early,mode=0777" \
      SYSTEM:'echo "Hyprland 0.56.2"'
  '';
in
pkgs.testers.runNixOSTest {
  name = "mynixos-vm-session-recovery";

  # Mirrors tests/vm-system.nix: pkgs IS pinned here (theming is off, so no
  # vogix overlay has to reach the node) and the node must therefore NOT set
  # nixpkgs.hostPlatform.
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

  nodes.machine = { lib, ... }: {
    imports = [
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    boot.loader.grub.enable = false;
    system.stateVersion = "24.11";
    networking.hostName = lib.mkForce "vmsession";

    virtualisation = {
      memorySize = 4096;
      cores = 4;
    };

    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [{ home.stateVersion = "24.11"; }];
    };

    my = {
      system.enable = true;
      system.hostname = "vmsession";

      # Theming off keeps the vogix closure out: this test is about the session
      # units the Hyprland module emits, not about what the shell renders.
      theming = {
        enable = false;
        vogix.enable = false;
      };

      users.hypruser = {
        fullName = "Hypr User";
        description = "Hypr User";
        email = "hypr@example.com";
        graphical.enable = true;
        apps.graphical.windowManagers.hyprland.enable = true;
        # Lean where this test gains nothing (btop builds CUDA, cava builds Rust).
        apps.terminal = {
          sysinfo.btop.enable = false;
          visualizers.cava.enable = false;
        };
      };
    };

    # Lingering is what lets user@<uid> exist without a login — and, crucially,
    # what makes `systemctl restart user@<uid>` a faithful reproduction of the
    # yoga incident rather than an artificial teardown. yoga has had lingering on
    # since June and the manager died anyway.
    users.users.hypruser.linger = true;
  };

  testScript = ''
    SIG = "teststub_1_1"

    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("id hypruser")

    uid = machine.succeed("id -u hypruser").strip()
    instance_dir = f"/run/user/{uid}/hypr/{SIG}"

    def as_user(cmd):
        # The test driver is root; these have to reach hypruser's OWN manager.
        return (
            f"runuser -u hypruser -- env XDG_RUNTIME_DIR=/run/user/{uid} "
            f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus {cmd}"
        )

    # Lingering brings this up with nobody logged in.
    machine.wait_for_unit(f"user@{uid}.service")

    with subtest("the session units and the target they act on all exist"):
        # Asserted first so a missing unit fails HERE, with an obvious message,
        # instead of surfacing as an unexplained timeout further down.
        machine.succeed(as_user("systemctl --user cat hyprland-session-env.service"))
        machine.succeed(as_user("systemctl --user cat hyprland-session-recover.service"))
        machine.succeed(as_user("systemctl --user cat hyprland-session.target"))

    with subtest("no compositor: hyprctl's malformed empty output is a no-op, not a failure"):
        # The premise, pinned rather than assumed: with no instance running
        # `hyprctl instances -j` exits 0 having printed "\n]\n\n" -- NOT "[]",
        # and not valid JSON. An earlier draft of the guard compared that text
        # to "[]", missed it, and let jq choke. If a future hyprland ever emits
        # a real empty array, this assertion says so instead of quietly passing.
        raw = machine.succeed(as_user("hyprctl instances -j"))
        assert raw.strip() == "]", f"hyprctl no-instance output changed: {raw!r}"

        # Both units must read that as nothing-to-do and exit 0. `systemctl
        # start` on a oneshot propagates a non-zero exit, so these succeed()
        # calls ARE the assertion that neither script failed.
        machine.succeed(as_user("systemctl --user start hyprland-session-env.service"))
        machine.succeed(as_user("systemctl --user start hyprland-session-recover.service"))

        # ...and neither invented a session out of nothing.
        machine.fail(as_user("systemctl --user show-environment") + " | grep -q '^WAYLAND_DISPLAY='")
        machine.fail(as_user("systemctl --user is-active hyprland-session.target"))

    with subtest("a fake compositor appears, outside the user manager's cgroup"):
        machine.succeed(f"mkdir -p {instance_dir}")
        machine.succeed(f"chmod 0755 /run/user/{uid}/hypr {instance_dir}")
        # A transient SYSTEM unit: root-owned, its own cgroup, so the user@
        # restart below cannot reap it -- the same reason Hyprland outlived the
        # manager on yoga.
        machine.succeed(
            f"systemd-run --unit=fake-hyprland --collect "
            f"${fakeCompositorIpc} {instance_dir}/.socket.sock"
        )
        machine.wait_for_unit("fake-hyprland.service")
        machine.wait_for_file(f"{instance_dir}/.socket.sock")

        # hyprland.lock is "<pid>\n<wl socket>", and hyprctl lists an instance
        # only while that pid is alive. socat is both the live pid and the IPC
        # server, so one process makes the instance real on both counts.
        pid = machine.succeed("systemctl show fake-hyprland.service -p MainPID --value").strip()
        machine.succeed(f"printf '%s\\nwayland-9\\n' {pid} > {instance_dir}/hyprland.lock")
        machine.succeed(f"chmod 0644 {instance_dir}/hyprland.lock")

        # The real hyprctl now sees it, and the liveness round-trip answers.
        machine.succeed(as_user("hyprctl instances -j") + " | grep -q '\"wl_socket\": \"wayland-9\"'")
        machine.succeed(as_user(f"env HYPRLAND_INSTANCE_SIGNATURE={SIG} hyprctl version"))

    with subtest("a user manager replaced under a live compositor recovers UNAIDED"):
        # This is the actual regression. Restarting user@<uid> is the ONLY action
        # taken: nothing below starts a unit or a target by hand, because on yoga
        # the four-hour outage was precisely that nothing re-raised it.
        machine.succeed(f"systemctl restart user@{uid}.service")
        machine.wait_for_unit(f"user@{uid}.service")

        # Precondition: the runtime dir (and so the fake instance) outlives the
        # manager restart. Checked explicitly so its loss reads as itself.
        machine.succeed(as_user("hyprctl instances -j") + " | grep -q '\"wl_socket\": \"wayland-9\"'")

        # The target raises itself...
        machine.wait_until_succeeds(
            as_user("systemctl --user is-active hyprland-session.target"), timeout=90
        )
        # ...and the environment comes back with it, taken from the live compositor.
        machine.wait_until_succeeds(
            as_user("systemctl --user show-environment")
            + " | grep -q '^WAYLAND_DISPLAY=wayland-9$'",
            timeout=90,
        )
        machine.succeed(
            as_user("systemctl --user show-environment")
            + f" | grep -q '^HYPRLAND_INSTANCE_SIGNATURE={SIG}$'"
        )

    with subtest("the import re-runs on a SECOND raise of the session"):
        # If hyprland-session-env ever gains RemainAfterExit it goes "active
        # (exited)" and is never run again -- reintroducing the once-only
        # behaviour the whole fix exists to remove, and it looks like an
        # optimisation in review. tests/module-eval.nix catches the directive;
        # this catches the behaviour it would cause.
        machine.succeed(as_user("systemctl --user stop hyprland-session.target"))
        machine.succeed(as_user("systemctl --user stop graphical-session.target"))
        machine.succeed(
            as_user("systemctl --user unset-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE")
        )
        machine.fail(as_user("systemctl --user show-environment") + " | grep -q '^WAYLAND_DISPLAY='")

        machine.succeed(as_user("systemctl --user start hyprland-session.target"))
        machine.wait_until_succeeds(
            as_user("systemctl --user show-environment")
            + " | grep -q '^WAYLAND_DISPLAY=wayland-9$'",
            timeout=60,
        )
  '';
}
