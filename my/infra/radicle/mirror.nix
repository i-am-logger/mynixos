# Event-driven GitHub mirroring + release publishing, from the seed node.
#
# Why from here: mirroring from ephemeral CI is the approach the (now
# archived) community tools died on -- a short-lived process cannot announce
# reliably. The seed node is long-lived and already holds every ref.
#
# Why event-driven: each repo gets a systemd PATH unit watching the source
# delegate's `sigrefs` file in storage -- radicle rewrites that loose file on
# every signed update from that delegate, so it is the precise "something
# landed" signal. An hourly safety-net timer catches anything missed and
# retries failed release uploads (e.g. the darwin builder was asleep).
#
# The ref-mapping trap this file exists to respect: radicle storage keeps
# per-peer NAMESPACED refs; only the canonical default branch materializes at
# top level. `git push --mirror` from storage would ship namespace and COB
# refs to GitHub. Instead each repo has a bare work repo whose `rad` remote is
# the DELEGATE's view (rad://<rid>/<nid> -- the only view that carries every
# branch and tag), fetched into canonical local names and pushed to GitHub.
#
# Separation from the node unit is deliberate: the node's confinement chroot
# is defended upstream by a systemd-analyze security threshold test, and
# GitHub egress must not be punched through it. This unit runs as the radicle
# user (storage objects are 0600 under the node's UMask, so a separate user
# in the radicle group could traverse but not read) -- but WITHOUT the node
# key: outside the node/broker namespaces the key simply does not exist on
# disk. Only the GitHub token credential enters this unit.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.infra.radicle;
  radProfile = import ./rad-profile.nix {
    inherit config pkgs;
    inherit (cfg) publicKey;
  };

  # rad:z2y7Kq… -> z2y7Kq…  (storage directory name)
  ridSuffix = rid: removePrefix "rad:" rid;
  # unit-name-safe repo handle: the GitHub name is unique and readable
  safeName = repo: replaceStrings [ "/" "." ] [ "-" "-" ] repo.githubRepo;

  sourceNidOf = repo:
    if repo.sourceNid != null then repo.sourceNid else cfg.mirror.sourceNid;

  # Git credential helper: the token comes from the systemd credential
  # directory, never argv, never a URL.
  tokenHelper = pkgs.writeShellScript "radicle-mirror-credential-helper" ''
    echo "username=x-access-token"
    printf 'password=%s\n' "$(cat "$CREDENTIALS_DIRECTORY/github-token")"
  '';

  mirrorScript = repo: ''
    export GH_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/github-token")"

    dir="$STATE_DIRECTORY/${safeName repo}"

    # Idempotent and UNCONDITIONAL: `git init --bare` is safe to re-run, and
    # the remotes are re-pointed every time so a changed rid/sourceNid
    # actually converges (they are baked into the rad:// URL) and a work dir
    # left half-created by a kill mid-run repairs itself instead of wedging.
    git init --bare --initial-branch=main "$dir"
    for remote in "rad:rad://${ridSuffix repo.rid}/${sourceNidOf repo}" \
                  "github:https://github.com/${repo.githubRepo}.git"; do
      name="''${remote%%:*}"
      url="''${remote#*:}"
      git -C "$dir" remote set-url "$name" "$url" 2>/dev/null \
        || git -C "$dir" remote add "$name" "$url"
    done

    # Delegate view -> canonical local names. --prune drops branches the
    # delegate deleted; rad/ and cobs/ refs are never fetched at all.
    git -C "$dir" fetch --prune rad \
      "+refs/heads/*:refs/heads/*" \
      "+refs/tags/*:refs/tags/*"

    # REFUSE to push an empty ref space. `git fetch` exits 0 when the refspec
    # matches nothing (a stale or mistyped sourceNid, a delegate key rotation,
    # or the RID not yet in storage when the boot timer fires), and --prune
    # would have just emptied the local refs too -- so the push below would
    # DELETE every branch and tag on the public GitHub repo. The token has
    # exactly the rights to do it, so this guard is the thing standing
    # between a typo and a wiped public mirror.
    if [ -z "$(git -C "$dir" for-each-ref --count=1 refs/heads)" ]; then
      echo "no refs fetched from ${sourceNidOf repo} for ${repo.rid};" \
           "refusing to prune ${repo.githubRepo}" >&2
      exit 1
    fi

    git -C "$dir" \
      -c credential.helper= \
      -c "credential.helper=!${tokenHelper}" \
      push --prune github \
      "+refs/heads/*:refs/heads/*" \
      ${optionalString repo.pushTags ''"+refs/tags/*:refs/tags/*"''}

    ${optionalString repo.releases.enable ''
      # Releases: every v* tag missing on GitHub gets one. Artifacts are
      # built from the GitHub ref just pushed, so the release is exactly the
      # published tree. A darwin build with the builder asleep fails here and
      # the safety timer retries -- release creation is idempotent.
      #
      # `rc` accumulates failures instead of aborting: one unbuildable tag
      # must not block every later tag forever (the loop is re-entered on
      # every run), but the unit must still end non-zero so the failure is
      # visible and notifyCommand fires.
      rc=0
      while read -r tag; do
        if gh release view "$tag" --repo "${repo.githubRepo}" >/dev/null 2>&1; then
          continue
        fi
        echo "creating release $tag on ${repo.githubRepo}"
        workdir="$STATE_DIRECTORY/${safeName repo}-artifacts/$tag"
        artifacts=()
        ok=1
        ${concatMapStrings (system: ''
          if [ "$ok" = 1 ]; then
            out="$workdir/${system}"
            mkdir -p "$out"
            # --no-link: an out-link under StateDirectory is a GC root that
            # would pin every release closure forever.
            if store=$(nix build --no-link --print-out-paths \
                 "github:${repo.githubRepo}/$tag#packages.${system}.${repo.releases.attribute}" \
                 --print-build-logs); then
              tar -C "$store" -czf "$out.tar.gz" .
              artifacts+=("$out.tar.gz#${safeName repo}-$tag-${system}.tar.gz")
            else
              echo "release $tag: ${system} build failed; skipping this tag" >&2
              ok=0
            fi
          fi
        '') repo.releases.systems}
        if [ "$ok" = 1 ]; then
          gh release create "$tag" --repo "${repo.githubRepo}" \
            --title "$tag" --verify-tag --generate-notes \
            ''${artifacts[@]+"''${artifacts[@]}"} || rc=1
        else
          rc=1
        fi
        rm -rf "$workdir"
      done < <(git -C "$dir" tag --list 'v*')
      [ "$rc" = 0 ]
    ''}
  '';

  mkMirrorService = repo: nameValuePair "radicle-mirror-${safeName repo}" {
    description = "Mirror ${repo.rid} to GitHub (${repo.githubRepo})";
    after = [ "radicle-node.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      RAD_HOME = radProfile.radHome;
      HOME = "/var/lib/radicle-mirror";
    };
    path = [
      pkgs.gitMinimal
      config.services.radicle.package # git-remote-rad resolves rad:// locally
      pkgs.gh
      pkgs.nix
      # `tar`/`gzip` for release artifacts: systemd.services.<n>.path REPLACES
      # PATH (the default adds only coreutils/findutils/gnugrep/gnused), and
      # neither ships tar.
      pkgs.gnutar
      pkgs.gzip
    ];
    onFailure = optional (cfg.mirror.notifyCommand != null)
      "radicle-mirror-notify@radicle-mirror-${safeName repo}.service";
    serviceConfig = {
      Type = "oneshot";
      User = "radicle";
      Group = "radicle";
      StateDirectory = "radicle-mirror";
      WorkingDirectory = "/var/lib/radicle-mirror";
      LoadCredential = [
        "github-token:${(config.sops.secrets.${cfg.mirror.githubTokenSecret} or { path = "/run/secrets/${cfg.mirror.githubTokenSecret}"; }).path}"
      ];
      # See ./rad-profile.nix: the read-only profile every non-node unit
      # needs, and why the private key is not part of it.
      BindReadOnlyPaths = radProfile.bindReadOnlyPaths;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/radicle-mirror" ];
    };
    script = mirrorScript repo;
  };

  # The event trigger: radicle rewrites this loose file on every signed
  # update from the source delegate.
  sigrefsPath = repo:
    "/var/lib/radicle/storage/${ridSuffix repo.rid}/refs/namespaces/${sourceNidOf repo}/refs/rad/sigrefs";

  mkMirrorPath = repo: nameValuePair "radicle-mirror-${safeName repo}" {
    description = "Watch ${repo.rid} for updates to mirror";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = sigrefsPath repo;
      # If the repo has not been fetched yet the file does not exist;
      # PathModified still arms on the closest existing parent.
      Unit = "radicle-mirror-${safeName repo}.service";
    };
  };

  mkMirrorTimer = repo: nameValuePair "radicle-mirror-${safeName repo}" {
    description = "Safety-net mirror of ${repo.rid} (missed events, release retries)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnCalendar = cfg.mirror.safetyInterval;
      RandomizedDelaySec = "2min";
      Persistent = true;
    };
  };
in
{
  config = mkIf (cfg.enable && cfg.mirror.enable) {
    assertions = [
      {
        assertion = cfg.mirror.repos != [ ];
        message = "my.infra.radicle.mirror.enable is set but mirror.repos is empty.";
      }
      {
        assertion = all (r: sourceNidOf r != "") cfg.mirror.repos;
        message = ""
          + "my.infra.radicle.mirror needs a sourceNid for every repo (set mirror.sourceNid "
          + "or the per-repo override). An empty NID names an empty namespace, which "
          + "would fetch zero refs and force-push a deletion of every branch and tag on GitHub.";
      }
    ];

    sops.secrets.${cfg.mirror.githubTokenSecret} = { mode = "0400"; };

    systemd = {
      services =
        listToAttrs (map mkMirrorService cfg.mirror.repos)
        // optionalAttrs (cfg.mirror.notifyCommand != null) {
          "radicle-mirror-notify@" = {
            description = "Notify that %i failed";
            serviceConfig.Type = "oneshot";
            path = [ pkgs.curl ];
            script = ''
              export MIRROR_UNIT="$1"
              ${cfg.mirror.notifyCommand}
            '';
            scriptArgs = "%i";
          };
        };

      paths = listToAttrs (map mkMirrorPath cfg.mirror.repos);
      timers = listToAttrs (map mkMirrorTimer cfg.mirror.repos);
    };
  };
}
