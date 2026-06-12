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
# (btop builds CUDA-enabled, bespec/cava build Rust, yazi is large) to keep the
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
      stylix
      vogix
      hypr-vogix
      lanzaboote
      sops-nix
      ;
    secrets = inputs.secrets or null;
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
          dev.enable = true; # feature-derivation => disk/dialout/docker groups
          terminal.enable = true; # mkApp pipeline => bat/lsd/... installed via HM
          # Trim the heaviest terminal defaults to keep the VM closure lean:
          apps.terminal = {
            sysinfo.btop.enable = false; # default build pulls CUDA (unfree, huge)
            visualizers.bespec.enable = false; # custom Rust build
            visualizers.cava.enable = false;
            fileManagers.yazi.enable = false;
          };
        };

        # Second ACTIVE user WITHOUT dev — proves dev group-derivation is
        # per-user for docker but all-active-users for disk/dialout.
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

    with subtest("dev derivation is PER-USER for docker (only the dev user)"):
        assert "docker" in machine.succeed("id -nG alice").split(), "alice (dev.enable) should be in docker"
        assert "docker" not in machine.succeed("id -nG carol").split(), "carol (no dev) must NOT be in docker"

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
