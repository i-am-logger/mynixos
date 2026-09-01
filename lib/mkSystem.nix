{ inputs
, lib
, self
,
}:

let
  core = import ./mk-system-core.nix { inherit inputs lib; };
in
{
  # Build a system for any of the three platforms.
  #
  # There is deliberately ONE builder rather than a separate mkDarwinSystem: a
  # host should read the same way whichever OS it runs, and a single entry point
  # is what lets darwin-invalid arguments be REJECTED rather than silently
  # ignored (see the throws below).
  #
  #   mkSystem {
  #     platform = "darwin";                     # defaults to "linux"
  #     hostname = "aether5d-dev";
  #     hardware = [ mynixos.hardware.laptops.apple.macbook-pro-m5-max ];
  #     users    = [ myLib.users.logger ];
  #     my       = { ... };
  #   }
  #
  # `platform` is explicit rather than inferred from a `system` string, because
  # on a real machine mkSystem takes no `system` argument at all -- the hardware
  # modules set `nixpkgs.hostPlatform`.
  #
  # It is deliberately a FLAT enum even though it now carries two axes:
  # "linux"/"darwin" are operating systems while "oci" is an output format (and
  # "vm", when it lands, will be another). A container is implicitly Linux, so
  # the enum stays unambiguous in practice, and one word in a host file reads
  # better than a `platform` x `format` pair. Each value is its own branch
  # below; adding one is an addition, not a rewrite.
  mkSystem =
    { platform ? "linux"
    , hostname ? null
    , hardware ? [ ]
    , users ? [ ]
    , config ? null
    , extraModules ? [ ]
    , my ? { }
    , system ? null
    }:
    let
      validUsers = core.assertUsers users;

      # `my` may be a list of layers, so the few places that read a scalar out of
      # it before any module exists use a flattened read-only view. Never used to
      # build config -- see myView in ./mk-system-core.nix.
      myFlat = core.myView my;

      resolvedHostname = core.resolveHostname { inherit hostname; my = myFlat; };

      # An argument that a given platform cannot honour is REJECTED with a
      # reason rather than accepted and ignored. Shared by all three branches so
      # the sentence reads the same wherever it comes from.
      reject = plat: name: hint:
        throw "mkSystem: '${name}' is not supported when platform = \"${plat}\" (${hint})";

      # The architecture comes from the hardware profile on a real machine, so
      # naming it as well would be two sources for one fact. A container has no
      # hardware profile, which is the whole reason `system` exists -- see the
      # oci branch.
      rejectSystem = plat:
        reject plat "system" "the hardware profile sets nixpkgs.hostPlatform; `system` is for platform = \"oci\" only";

      # ---------------------------------------------------------------------
      # darwin
      # ---------------------------------------------------------------------
      darwinSystem =
        # `my.filesystem` is not declared on darwin at all (its options live in
        # my/filesystem-options.nix, imported only by platforms/linux.nix), so
        # setting it already fails in the module system. This check catches it
        # one step earlier, with a reason.
        if myFlat.filesystem or null != null then reject "darwin" "my.filesystem" "disko does not manage APFS; macOS owns the disk"
        else if system != null then rejectSystem "darwin"
        else
          inputs.nix-darwin.lib.darwinSystem {
            # NOTE: pass neither `pkgs` nor `system`. Both are backwards-compat
            # shims in darwinSystem; `pkgs` becomes
            # `_module.args.pkgs = lib.mkForce ...`, which makes `nixpkgs.config`
            # inert and so breaks my/system/unfree. The hardware profile sets
            # nixpkgs.hostPlatform instead.
            specialArgs = {
              inherit inputs self;
            };

            modules =
              hardware
              ++ [ self.darwinModules.default ]
              ++ (lib.optionals (config != null) [ config ])
              ++ [
                {
                  networking = {
                    hostName = resolvedHostname;
                    localHostName = resolvedHostname;
                    computerName = resolvedHostname;
                  };
                }

                # The architecture comes from the hardware profile, exactly as on
                # NixOS -- mkSystem takes no `system` argument. `platform` only
                # selects the evaluator, so the two could disagree if a host
                # forgot to enable a darwin hardware profile. Catch that here
                # rather than letting it produce a subtly wrong system.
                ({ config, ... }: {
                  assertions = [{
                    assertion = config.nixpkgs.hostPlatform.isDarwin;
                    message = ''
                      mkSystem: platform = "darwin" but nixpkgs.hostPlatform is
                      "${config.nixpkgs.hostPlatform.system}".

                      The architecture comes from the hardware profile. Enable one,
                      e.g. my.hardware.laptops.apple.macbook-pro-m5-max.enable = true.
                    '';
                  }];
                })

                # macOS accounts themselves come from my/users/users/darwin.nix,
                # driven by `my.users` -- the same data-driven route NixOS uses.
                # A user entry may still supply an explicit `darwinUser` module.
                { imports = lib.filter (m: m != null) (map (u: u.darwinUser or null) validUsers); }

                inputs.home-manager.darwinModules.home-manager
                (core.homeManagerConfig validUsers)

                inputs.sops-nix.darwinModules.sops
              ]
              ++ core.myModules "darwin" my
              ++ extraModules;
          };

      # ---------------------------------------------------------------------
      # NixOS
      # ---------------------------------------------------------------------
      filesystemType = myFlat.filesystem.type or null;
      filesystemConfig = myFlat.filesystem.config or null;

      filesystemModules =
        if filesystemType == "disko" && filesystemConfig != null then
          [
            inputs.disko.nixosModules.disko
            { disko.devices = import filesystemConfig { }; }
          ]
        else if filesystemType == "nixos" && filesystemConfig != null then
          [ filesystemConfig ]
        else
          [ ];

      # Shared by the two NixOS-evaluated branches (a role is a Linux machine,
      # so it needs the same specialArgs a host does -- the modules that read
      # them are the same modules).
      nixosSpecialArgs = {
        inherit inputs;
        inherit (inputs)
          disko
          impermanence
          vogix
          hypr-vogix
          lanzaboote
          self
          ;
      };

      nixosSystem =
        if system != null then rejectSystem "linux"
        else
          lib.nixosSystem {
            specialArgs = nixosSpecialArgs;

            modules =
              hardware
              ++ [ self.nixosModules.default ]
              ++ filesystemModules
              ++ (lib.optionals (config != null) [ config ])
              ++ [
                { networking.hostName = resolvedHostname; }

                (
                  let
                    invalid = lib.filter (u: !(u ? nixosUser)) validUsers;
                  in
                  assert lib.assertMsg (invalid == [ ])
                    "mkSystem: each user must have a 'nixosUser' attribute on NixOS";
                  { imports = map (u: u.nixosUser) validUsers; }
                )

                inputs.home-manager.nixosModules.home-manager
                (core.homeManagerConfig validUsers)

                inputs.sops-nix.nixosModules.sops
              ]
              ++ core.myModules "linux" my
              ++ extraModules;
          };

      # ---------------------------------------------------------------------
      # OCI -- a ROLE: the same mynixos system, emitted as a container image
      # ---------------------------------------------------------------------
      #
      # `platform` picks the emitter here exactly as it picks lib.nixosSystem
      # versus darwinSystem above. What comes back is a full NixOS evaluation,
      # so a role reads like any other machine; the container-shaped output is
      # `config.system.build.image` (my/system/oci-image), beside the
      # `.toplevel` it is built from.
      #
      # `self.nixosModules.oci`, not `.default`. Both carry platforms/linux.nix
      # and the same two flake inputs; what the oci set adds is nixpkgs'
      # docker-container profile, the image emitter, and the assertions that
      # forbid a role from booting like a host. platforms/oci.nix says why in
      # its own header.
      ociSystem =
        if myFlat.filesystem or null != null then
          reject "oci" "my.filesystem" "a container has no disk to partition; the image is its filesystem, and state is a bind mount from whatever hosts it"
        # Rejected HERE rather than by an assertion in platforms/oci.nix, where
        # it was first written and where it silently did nothing. `assertions`
        # is a list, and the module system forces the whole list before
        # filtering to the failing ones -- so enabling impermanence produced
        # nixpkgs' own `fileSystems."/persist".fsType was accessed but has no
        # value defined` (impermanence declares the mount; a role has no
        # filesystem module to give it a device) and the assertion's message was
        # never reached. Rejecting before any module evaluates cannot be
        # shadowed that way.
        else if myFlat.storage.impermanence.enable or false then
          reject "oci" "my.storage.impermanence" "impermanence describes what survives a tmpfs root being wiped, and a container's root IS the image. State a role must keep is a bind mount declared by whatever hosts it"
        else if hardware != [ ] then
          reject "oci" "hardware" "a container has no hardware; `system` is what gives the image its architecture"
        # Both spellings, because rejecting only the ARGUMENT would leave the
        # message claiming more than the check enforces: `my.users` reaches the
        # same account-creating and home-manager modules -- platforms/oci.nix
        # imports linux.nix wholesale -- so a role could still grow accounts
        # through the `my` layers while mkSystem reported them forbidden.
        else if users != [ ] then
          reject "oci" "users" "a role has no accounts -- users would pull home-manager and a whole workstation closure into the image. A role is one domain switched on, nothing else"
        else if lib.filterAttrs (_: u: u.fullName or null != null) (myFlat.users or { }) != { } then
          reject "oci" "my.users (with a fullName)" "a role has no accounts, and `fullName` is what makes one -- lib/active-users.nix filters on exactly that, so such an entry reaches the same account and home-manager modules the `users` argument does. An entry WITHOUT a fullName is fine: it carries settings and creates no account"
        else if system == null then
          throw ''
            mkSystem: platform = "oci" requires `system` (e.g. "x86_64-linux").

            On a real machine the hardware profile sets nixpkgs.hostPlatform. A
            container has no hardware profile, so the architecture has to be
            named -- and it is the one thing an image cannot be discovered from.
          ''
        else
          lib.nixosSystem {
            specialArgs = nixosSpecialArgs;

            modules =
              [ self.nixosModules.oci ]
              ++ (lib.optionals (config != null) [ config ])
              ++ [
                {
                  networking.hostName = resolvedHostname;
                  nixpkgs.hostPlatform = system;
                }

                # No per-user system modules: `users` is asserted empty above.
                # home-manager is still loaded, with no users -- every mkApp
                # module writes `home-manager.users = { ... }`, so the option
                # has to EXIST even when the attrset it gets is empty. An empty
                # user set contributes nothing to the closure.
                inputs.home-manager.nixosModules.home-manager
                (core.homeManagerConfig validUsers)

                inputs.sops-nix.nixosModules.sops
              ]
              # "linux", not "oci": the per-user tier axis is the OPERATING
              # SYSTEM, and a container is Linux. Passing "oci" here would
              # silently drop a `my.users.<n>.linux` tier instead of applying
              # it -- and platformTiers stays a two-value list.
              ++ core.myModules "linux" my
              ++ extraModules;
          };
    in
    if platform == "darwin" then darwinSystem
    else if platform == "linux" then nixosSystem
    else if platform == "oci" then ociSystem
    else throw "mkSystem: unknown platform '${platform}' (expected \"linux\", \"darwin\" or \"oci\")";
}
