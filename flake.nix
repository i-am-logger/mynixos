{
  description = "mynixos - A typed functional DSL for NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Partition management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tmpfs persistence
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # User configuration and dotfiles
    home-manager = {
      url = "github:i-am-logger/home-manager?ref=feature/webapps-module";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    # Runtime theme management.
    #
    # Tracks hud-live rather than master: my/theming/vogix sets
    # programs.vogix.behavior.input.kbLayout, an option that exists only on that
    # branch. Pinned to master this flake does not evaluate on any host. Move it
    # back when hud-live lands.
    vogix = {
      url = "github:i-am-logger/vogix/hud-live";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        tinted-schemes.url = "github:i-am-logger/tinted-schemes";
        # Track vogix16-themes directly rather than through vogix's lock (which
        # can lag its releases). Still pinned by flake.lock — a `nix flake update`
        # is what pulls in the newest theme set.
        vogix16-themes.url = "github:i-am-logger/vogix16-themes";
        rust-overlay.follows = "lanzaboote/rust-overlay";
        devenv.inputs.git-hooks.follows = "git-hooks";
      };
    };

    # Monochromatic screen overlay for Hyprland
    hypr-vogix = {
      url = "github:i-am-logger/hypr-vogix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pre-commit.inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    # Hardware configurations
    # macOS system configuration. mkSystem dispatches to nix-darwin's
    # darwinSystem when `platform = "darwin"`.
    #
    # nix-darwin and nixpkgs must agree on nixos-render-docs' CLI (the
    # darwin-manual build passes flags that move between releases), so this
    # follows our nixpkgs rather than pinning independently.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Homebrew, installed and pinned declaratively. nix-darwin's `homebrew.*`
    # module only writes a Brewfile and runs `brew bundle` — it does NOT install
    # Homebrew, so this is what makes that module usable at all.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development tooling
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , impermanence
    , lanzaboote
    , treefmt-nix
    , git-hooks
    , ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      # Systems whose CHECKS we can run. Linux only, and deliberately so: most
      # of tests/ builds a real `lib.nixosSystem` for the given system, which is
      # meaningless on darwin. Measured — with aarch64-darwin in this list,
      # `checks.aarch64-darwin.real-system-pkgs` and the `smoke-*` tests fail to
      # evaluate, while `module-eval-*` and `formatting` are fine. Rather than
      # ship a half-broken `nix flake check`, checks stay Linux-only.
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = lib.genAttrs supportedSystems;

      # Systems we can DEVELOP mynixos on. This repo is now edited from a Mac, so
      # `nix fmt`, `nix develop` and `nix run` have to work there — none of which
      # build a NixOS system, so none of them have the problem above.
      devSystems = supportedSystems ++ [ "aarch64-darwin" ];
      forAllDevSystems = lib.genAttrs devSystems;

      # mynixos library functions
      mynixosLib = import ./lib {
        inherit
          inputs
          lib
          nixpkgs
          self
          ;
      };

      # treefmt configuration (shared between formatter and checks)
      treefmtEval = forAllDevSystems (system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );

      # pre-commit hooks, defined over devSystems rather than supportedSystems.
      # `checks` is Linux-only because its tests build real NixOS systems, but
      # `nix develop` has to work on darwin and its shell needs these hooks, so
      # devShells consumes this directly instead of reaching into checks.
      preCommitCheck = forAllDevSystems (system:
        git-hooks.lib.${system}.run {
          src = self;
          hooks = {
            treefmt = {
              enable = true;
              package = treefmtEval.${system}.config.build.wrapper;
            };
            statix.enable = true;
            deadnix.enable = true;
          };
        }
      );

      # Security key type constructors (exported in lib for use in configs)
      securityKeys = {
        yubikey =
          { serialNumber
          , gpgKeyId ? null
          , ...
          }:
          {
            type = "yubikey";
            inherit serialNumber gpgKeyId;
          };

        solokey =
          { serialNumber, ... }:
          {
            type = "solokey";
            inherit serialNumber;
          };

        nitrokey =
          { serialNumber, ... }:
          {
            type = "nitrokey";
            inherit serialNumber;
          };
      };

      # Hardware profiles (exported in lib for use in configs)
      hardware = {
        motherboards = {
          gigabyte = {
            x870e-aorus-elite-wifi7 = ./my/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7;
          };
        };
        laptops = {
          apple = {
            macbook-pro-m5-max = ./my/hardware/laptops/apple/macbook-pro-m5-max;
          };
          lenovo = {
            legion-16irx8h = ./my/hardware/laptops/lenovo/legion-16irx8h;
          };
        };
        cooling = {
          nzxt = {
            kraken-elite-rgb = {
              elite-240-rgb = ./my/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb;
            };
          };
        };
      };


    in
    {
      # Main NixOS module providing the `my.*` namespace.
      #
      # The module set itself lives in ./platforms/ -- see platforms/common.nix
      # for how platform reach is expressed (it is a matter of WHICH FILE imports
      # a module, not of a `pkgs.stdenv.hostPlatform.isX` test).
      #
      # impermanence and lanzaboote are listed here rather than in
      # platforms/linux.nix because they are flake input *values*, not paths.
      nixosModules.default = {
        imports = [
          ./platforms/linux.nix
          impermanence.nixosModules.impermanence
          lanzaboote.nixosModules.lanzaboote
        ];
      };


      # Main nix-darwin module providing the `my.*` namespace.
      #
      # nix-homebrew is listed here, not in platforms/darwin.nix, for the same
      # reason impermanence and lanzaboote are listed above: it is a flake input
      # *value* rather than a path. my/system/homebrew writes `nix-homebrew.*`,
      # which only exists once this module is loaded — nix-darwin's own
      # `homebrew.*` module writes a Brewfile and runs `brew bundle`, but does
      # not install Homebrew itself.
      darwinModules.default = {
        imports = [
          ./platforms/darwin.nix
          inputs.nix-homebrew.darwinModules.nix-homebrew
        ];
      };

      # Export library functions
      lib = mynixosLib // {
        inherit securityKeys hardware;
      };

      # Formatter (treefmt: nix + shell + yaml)
      formatter = forAllDevSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Checks (run via `nix flake check`)
      checks = forAllSystems (system:
        let
          moduleEvalTests = import ./tests/module-eval.nix {
            inherit lib nixpkgs system self inputs;
          };
          typeValidationTests = import ./tests/type-validation.nix {
            inherit lib nixpkgs system self inputs;
          };
          smokeTests = import ./tests/integration-smoke.nix {
            inherit self inputs system;
          };
          edgeCaseTests = import ./tests/persistence-and-edge-cases.nix {
            inherit self inputs system;
          };
          # Regression: evaluate a system the mkSystem way (pkgs NOT in
          # specialArgs) so mkApp's pkgs sourcing is actually exercised.
          realPkgsTest = import ./tests/real-system-pkgs.nix {
            inherit lib nixpkgs system self inputs;
          };
          # Asserts which my.users options each platform declares. Pure eval, so
          # a Linux runner enumerates the darwin module set without building it.
          userOptionReachTest = import ./tests/user-option-reach.nix {
            inherit lib nixpkgs system self inputs;
          };

          # mkSystem itself: platform dispatch, argument rejection, `my` layering
          # and the per-user linux/darwin tiers.
          mkSystemTests = import ./tests/mksystem.nix {
            inherit lib nixpkgs system self inputs;
          };

          # What platforms/oci.nix has to undo, and the guard that turns a
          # silently-skipped firewall into a failure.
          ociPlatformTests = import ./tests/oci-platform.nix {
            inherit lib nixpkgs system self inputs;
          };

          # Secrets must never land in /nix/store. Guards the flake-input
          # interpolation that copies a whole directory in as a side effect.
          secretsStorePolicyTests = import ./tests/secrets-store-policy.nix {
            inherit lib nixpkgs system self inputs;
          };

          # The darwin module set, evaluated from a Linux runner. Only `config`
          # is read, so no aarch64-darwin builder is needed.
          darwinSmokeTests = import ./tests/darwin-smoke.nix {
            inherit lib nixpkgs system self inputs;
          };
        in
        {
          formatting = treefmtEval.${system}.config.build.check self;

          pre-commit = preCommitCheck.${system};
        } // lib.mapAttrs' (name: value: lib.nameValuePair "module-eval-${name}" value) moduleEvalTests
        // lib.mapAttrs' (name: value: lib.nameValuePair name value) typeValidationTests
        // smokeTests
        // edgeCaseTests
        // realPkgsTest
        // userOptionReachTest
        // mkSystemTests
        // darwinSmokeTests
        // secretsStorePolicyTests
        // ociPlatformTests
      );

      # Heavy booting VM tests, kept OUT of `checks` so `nix flake check` stays
      # light and KVM-free (it is part of the pre-push routine). Run on demand:
      #   nix build .#tests.<system>.vm-system -L
      tests = forAllSystems (system: {
        vm-system = import ./tests/vm-system.nix {
          inherit self inputs system lib nixpkgs;
        };
        # The graphical login end to end (SDDM + the vogix greeter), with the
        # vogix overlay arriving through my/theming/vogix like on a real host:
        #   nix build .#tests.<system>.vm-login -L
        vm-login = import ./tests/vm-login.nix {
          inherit self inputs system lib nixpkgs;
        };
        # The Radicle forge end to end: two VMs on an isolated net (a private
        # network by construction), seed + CI + a workstation profile pushing:
        #   nix build .#tests.<system>.vm-radicle -L
        vm-radicle = import ./tests/vm-radicle.nix {
          inherit self inputs system lib nixpkgs;
        };
      });


      # Dev shell with pre-commit hooks installed
      devShells = forAllDevSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pre-commit = preCommitCheck.${system};
        in
        {
          default = pkgs.mkShell {
            inherit (pre-commit) shellHook;
            buildInputs = pre-commit.enabledPackages ++ [
              pkgs.statix
              pkgs.deadnix
              pkgs.shellcheck
              pkgs.shfmt
              pkgs.nixpkgs-fmt
            ];
          };
        }
      );

      # Runnable demos and utilities.
      #
      # forAllSystems, not forAllDevSystems: the only app records a Hyprland
      # session with wf-recorder, and neither it nor hypr-vogix builds on darwin.
      # Exposing it there made `nix flake check` fail on this flake's own output.
      apps = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ inputs.hypr-vogix.overlays.default ];
            config.allowUnfreePredicate = pkg: lib.getName pkg == "hypr-vogix";
          };
          demo = pkgs.writeShellApplication {
            name = "demo-hypr-vogix";
            runtimeInputs = [ pkgs.wf-recorder pkgs.hypr-vogix pkgs.ffmpeg ];
            text = builtins.readFile ./scripts/demo-hypr-vogix.sh;
          };
        in
        {
          demo-hypr-vogix = {
            type = "app";
            program = "${demo}/bin/demo-hypr-vogix";
          };
        }
      );
    };
}
