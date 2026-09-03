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
  # The enum is the OPERATING SYSTEM, and only that. It used to carry a third
  # value, "oci" -- an output FORMAT wearing a platform's clothes, so a machine
  # bound for a container was CONSTRUCTED differently rather than EXPRESSED
  # differently. A container image is now `system.build.image`, an output of any
  # Linux system exactly as `system.build.vm` already is -- see my/system/oci-image.
  # Adding a format is adding an output, never a platform.
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
      # reason rather than accepted and ignored. Shared by both branches so
      # the sentence reads the same wherever it comes from.
      reject = plat: name: hint:
        throw "mkSystem: '${name}' is not supported when platform = \"${plat}\" (${hint})";

      # The architecture comes from the hardware profile on a real machine, so
      # naming it as well would be two sources for one fact. A container has no
      # hardware profile does, which is why the linux branch accepts it and this
      # helper is darwin-only.
      rejectSystem = plat:
        reject plat "system" "the hardware profile sets nixpkgs.hostPlatform; darwin always has a hardware profile to set it";

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
        # `system` and `hardware` are two answers to one question, so giving both
        # is an error rather than a precedence rule. A real machine gets its
        # architecture from its hardware profile; a machine with no hardware at
        # all -- one that exists to be built as a container image or a VM -- has
        # nowhere else to say what it is, which is the case this argument covers.
        if system != null && hardware != [ ] then
          throw ''
            mkSystem: give either `hardware` or `system`, not both.

            A hardware profile already sets nixpkgs.hostPlatform; naming the
            architecture as well would be two sources for one fact.
          ''
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
                (lib.optionalAttrs (system != null) { nixpkgs.hostPlatform = system; })

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

    in
    if platform == "darwin" then darwinSystem
    else if platform == "linux" then nixosSystem
    else throw "mkSystem: unknown platform '${platform}' (expected \"linux\" or \"darwin\")";
}
