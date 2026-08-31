# babysitter -- the a5c-ai run-orchestration CLI used by the Claude Code
# plugin of the same name.
#
# Packaged rather than `npm i -g`: this fleet has no node on PATH and the npm
# prefix lives in the read-only nix store, so a global install would either
# fail or need an unmanaged ~/.npm-global. The plugin's own fallback
# (`npm exec --package @a5c-ai/babysitter-sdk@<v>`) works, but it resolves
# through a mutable ~/.npm cache at first use -- unpinned and offline-hostile.
# Building it here makes `babysitter` a real, version-pinned binary in the
# user profile, which is also what makes it available in EVERY repo rather
# than one project's dev shell.
#
# Same shape as my/ai/openclaw: an npm-registry tarball ships no lockfile, so
# one is generated once and vendored beside this file. Regenerate both it and
# npmDepsHash together when bumping `version`:
#
#   nix store prefetch-file https://registry.npmjs.org/@a5c-ai/babysitter-sdk/-/babysitter-sdk-<v>.tgz
#   tar xzf <store path> && cd package
#   npm install --package-lock-only --ignore-scripts --legacy-peer-deps
#   cp package-lock.json <here>/package-lock.json
#   # then build once and take the hash nix reports
#
# The plugin pins the SDK version in its versions.json (6.0.3 for plugin
# 6.0.3); keep `version` below in step with the plugin you have installed, or
# the CLI and the skill's instructions can disagree.
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "ai.tools.babysitter";
  option = {
    name = "babysitter";
    default = false;
    description = "babysitter run-orchestration CLI (a5c-ai)";
    # ~/.babysitter holds cross-run state; .a5c/ lives inside each repo and is
    # persisted by whatever persists that repo.
    persistedDirectories = [ ".babysitter" ];
  };
  home = { pkgs, ... }:
    let
      version = "6.0.3";

      babysitter = pkgs.buildNpmPackage {
        pname = "babysitter-sdk";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@a5c-ai/babysitter-sdk/-/babysitter-sdk-${version}.tgz";
          hash = "sha256-1KVDiXvX0axpGhtFBWFwsNCPvGutVUIDehHs9PGmiK8=";
        };

        sourceRoot = "package";

        # npm registry tarballs carry no lockfile; buildNpmPackage requires one.
        postPatch = ''
          cp ${./package-lock.json} package-lock.json
        '';

        npmDepsHash = "sha256-zAz2ZYA22Cqn1rxWb26KK+ubK+mF7SZm1S3PTMmbgao=";

        # `dist/` is prebuilt in the published tarball, so there is nothing to
        # compile and no install scripts worth running.
        dontNpmBuild = true;
        makeCacheWritable = true;
        npmFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];

        nativeBuildInputs = [ pkgs.makeWrapper ];

        # The package declares five bins off one dist tree; wrap the two that
        # are actually driven by hand (the skill calls `babysitter`, the MCP
        # server is what the plugin registers).
        postInstall = ''
          mkdir -p $out/bin
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/babysitter \
            --add-flags "$out/lib/node_modules/@a5c-ai/babysitter-sdk/dist/cli/main.js"
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/babysitter-mcp-server \
            --add-flags "$out/lib/node_modules/@a5c-ai/babysitter-sdk/dist/cli/mcpServeEntry.js"
        '';

        meta = {
          description = "babysitter SDK / run-orchestration CLI";
          mainProgram = "babysitter";
        };
      };
    in
    {
      # jq is a hard dependency of the babysit skill's own instructions, so it
      # travels with the CLI rather than being assumed.
      home.packages = [ babysitter pkgs.jq ];
    };
}
