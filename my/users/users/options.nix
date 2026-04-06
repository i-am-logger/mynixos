{ lib, ... }:

{
  users = lib.mkOption {
    description = "User configurations";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          imports = [
            ./base-options.nix
            ./github-options.nix
            ./environment-options.nix
            ./yubikeys-options.nix
            ../graphical/options.nix
            ../dev/options.nix
            ../ai/options.nix
            ../terminal/options.nix
            ../theming/options.nix
            ./apps-options.nix
          ];
        }
      )
    );
  };
}
