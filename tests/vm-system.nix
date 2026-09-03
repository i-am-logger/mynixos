# Booting VM test for mynixos (the first REAL runtime test).
#
# Unlike the other tests/*.nix files — which are EVAL-ONLY (they call
# lib.nixosSystem and read config attrs at Nix-eval time) — this one builds and
# BOOTS a real qemu VM via pkgs.testers.runNixOSTest, then asserts RUNTIME
# behavior with a python testScript. Its unique value over the eval tests is the
# things eval cannot see: that an active user is actually created, that the
# activeUsers filter actually excludes partial users, that home-manager actually
# activates, that feature-derived group membership actually lands, that the
# user's login shell is actually mapped, and that the mkApp pipeline actually
# puts app binaries in the user's profile.
#
# It is HEAVY (boots a VM, needs /dev/kvm), so it is exposed under the `tests`
# flake output (NOT `checks`, to keep `nix flake check` light/KVM-free) and run
# on demand: `nix build .#tests.<sys>.vm-system -L`.
#
# Deliberately scoped to a terminal+dev user (NOT graphical/ai): graphical pulls
# Hyprland + a display manager and ai pulls ROCm/CUDA closures (multi-GB, slow,
# display-dependent), while config-level feature-derivation is already covered by
# the eval smoke tests. We also disable the heaviest terminal-default apps
# (btop builds CUDA-enabled, cava builds Rust) to keep the
# closure lean and the boot fast.
{ self, inputs, system, nixpkgs, ... }:

let
  # Host pkgs for the test driver. allowUnfree is required: mynixos pulls unfree
  # closures; legacyPackages has allowUnfree = false.
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
pkgs.testers.runNixOSTest {
  name = "mynixos-vm-system";

  # specialArgs delivered to every node during `imports` resolution. MUST mirror
  # lib/mkSystem.nix (NOT the leaner tests/lib.nix set): vogix and hypr-vogix are
  # destructured unconditionally at the head of always-imported mynixos modules
  # (my/theming/vogix, my/graphical/hyprland, my/theming/hypr-vogix), and `pkgs`
  # is forced by mkApp's `home = { pkgs, ... }:` lambdas. activeUsers is NOT
  # passed here — nixosModules.default delivers it via _module.args.
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
      # Node baseModules are the STANDARD nixpkgs list, not mynixos's, so the
      # mynixos module tree + home-manager + sops-nix are added explicitly.
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    # Do NOT set nixpkgs.hostPlatform / nixpkgs.pkgs: runNixOSTest pins node.pkgs
    # and makes nixpkgs.* read-only and provided.
    boot.loader.grub.enable = false;
    system.stateVersion = "24.11";

    # Both the test framework (mkDefault "machine") and mynixos (mkDefault from
    # my.system.hostname) define networking.hostName; force ours to break the tie.
    networking.hostName = lib.mkForce "vmtest";

    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };

    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [{ home.stateVersion = "24.11"; }];
    };

    my = {
      # Enables the core system module (os-release branding, etc.).
      system.enable = true;
      # my/system/kernel sets networking.hostName from this (throws if null).
      system.hostname = "vmtest";

      # Theming (vogix) is out of scope here: the vogix NixOS module references
      # pkgs.vogix, which needs the vogix overlay — but runNixOSTest pins node.pkgs
      # read-only so the module's nixpkgs.overlays is ignored. A theming VM test
      # would need to build node pkgs WITH the overlay instead of pinning it.
      theming.enable = false;

      users = {
        # Active user: fullName => created as a real NixOS user (activeUsers).
        alice = {
          fullName = "Alice Example";
          description = "Alice Example";
          email = "alice@example.com";
          shell = "fish"; # exercises the shell -> login-shell mapping
          dev.enable = true; # => disk/dialout groups + rootless podman subids
          terminal.enable = true; # mkApp pipeline => bat/lsd/... installed via HM
          # Trim the heaviest terminal defaults to keep the VM closure lean:
          apps.terminal = {
            sysinfo.btop.enable = false; # default build pulls CUDA (unfree, huge)
            visualizers.cava.enable = false;
          };
        };

        # Second ACTIVE user WITHOUT dev — proves the dev base groups
        # (disk/dialout) are derived for ALL active users once any user turns
        # dev on. Nothing about the subid ranges is per-user: mynixos writes no
        # users.users entry for them, it only asserts at eval time, so the
        # ranges come from nixpkgs' own default for every normal account. The
        # per-user scoping of that ASSERTION is covered in tests/module-eval.nix
        # (containers-subid-guard-scoped), which eval can see and a VM cannot.
        carol = {
          fullName = "Carol Example";
          description = "Carol Example";
          email = "carol@example.com";
        };

        # Partial user: no fullName => must NOT be created (activeUsers filter).
        bob.email = "bob@example.com";
      };
    };

    # Register alice with home-manager (the app modules merge their per-user
    # config into this).
    home-manager.users.alice = { };
  };

  testScript = ''
    machine.start()
    # multi-user.target is the "fully booted" gate and guarantees home-manager
    # activation ran (home-manager-<user>.service is WantedBy=multi-user.target).
    machine.wait_for_unit("multi-user.target")

    with subtest("active user alice was created (fullName => activeUsers)"):
        machine.succeed("id alice")
        machine.wait_for_unit("home-manager-alice.service")

    with subtest("partial user bob (no fullName) was NOT created"):
        machine.fail("id bob")

    with subtest("second active user carol was created"):
        machine.succeed("id carol")

    with subtest("base groups: alice in own group + wheel + networkmanager"):
        groups = machine.succeed("id -nG alice").split()
        for g in ["alice", "wheel", "networkmanager"]:
            assert g in groups, f"alice missing base group '{g}' (got: {groups})"

    with subtest("containers: podman is the backend and no CONTAINER group is handed out"):
        # dockerCompat gives `docker` as an alias for podman, so the name still
        # works -- what must be gone is the GROUP, whose members could bind-mount
        # / into a container and come back as root. (This says nothing about the
        # other groups mynixos grants; `disk` is handed out separately.)
        machine.succeed("podman --version")
        machine.fail("getent group docker")
        for u in ["alice", "carol"]:
            g = machine.succeed(f"id -nG {u}").split()
            assert "docker" not in g and "podman" not in g, f"{u} must not be in a container group (got: {g})"

    with subtest("rootless podman: the container user has subuid/subgid ranges"):
        # Without these, `podman run` fails at RUNTIME with an opaque uid-mapping
        # error. nixpkgs turns autoSubUidGidRange on for every normal user, so
        # this is not per-user -- what it proves is that mynixos did not turn it
        # OFF, which is the failure the module asserts against at eval time.
        machine.succeed("grep -q '^alice:' /etc/subuid")
        machine.succeed("grep -q '^alice:' /etc/subgid")

    with subtest("containers: a container runs and aardvark-dns resolves a container name"):
        # The only runtime proof of my.dev.containers' dns_enabled: `webserver`
        # is a container NAME, and it resolves only because aardvark-dns is
        # serving the default network (and the firewall lets UDP 53 through on
        # podman0). An empty scratch image with the host store bind-mounted runs
        # host binaries, so nothing has to be fetched or built for this.
        machine.succeed("tar cv --files-from /dev/null | podman import - scratchimg")
        machine.succeed(
            "podman run -d --name=webserver"
            " -v /nix/store:/nix/store -v /run/current-system/sw/bin:/bin"
            " -w ${pkgs.writeTextDir "index.html" "<h1>mynixos</h1>"}"
            " scratchimg ${pkgs.python3}/bin/python -m http.server 8000"
        )
        machine.succeed("podman ps | grep -q webserver")
        machine.wait_until_succeeds(
            "podman run --rm --name=client"
            " -v /nix/store:/nix/store -v /run/current-system/sw/bin:/bin"
            " scratchimg ${pkgs.curl}/bin/curl -s http://webserver:8000 | grep -q mynixos"
        )

    with subtest("NetworkManager does not manage podman's bridge"):
        # Left managed, NM autoconnects and runs DHCP on podman0 and can take it
        # down under a running container -- which would break both the run above
        # and its name resolution. The unmanaged-devices keyfile written by
        # my/system/core is what prevents it. Checked HERE, while the webserver
        # container is still up: netavark removes the bridge again once the last
        # container leaves the network.
        machine.wait_for_unit("NetworkManager.service")
        machine.succeed("nmcli -t -f DEVICE,STATE device | grep -q '^podman0:unmanaged'")

    with subtest("dev base groups (disk/dialout) apply to ALL active users when my.dev.enable"):
        for u in ["alice", "carol"]:
            g = machine.succeed(f"id -nG {u}").split()
            assert "disk" in g and "dialout" in g, f"{u} missing disk/dialout (got: {g})"

    with subtest("login shell mapped from my.users.alice.shell = fish"):
        machine.succeed("getent passwd alice | grep -q '/fish$'")

    with subtest("mkApp pipeline: terminal app binaries in alice's HM profile"):
        for b in ["bat", "lsd"]:
            machine.succeed(f"test -x /etc/profiles/per-user/alice/bin/{b}")

    with subtest("disabled app: btop was NOT installed for alice"):
        machine.succeed("test ! -e /etc/profiles/per-user/alice/bin/btop")

    with subtest("mynixos os-release branding (my.system.enable)"):
        machine.succeed("grep -q '^VERSION_CODENAME=bootstrapper$' /etc/os-release")
  '';
}
