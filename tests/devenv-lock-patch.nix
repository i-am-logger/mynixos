# devenv's Nix libraries, built from a source that tells a stale lock by its link
# count (my/system/nixpkgs-fixes/devenv.nix), for pkgs.devenv and for the package a
# user's devenv app installs.
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

        my.users.alice = {
          fullName = "Alice";
          apps.dev.tools.devenv.enable = true;
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
in
{
  devenv-lock-patch = hostPkgs.runCommand "devenv-lock-patch" { } ''
    for f in ${lockSource eval.pkgs.devenv} ${lockSource homeDevenv}; do
      grep -qF 'if (st.st_nlink == 0)' "$f"
      if grep -qF 'if (st.st_size != 0)' "$f"; then
        echo "$f still tests the lock file's size" >&2
        exit 1
      fi
    done
    touch $out
  '';
}
