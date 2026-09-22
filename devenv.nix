{ pkgs, ... }:

{
  packages = [
    pkgs.git
    pkgs.jq
  ];

  # The release gate, as a DAG rather than a script: name the endpoint and
  # devenv runs everything upstream of it.
  #
  #   devenv tasks run release:tag --input tag=v1.2.0
  #
  # `release:vm` builds x86_64-linux VM tests, so a full release runs on Linux
  # (the radicle builder), not on a darwin workstation. The earlier tasks are
  # platform-independent and are worth running anywhere:
  #
  #   devenv tasks run release:check
  tasks = {
    # Fast gate. `nix flake check` covers formatting too (treefmt.nix wires
    # statix and deadnix into the `formatting` check precisely so the two
    # cannot disagree), but that takes minutes and this takes seconds, so it
    # runs first and fails first.
    #
    # --ci implies --no-cache --fail-on-change: report drift, never rewrite the
    # tree mid-release.
    "release:fmt" = {
      exec = "nix fmt -- --ci";
      execIfModified = [
        "**/*.nix"
        "**/*.sh"
        "**/*.yml"
        "**/*.yaml"
      ];
    };

    "release:check" = {
      exec = "nix flake check --print-build-logs";
      after = [ "release:fmt" ];
    };

    # The heavy booting tests flake.nix deliberately keeps OUT of `checks` so
    # that `nix flake check` stays light and KVM-free. A release is exactly the
    # moment to pay for them.
    "release:vm" = {
      exec = ''
        set -euo pipefail
        for t in vm-system vm-login vm-radicle; do
          echo "==> tests.x86_64-linux.$t"
          nix build --no-link --print-build-logs ".#tests.x86_64-linux.$t"
        done
      '';
      after = [ "release:check" ];
    };

    # Signed tag, then push. The remote is an input rather than a literal:
    # this tree is moving off GitHub and onto radicle, and when it lands the
    # cutover should be `--input remote=rad`, not an edit here.
    "release:tag" = {
      exec = ''
        set -euo pipefail

        tag=$(printf '%s' "$DEVENV_TASK_INPUT" | jq -r '.tag // empty')
        remote=$(printf '%s' "$DEVENV_TASK_INPUT" | jq -r '.remote // "origin"')

        if [ -z "$tag" ]; then
          echo "release:tag needs a tag:" >&2
          echo "  devenv tasks run release:tag --input tag=v1.2.0" >&2
          exit 1
        fi

        if [ -n "$(git status --porcelain)" ]; then
          echo "refusing to tag a dirty tree; commit or stash first" >&2
          exit 1
        fi

        if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
          echo "tag $tag already exists" >&2
          exit 1
        fi

        git tag -s "$tag" -m "release $tag"
        git push "$remote" "$tag"
        echo "pushed $tag to $remote"
      '';
      input.remote = "origin";
      after = [ "release:vm" ];
    };
  };
}
