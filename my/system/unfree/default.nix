{ config, lib, ... }:

with lib;

let
  allowedPackages = config.my.system.allowedUnfreePackages;
  hasAllowedPackages = allowedPackages != [ ];
in
{
  config = mkIf hasAllowedPackages {
    # Single centralized unfree predicate at the NixOS level
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) allowedPackages;

    # Propagate the same predicate to all home-manager users
    home-manager.users = mapAttrs
      (_name: _userCfg: {
        nixpkgs.config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) allowedPackages;
      })
      config.my.users;
  };
}
