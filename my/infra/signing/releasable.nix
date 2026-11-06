# Pre-release signing for releasable repositories: see ./options.nix.
#
# One key for the machine's pre-releases, held by the `pre-release` service, and
# an instance of it per repository: a handler serving one repository sees only
# that repository's history, so it signs only what that repository's loop
# recorded green.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.signing.releasable;
in
{
  config.my.infra.signing.services = mkIf (cfg.repositories != { }) {
    pre-release = {
      handler = cfg.package;
      path = [ pkgs.git ];
      inherit (cfg) clients;
      instances = mapAttrs
        (_: checkout: {
          handlerArgs = [ "signing" "handle" "--repo" "${checkout}/.git" ];
          readOnlyPaths = [ "${checkout}/.git" ];
        })
        cfg.repositories;
    };
  };
}
