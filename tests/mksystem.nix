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
  # A machine with no hardware profile -- the shape a system built to be run as
  # a container image has. Nothing is added on top: the variant supplies the
  # stateVersion and the docker-container profile relaxes the
  # `fileSystems."/"` requirement, so a machine that needed an `extraModules`
  # prelude here would be one a consumer could not write either.
  imageableBase = {
    hostname = "mks-oci";
    system = "x86_64-linux";
  };

  evalImageable = args: self.lib.mkSystem (imageableBase // args);

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

  # --- The container image, as an OUTPUT of a machine ------------------------

  # `system.build.image` is an output of any Linux system, exactly as
  # `system.build.vm` is. What distinguishes the IMAGE from the machine is the
  # variant it is built from: `boot.isContainer`, no kernel, no initrd, no
  # bootloader. Asserting the hostname alone would prove none of that.
  mksystem-image-is-an-output =
    let e = evalImageable { }; in
    pureCheck "image-is-an-output"
      (e.config.networking.hostName == "mks-oci"
        && e.options ? systemd && !(e.options ? launchd)
        && e.config.system.build ? image
        # the base is an ordinary machine -- it is NOT a container
        && !e.config.boot.isContainer
        # ... and its image is
        && e.config.virtualisation.ociVariant.boot.isContainer
        && !e.config.virtualisation.ociVariant.boot.loader.systemd-boot.enable)
      "every Linux system should offer system.build.image without becoming a container itself";

  # The image is named after the machine, which is what makes several images
  # from one flake distinguishable once they are loaded into a runtime.
  mksystem-image-named-for-machine = pureCheck "image-named-for-machine"
    ((evalImageable { }).config.system.build.image.imageName == "mks-oci")
    "the machine's hostname should name its image";

  # lanzaboote signs an EFI stub for a bootloader a container has not got, and
  # impermanence describes what survives a tmpfs root when the image IS the
  # root. Both modules are still LOADED for their option declarations
  # (platforms/linux.nix writes those paths under mkIf, and a mkIf-false
  # definition still needs the option to exist), so the thing to assert is that
  # neither is switched on inside the variant.
  mksystem-image-has-no-bootloader = pureCheck "image-has-no-bootloader"
    (
      let c = (evalImageable { }).config.virtualisation.ociVariant; in
      !c.boot.lanzaboote.enable
      && !c.my.boot.uefi
      && c.environment.persistence == { }
    )
    "an image must carry neither a signed bootloader nor a tmpfs-root persistence layer";

  # THE PROPERTY THAT REPLACED FIVE REJECTIONS.
  #
  # `platform = "oci"` used to REFUSE a machine that named my.filesystem,
  # hardware, users, or impermanence -- because such a machine could not be
  # built as a container. A variant does not get to refuse: it is an output of
  # whatever machine it is asked about, including a laptop with disks and a
  # GPU, so it OVERRIDES instead. qemu-vm.nix does the same to `fileSystems`.
  #
  # Impermanence is the sharp case and the reason rejection could not simply
  # move into an assertion: it declares a /persist mount with no device, and
  # `assertions` is forced as a whole list before failures are filtered, so it
  # errors with nixpkgs' own "fileSystems.\"/persist\".fsType was accessed but
  # has no value defined" before any message of ours is read.
  mksystem-image-overrides-impermanence = pureCheck "image-overrides-impermanence"
    (
      let e = evalImageable { my = { storage.impermanence.enable = true; }; }; in
      e.config.my.storage.impermanence.enable
      && !e.config.virtualisation.ociVariant.my.storage.impermanence.enable
      && builtins.isString e.config.system.build.image.drvPath
    )
    "a machine using impermanence must still produce an image, with impermanence off inside it";

  # The per-user tier axis is the OPERATING SYSTEM, and a container is Linux --
  # so the tier a machine resolved is the tier its image carries. Nothing about
  # taking an image may re-resolve it.
  mksystem-image-keeps-linux-tier = pureCheck "image-keeps-linux-tier"
    ((evalImageable {
      my = { users.alice = { linux = { shell = "fish"; }; darwin = { shell = "zsh"; }; }; };
    }).config.virtualisation.ociVariant.my.users.alice.shell == "fish")
    "an image should carry the linux tier its machine resolved";

  # `system` and `hardware` are two answers to one question. A machine with a
  # hardware profile gets its architecture from it; one with none -- which is
  # the shape a machine built only to be imaged has -- names it. Both is an
  # error rather than a precedence rule.
  mksystem-rejects-system-and-hardware = pureCheck "rejects-system-and-hardware"
    (throws (self.lib.mkSystem {
      hostname = "mks-both";
      system = "x86_64-linux";
      hardware = [{ nixpkgs.hostPlatform = "x86_64-linux"; }];
    }).config)
    "naming both `system` and `hardware` should be refused, not silently resolved";

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
