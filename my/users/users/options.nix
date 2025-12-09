{ lib, pkgs, ... }:

{
  users = lib.mkOption {
    description = "User configurations";
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      imports = [
        ./base-options.nix
        ./github-options.nix
        ./environment-options.nix
        ./yubikeys-options.nix
        ../graphical/options.nix
        ../dev/options.nix
        ../ai/options.nix
        ../terminal/options.nix
        ./apps-options.nix
      ];

      # Pass pkgs to submodule so environment.nix can use it in defaults
      _module.args.pkgs = lib.mkForce pkgs;
    }));
  };
}
