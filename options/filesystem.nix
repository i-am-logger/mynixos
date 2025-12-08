{ lib, ... }:

{
  filesystem = {
    type = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "disko" "nixos" ]);
      default = null;
      description = "Filesystem configuration type (disko for declarative partitioning, nixos for standard NixOS)";
    };

    config = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to filesystem configuration file (disko.nix or filesystem.nix)";
    };
  };
}
