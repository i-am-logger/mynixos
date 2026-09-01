# mkSystem: the public entry point, and the pure helpers behind it.
#
# Everything here was untested. mkSystem decides which evaluator runs, which
# module set loads, how `my` layers merge, and -- through userTierLayers --
# whether a person's password hash, avatar, pointer acceleration and media apps
# reach a host at all. A mistake in it is silent: the option simply never gets
# set, and no host notices.
#
# Two kinds of check live here:
#
#   * PURE   -- the helpers in lib/mk-system-core.nix, exercised directly. These
#               are plain functions over attrsets; no evaluator needed.
#   * SYSTEM -- real mkSystem calls on both platforms, asserting the resulting
#               config. Only `config` is read, never a derivation, so the darwin
#               half runs on a Linux runner.

{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs;

  core = import ../lib/mk-system-core.nix { inherit inputs lib; };

  # A check that is a plain boolean assertion over pure values.
  pureCheck = name: cond: detail:
    pkgs.runCommand "mksystem-${name}" { }
      (if cond then ''
        echo "PASS: ${name}"
        touch $out
      '' else builtins.throw "FAIL: ${name} -- ${detail}");

  # Every user needs `name` and `homeManager`; NixOS additionally requires
  # `nixosUser`, which is asserted in mkSystem's linux branch. darwin does not --
  # macOS accounts come from my/users/users/darwin.nix, driven by `my.users`.
  mkUser = name: { inherit name; homeManager = { }; };
  mkNixosUser = name: (mkUser name) // {
    nixosUser = { users.users.${name} = { isNormalUser = true; group = "users"; }; };
  };

  linuxBase = {
    platform = "linux";
    hostname = "mks-linux";
    users = [ (mkNixosUser "alice") ];
  };

  darwinBase = {
    platform = "darwin";
    hostname = "mks-darwin";
    users = [ (mkUser "alice") ];
  };

  # Minimal modules each evaluator needs on top of what mkSystem supplies.
  linuxExtra = [{
    boot.loader.grub.devices = [ "nodev" ];
    fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; };
    system.stateVersion = "24.11";
    nixpkgs.hostPlatform = "x86_64-linux";
  }];

  darwinExtra = [{
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 7;
    system.primaryUser = "alice";
  }];

  # A user carrying both platform tiers plus shared data. `shell` is the live
  # example: it is a scalar, so if a tier ever leaked into the shared layer the
  # module system would report conflicting definitions rather than pick one.
  tieredUser = {
    alice = {
      fullName = "Alice";
      description = "test user";
      email = "alice@example.com";
      linux = { shell = "fish"; };
      darwin = { shell = "zsh"; };
    };
  };

  evalLinux = args: self.lib.mkSystem (linuxBase // args // {
    extraModules = linuxExtra ++ (args.extraModules or [ ]);
  });

  evalDarwin = args: self.lib.mkSystem (darwinBase // args // {
    extraModules = darwinExtra ++ (args.extraModules or [ ]);
  });

  # A role: no hardware, no users, and `system` instead of a hardware profile.
  # Nothing is added on top -- platforms/oci.nix supplies the stateVersion and
  # the docker-container profile relaxes the `fileSystems."/"` requirement, so
  # a role that needed an `extraModules` prelude here would be a role a
  # consumer could not write either.
  ociBase = {
    platform = "oci";
    hostname = "mks-oci";
    system = "x86_64-linux";
  };

  evalOci = args: self.lib.mkSystem (ociBase // args);

  # `tryEval` does NOT catch a missing attribute, but it does catch `throw`,
  # which is how mkSystem reports a rejected argument.
  throws = expr: !(builtins.tryEval (builtins.deepSeq expr "ok")).success;
in
{
  # --- Pure: layering -------------------------------------------------------

  # A bare attrset and a single-element list must behave identically.
  mksystem-layers-normalise = pureCheck "layers-normalise"
    (core.myLayers { a = 1; } == [{ a = 1; }] && core.myLayers [{ a = 1; }] == [{ a = 1; }])
    "myLayers should wrap a bare attrset and pass a list through";

  # myView is the read-only flatten. It must NOT be used to build config, and
  # this check documents why: it replaces lists rather than concatenating.
  mksystem-myview-replaces-lists = pureCheck "myview-replaces-lists"
    ((core.myView [{ xs = [ 1 ]; } { xs = [ 2 ]; }]).xs == [ 2 ])
    "myView is recursiveUpdate, so the later list wins -- that is why it is read-only";

  # Each layer becomes its own module, so the module system merges them.
  mksystem-layers-become-modules = pureCheck "layers-become-modules"
    (builtins.length (core.myModules "linux" [{ a = 1; } { b = 2; }]) == 2)
    "two layers should produce two modules";

  # --- Pure: platform tiers -------------------------------------------------

  mksystem-tier-linux-selected = pureCheck "tier-linux-selected"
    (
      let ls = core.userTierLayers "linux" tieredUser;
      in builtins.length ls == 2 && (builtins.elemAt ls 1).alice.shell == "fish"
    )
    "the linux tier should be emitted as its own layer on linux";

  mksystem-tier-darwin-selected = pureCheck "tier-darwin-selected"
    (
      let ls = core.userTierLayers "darwin" tieredUser;
      in builtins.length ls == 2 && (builtins.elemAt ls 1).alice.shell == "zsh"
    )
    "the darwin tier should be emitted as its own layer on darwin";

  # The reserved keys must never survive into the shared layer, or they would
  # reach the module system as unknown options.
  mksystem-tiers-stripped-from-shared = pureCheck "tiers-stripped-from-shared"
    (
      let shared = builtins.head (core.userTierLayers "linux" tieredUser);
      in !(shared.alice ? linux) && !(shared.alice ? darwin) && shared.alice.fullName == "Alice"
    )
    "shared layer must keep ordinary keys and drop both reserved tier keys";

  # A user with no tiers must not produce an empty second layer.
  mksystem-no-tier-no-extra-layer = pureCheck "no-tier-no-extra-layer"
    (builtins.length (core.userTierLayers "linux" { bob = { fullName = "Bob"; }; }) == 1)
    "a user without tiers should yield exactly one layer";

  # A misspelt tier is deliberately NOT stripped: it stays in the shared layer
  # so the module system rejects it, rather than being silently discarded.
  mksystem-misspelt-tier-not-stripped = pureCheck "misspelt-tier-not-stripped"
    (
      let shared = builtins.head (core.userTierLayers "linux" { bob = { macos = { shell = "zsh"; }; }; });
      in shared.bob ? macos
    )
    "an unknown tier name must survive to become an unknown-option error";

  # --- Pure: hostname resolution -------------------------------------------

  mksystem-hostname-parameter-wins = pureCheck "hostname-parameter-wins"
    (core.resolveHostname { hostname = "from-param"; my = { system.hostname = "from-my"; }; } == "from-param")
    "the hostname parameter should outrank my.system.hostname";

  mksystem-hostname-from-my = pureCheck "hostname-from-my"
    (core.resolveHostname { hostname = null; my = { system.hostname = "from-my"; }; } == "from-my")
    "my.system.hostname should be used when no parameter is given";

  mksystem-hostname-required = pureCheck "hostname-required"
    (throws (core.resolveHostname { hostname = null; my = { }; }))
    "naming no hostname at all should throw, not produce an empty name";

  # --- System: platform dispatch -------------------------------------------

  # networking.hostName alone proves nothing here: both evaluators declare it and
  # both mkSystem branches set it identically. These assert on options only ONE
  # evaluator declares, so a branch dispatching to the wrong one fails.
  mksystem-linux-builds-nixos =
    let e = evalLinux { }; in
    pureCheck "linux-builds-nixos"
      (e.config.networking.hostName == "mks-linux"
        && e.options ? systemd && e.options ? boot && !(e.options ? launchd))
      "platform = linux should produce a NixOS configuration (systemd/boot, no launchd)";

  mksystem-darwin-builds-darwin =
    let e = evalDarwin { }; in
    pureCheck "darwin-builds-darwin"
      (e.config.networking.hostName == "mks-darwin"
        && e.options ? launchd && e.options ? homebrew && !(e.options ? systemd))
      "platform = darwin should produce a nix-darwin configuration (launchd/homebrew, no systemd)";

  # my.filesystem is disko, which cannot describe APFS. Rejected with a reason
  # rather than accepted and ignored.
  mksystem-darwin-rejects-filesystem = pureCheck "darwin-rejects-filesystem"
    (throws (evalDarwin { my = { filesystem = { type = "disko"; }; }; }).config)
    "a darwin host naming my.filesystem should be told, not silently ignored";

  # `system` is the oci branch's alone: everywhere else the hardware profile
  # sets nixpkgs.hostPlatform, and two sources for one fact is how a host ends
  # up silently building for the wrong architecture.
  mksystem-linux-rejects-system = pureCheck "linux-rejects-system"
    (throws (evalLinux { system = "x86_64-linux"; }).config)
    "a NixOS host naming `system` should be told the hardware profile owns it";

  mksystem-darwin-rejects-system = pureCheck "darwin-rejects-system"
    (throws (evalDarwin { system = "aarch64-darwin"; }).config)
    "a darwin host naming `system` should be told the hardware profile owns it";

  # --- System: the oci role emitter ----------------------------------------

  # A role is a NixOS evaluation like any other machine -- that is the claim
  # `platform = "oci"` makes. What distinguishes it is `system.build.image`
  # beside the toplevel, and `boot.isContainer`: no kernel, no initrd, no
  # bootloader. Asserting the hostname alone would prove none of that.
  mksystem-oci-builds-role =
    let e = evalOci { }; in
    pureCheck "oci-builds-role"
      (e.config.networking.hostName == "mks-oci"
        && e.options ? systemd && !(e.options ? launchd)
        && e.config.boot.isContainer
        && !e.config.boot.loader.systemd-boot.enable
        && e.config.system.build ? image)
      "platform = oci should produce a container-shaped NixOS role with system.build.image";

  # The image is named after the role, which is what makes several roles from
  # one flake distinguishable once they are loaded into a runtime.
  mksystem-oci-image-named-for-role = pureCheck "oci-image-named-for-role"
    ((evalOci { }).config.system.build.image.imageName == "mks-oci")
    "the role's hostname should name its image";

  # ... and it must NOT be nixosModules.default: lanzaboote signs an EFI stub
  # for a bootloader a container has not got, and impermanence describes what
  # survives a tmpfs root when the image IS the root. Both modules are loaded
  # for their option DECLARATIONS (platforms/linux.nix writes those paths under
  # mkIf, and a mkIf-false definition still needs the option to exist), so the
  # thing to assert is that neither is switched on.
  mksystem-oci-has-no-bootloader = pureCheck "oci-has-no-bootloader"
    (
      let c = (evalOci { }).config; in
      !c.boot.lanzaboote.enable
      && !c.my.boot.uefi
      && c.environment.persistence == { }
    )
    "a role must carry neither a signed bootloader nor a tmpfs-root persistence layer";

  # A container has no disk to partition, no hardware profile, and no accounts.
  # Each is rejected with its own reason rather than accepted and ignored.
  mksystem-oci-rejects-filesystem = pureCheck "oci-rejects-filesystem"
    (throws (evalOci { my = { filesystem = { type = "disko"; }; }; }).config)
    "a role naming my.filesystem should be told the image IS its filesystem";

  mksystem-oci-rejects-hardware = pureCheck "oci-rejects-hardware"
    (throws (evalOci { hardware = [{ nixpkgs.hostPlatform = "x86_64-linux"; }]; }).config)
    "a role naming hardware should be told a container has none";

  # The one that keeps the image small BY CONSTRUCTION: a user brings a
  # home-manager closure and a workstation's worth of apps into a machine whose
  # only job is to run one domain.
  mksystem-oci-rejects-users = pureCheck "oci-rejects-users"
    (throws (evalOci { users = [ (mkNixosUser "alice") ]; }).config)
    "a role naming users should be told a role has no accounts";

  # `system` is the ONE thing a container cannot be discovered from, so its
  # absence is an error rather than a guess at the evaluator's architecture.
  mksystem-oci-requires-system = pureCheck "oci-requires-system"
    (throws (self.lib.mkSystem { platform = "oci"; hostname = "mks-oci"; }).config)
    "platform = oci without `system` should throw, not default to the builder's arch";

  # The per-user tier axis is the OPERATING SYSTEM, and a container is Linux.
  # If the oci branch passed "oci" to myModules, a `my.users.<n>.linux` tier
  # would be dropped in silence instead of applied.
  # Deliberately an entry with NO fullName: that is what lib/active-users.nix
  # filters on, so this one carries settings and creates no account -- which is
  # the only shape of my.users a role accepts. Using the account-creating
  # `tieredUser` here would now be rejected, and rightly: it would prove tier
  # resolution with a config a role must refuse.
  mksystem-oci-uses-linux-tier = pureCheck "oci-uses-linux-tier"
    ((evalOci {
      my = { users.alice = { linux = { shell = "fish"; }; darwin = { shell = "zsh"; }; }; };
    }).config.my.users.alice.shell == "fish")
    "a role should resolve the linux tier, because a container is Linux";

  mksystem-oci-rejects-my-users-with-account = pureCheck "oci-rejects-my-users-with-account"
    (throws (evalOci { my = { users = tieredUser; }; }))
    "a role must refuse a my.users entry with a fullName -- that is an account";

  # An unknown platform is a typo, and a typo must not silently fall through to
  # a default. This is also the check that keeps the dispatch honest when a
  # fourth branch (\"vm\") is added.
  mksystem-unknown-platform-throws = pureCheck "unknown-platform-throws"
    (throws (self.lib.mkSystem { platform = "vm"; hostname = "mks-vm"; }))
    "an unimplemented platform should throw by name, not build something else";

  # --- System: tiers and layers reach config -------------------------------

  mksystem-tier-reaches-linux-config = pureCheck "tier-reaches-linux-config"
    ((evalLinux { my = { users = tieredUser; }; }).config.my.users.alice.shell == "fish")
    "the linux tier should win on a linux host";

  mksystem-tier-reaches-darwin-config = pureCheck "tier-reaches-darwin-config"
    ((evalDarwin { my = { users = tieredUser; }; }).config.my.users.alice.shell == "zsh")
    "the darwin tier should win on a darwin host";

  # The reserved keys must not become option paths.
  mksystem-tier-keys-not-options = pureCheck "tier-keys-not-options"
    (
      let u = (evalLinux { my = { users = tieredUser; }; }).config.my.users.alice;
      in !(u ? linux) && !(u ? darwin)
    )
    "my.users.<n>.linux/.darwin must never appear in the option tree";

  # listOf options concatenate across layers -- this is what lets a host add its
  # own facts without re-splicing the shared profile.
  mksystem-layers-concatenate-lists = pureCheck "layers-concatenate-lists"
    (
      let
        c = (evalLinux {
          my = [
            { system.allowedUnfreePackages = [ "aaa" ]; }
            { system.allowedUnfreePackages = [ "bbb" ]; }
          ];
        }).config.my.system.allowedUnfreePackages;
      in
      builtins.elem "aaa" c && builtins.elem "bbb" c
    )
    "listOf options should accumulate across my layers, not replace";

  # ... and unequal scalars must conflict rather than silently last-wins.
  mksystem-layers-conflict-on-scalar = pureCheck "layers-conflict-on-scalar"
    (throws (evalLinux {
      my = [
        { users = { alice = { fullName = "One"; }; }; }
        { users = { alice = { fullName = "Two"; }; }; }
      ];
    }).config.my.users.alice.fullName)
    "two different values for one scalar must be an error, not a silent pick";
}
