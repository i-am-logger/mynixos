{ inputs, lib, nixpkgs, self }:

{
  # System builder function - the core mynixos API
  mkSystem = (import ./mkSystem.nix { inherit inputs lib nixpkgs self; }).mkSystem;
}
