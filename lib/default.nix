{ inputs, lib, nixpkgs, self }:

{
  # System builder function - the core mynixos API
  mkSystem = (import ./mkSystem.nix { inherit inputs lib nixpkgs self; }).mkSystem;

  # Auto-import utilities for recursive module loading
  autoImports = import ./auto-imports.nix { inherit lib; };

  # App helper utilities for category-based enabling
  appHelpers = import ./app-helpers.nix { inherit lib; };
}
