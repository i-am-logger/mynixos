# Regression test for the mkApp pkgs-provisioning bug.
#
# The migrated app modules are bare `args:` lambdas, so the module system only
# gives them `pkgs` if something NAMES it. `mkSystem` (the real builder) does NOT
# pass `pkgs` via specialArgs — pkgs comes from the nixpkgs module via config.
# An earlier version of mkApp forwarded its own (pkgs-less) module args straight
# to each app's `home`, so any app whose home used `pkgs` failed the real build
# with "function 'home' called without required argument 'pkgs'".
#
# Crucially, the other test harnesses (tests/lib.nix and the VM test) pass `pkgs`
# via specialArgs, which MASKED the bug. This test deliberately evaluates a system
# the mkSystem way — pkgs NOT in specialArgs — and forces an app whose home uses
# pkgs (jq: `home = { pkgs, ... }: { home.packages = [ pkgs.jq ]; }`).
{ lib, nixpkgs, system, self, inputs }:

let
  hostPkgs = nixpkgs.legacyPackages.${system};

  eval = lib.nixosSystem {
    # Match lib/mkSystem.nix specialArgs EXACTLY — note the absence of `pkgs`
    # (mkSystem does not pass it; that is precisely what this test exercises).
    # sops-nix is imported as a module below, not a specialArg (as in mkSystem).
    specialArgs = {
      inherit inputs;
      inherit (inputs)
        disko
        impermanence
        stylix
        vogix
        hypr-vogix
        lanzaboote
        self
        ;
      secrets = inputs.secrets or null;
    };
    modules = [
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      {
        boot.loader.grub.devices = [ "nodev" ];
        fileSystems."/" = {
          device = "tmpfs";
          fsType = "tmpfs";
        };
        system.stateVersion = "24.11";
        nixpkgs.hostPlatform = system;
        networking.hostName = "pkgs-regression";

        my.users.alice = {
          fullName = "Alice";
          # jq is a light, free app whose mkApp `home` uses `pkgs`.
          apps.dev.tools.jq.enable = true;
        };
        home-manager = {
          useUserPackages = true;
          backupFileExtension = "backup";
          sharedModules = [{ home.stateVersion = "24.11"; }];
          users.alice = { };
        };
      }
    ];
  };

  # Forcing alice's home.packages forces the jq app module's `home`, which
  # references `pkgs`. With the bug, this throws at eval.
  forced = builtins.length eval.config.home-manager.users.alice.home.packages;
in
{
  real-system-pkgs = hostPkgs.runCommand "real-system-pkgs" { } ''
    echo "alice home.packages evaluated (count: ${toString forced}) without a pkgs specialArg"
    touch $out
  '';
}
