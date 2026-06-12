{ inputs, lib, nixpkgs, self }:

{
  # System builder function - the core mynixos API
  inherit (import ./mkSystem.nix { inherit inputs lib nixpkgs self; }) mkSystem;

  # Installer ISO builder
  inherit (import ./mkInstallerISO.nix { inherit inputs lib nixpkgs; }) mkInstallerISO;

  # Per-user app module builder (collapses the home-manager boilerplate)
  inherit (import ./mk-app.nix) mkApp;

  # Filter users to only those with fullName defined (fully configured users)
  # Users without fullName are partial configs (mounts, yubikeys, email only)
  # Usage: activeUsers config.my.users
  activeUsers = import ./active-users.nix lib;
}
