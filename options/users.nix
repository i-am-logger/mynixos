{ lib, pkgs, ... }:

{
  users = lib.mkOption {
    description = "User configurations";
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      imports = [
        ./users/base.nix
        ./users/github.nix
        ./users/environment.nix
        ./users/yubikeys.nix
        ./users/graphical.nix
        ./users/dev.nix
        ./users/ai.nix
        ./users/terminal.nix
        ./users/apps.nix
        # Opinionated defaults (mynixos.nix files)
        ../my/users/terminal/mynixos.nix
        ../my/users/graphical/mynixos.nix
        ../my/users/dev/mynixos.nix
        ../my/users/ai/mynixos.nix
      ];

      # Pass pkgs to submodule so environment.nix can use it in defaults
      _module.args.pkgs = lib.mkForce pkgs;
    }));
  };
}
