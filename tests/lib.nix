# Shared test utilities for mynixos test suites
{ nixpkgs, system, self, inputs, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};

  # Common specialArgs for test evaluations.
  #
  # `pkgs` is deliberately NOT here. Passing it makes `nixpkgs.overlays` inert
  # (nix warns about this), and my/theming/vogix adds the vogix overlay then
  # installs `pkgs.vogix` -- so with pkgs pinned, every config that reaches vogix
  # died with "attribute 'vogix' missing". That failure was invisible because the
  # checks only forced `networking.hostName`.
  #
  # Leaving it out also matches how mkSystem really builds a system: it passes
  # neither `pkgs` nor `system`, so modules resolve pkgs from the nixpkgs module.
  # tests/real-system-pkgs.nix asserts that path explicitly.
  specialArgs = {
    inherit inputs self;
    inherit (inputs) disko impermanence vogix lanzaboote sops-nix;
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

    # home-manager requires this of every user it manages and provides no
    # default. Real hosts set it per host; test configs create users through
    # `my.users` and would otherwise fail the moment anything forces a
    # home-manager option.
    home-manager.sharedModules = [{ home.stateVersion = "24.11"; }];
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
