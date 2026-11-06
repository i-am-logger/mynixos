# Pre-release signing for releasable repositories: see ./options.nix.
#
# One key for the machine's pre-releases, held by the `pre-release` service, and
# an instance of it per repository: a handler serving one repository sees only
# that repository's history, so it signs only what that repository's loop
# recorded green.
#
# The machine declares that signer to releasable in /etc/xdg/releasable/signing.toml:
# the format, the public key, and per repository its git common directory and
# socket. A policy that signs with `signer = "machine"` then names no path.
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.infra.signing.releasable;

  gitDir = checkout: "${checkout}/.git";
  checkouts = attrValues cfg.repositories;

  # TOML basic strings take the escapes JSON writes for a string.
  str = builtins.toJSON;
  signer = concatStringsSep "\n"
    ([
      "format = \"ssh\""
      "key = ${str "/var/lib/${config.my.infra.signing.services.pre-release.user}/key.pub"}"
    ] ++ mapAttrsToList
      (name: checkout: concatStringsSep "\n" [
        ""
        "[[repository]]"
        "git-common-dir = ${str (gitDir checkout)}"
        "socket = ${str "/run/signing/${name}.sock"}"
      ])
      cfg.repositories) + "\n";
in
{
  config = {
    # releasable refuses the whole file where it names one git directory twice.
    assertions = [{
      assertion = length (unique checkouts) == length checkouts;
      message = "my.infra.signing.releasable.repositories: a checkout is named more than once: ${concatStringsSep ", " checkouts}.";
    }];

    my.infra.signing.services = mkIf (cfg.repositories != { }) {
      pre-release = {
        handler = cfg.package;
        path = [ pkgs.git ];
        inherit (cfg) clients;
        instances = mapAttrs
          (_: checkout: {
            handlerArgs = [ "signing" "handle" "--repo" (gitDir checkout) ];
            readOnlyPaths = [ (gitDir checkout) ];
          })
          cfg.repositories;
      };
    };

    environment.etc."xdg/releasable/signing.toml" = mkIf (cfg.repositories != { }) {
      text = signer;
    };
  };
}
