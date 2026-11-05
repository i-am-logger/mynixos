# devenv's and the system's Nix libraries, built from a source that tells a stale lock by what
# its path names (my/system/nixpkgs-fixes/nix-lock-stale.nix), for pkgs.devenv, for
# the package a user's devenv app installs, for the system Nix, and as nix-direnv's
# fallback Nix.
#
# Reads the source devenv's nix-store is really built from, so it compiles nothing.
# When a devenv update moves to a Nix the patch no longer applies to, building
# that source fails here first, and the overlay can go.
{ lib, nixpkgs, system, self, inputs }:

let
  hostPkgs = nixpkgs.legacyPackages.${system};

  eval = lib.nixosSystem {
    specialArgs = {
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
        networking.hostName = "devenv-lock-patch";

        # The system Nix is set by my/system/core, which this switches on.
        my.system.enable = true;

        my.users.alice = {
          fullName = "Alice";
          apps.dev.tools.devenv.enable = true;
          apps.dev.tools.direnv.enable = true;
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

  byPname = pname: lib.findFirst (d: (d.pname or "") == pname) (throw "no ${pname}");

  lockSource = devenv:
    let
      storeC = byPname "nix-store-c" devenv.buildInputs;
      store = byPname "nix-store" storeC.propagatedBuildInputs;
    in
    "${store.src}/src/libstore/unix/pathlocks.cc";

  homeDevenv = byPname "devenv" eval.config.home-manager.users.alice.home.packages;
  systemNix = "${eval.config.nix.package.libs.nix-store.src}/src/libstore/unix/pathlocks.cc";
  homeDirenv = eval.config.home-manager.users.alice.programs.direnv.nix-direnv.package;
  # Asks whether the package is what it would be with the system Nix as its fallback,
  # because the path itself sits in a file that only exists once Nix is built.
  direnvFallback = homeDirenv.outPath == (homeDirenv.override { nix = eval.config.nix.package; }).outPath;
in
{
  devenv-lock-patch = hostPkgs.runCommand "devenv-lock-patch" { } ''
    for f in ${lockSource eval.pkgs.devenv} ${lockSource homeDevenv} ${systemNix}; do
      grep -qF 'isLockFileStale(fd.get(), lockPath)' "$f"
      if grep -qF 'if (st.st_size != 0)' "$f"; then
        echo "$f still tests the lock file's size" >&2
        exit 1
      fi
    done
    ${lib.optionalString (!direnvFallback) "echo nix-direnv does not fall back to the system Nix >&2; exit 1"}
    touch $out
  '';
}
