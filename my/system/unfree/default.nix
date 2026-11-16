{ activeUsers, config, lib, ... }:

with lib;

let
  allowedPackages = config.my.system.allowedUnfreePackages;
  allowedLicenses = config.my.system.allowedUnfreeLicenses;
  hasAllowed = allowedPackages != [ ] || allowedLicenses != [ ];

  # One predicate: a package is allowed by its name, or by a licence it
  # carries (meta.license may be one licence or a list).
  predicate = pkg:
    builtins.elem (lib.getName pkg) allowedPackages
    || lib.any (l: builtins.elem (l.shortName or "") allowedLicenses)
      (lib.toList (pkg.meta.license or [ ]));
in
{
  config = mkIf hasAllowed {
    # Single centralized unfree predicate at the NixOS level
    nixpkgs.config.allowUnfreePredicate = predicate;

    # Propagate the same predicate to all home-manager users
    home-manager.users = mapAttrs
      (_name: _userCfg: {
        nixpkgs.config.allowUnfreePredicate = predicate;
      })
      (activeUsers config.my.users);
  };
}
