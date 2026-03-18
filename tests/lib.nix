# Shared test utilities for mynixos test suites
{ nixpkgs, system, self, inputs, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};

  # Common specialArgs for test evaluations
  specialArgs = {
    inherit inputs self pkgs;
    inherit (inputs) disko impermanence stylix vogix lanzaboote sops-nix;
  };

  # Common base NixOS config for test evaluations
  baseConfig = {
    boot.loader.grub.devices = [ "nodev" ];
    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
    };
    system.stateVersion = "24.11";
    nixpkgs.hostPlatform = system;
  };

  # Common modules for test evaluations
  baseModules = [
    self.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];
in
{
  inherit pkgs specialArgs baseConfig baseModules;
}
