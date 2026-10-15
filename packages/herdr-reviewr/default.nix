# herdr-reviewr -- a review pane beside the agent: browse its diff, leave
# line comments, paste them into the agent's input.
#
# Built from source instead of the manifest's [[build]], `bash
# herdr/install.sh`, which downloads the release binary from GitHub and
# checks it only against a sha256 sidecar from the same release. herdr runs
# [[build]] only on a GitHub `plugin install`, never for a linked or local
# root (herdr docs/plugins.mdx "Build commands", v0.9.5), and herdr/ is left
# out of the root below, so nothing here can reach that download.
#
# Layout is load-bearing. Every manifest command is the relative argv
# `bin/herdr-reviewr`, resolved against the plugin root, so the REAL file
# sits at <root>/bin and $out/bin is the symlink.
{ lib
, rustPlatform
, fetchFromGitHub
, git
, python3
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-reviewr";
  version = "0.46.0";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    # v0.46.0 is commit 859dd5b11a5280fe282de56b52378b20a54fa10a
    tag = "v${finalAttrs.version}";
    hash = "sha256-KJNzp6e7Uy3E1teheD/dMpB5Zqw7dqxEGnjJqvJgYaE=";
  };

  cargoHash = "sha256-v7GFjRE2Zw6HWpD5Pl7Pd8+PNz7Lb05dvsnFJshFtLE=";

  patches = [
    # Every action re-points two symlinks at $HERDR_PLUGIN_ROOT/bin
    # (src/actions.rs, repoint_launch_links): ~/.local/bin/herdr-reviewr
    # whenever ~/.local/bin exists, and one under
    # ~/.local/state/herdr/plugins/persiyanov.reviewr/bin. Here that root is
    # a store path, so both would be unmanaged links into the store that
    # dangle after a garbage collection, and the first one lands in a PATH
    # directory the user owns. Put this package's bin/ on PATH instead;
    # layouts name `herdr-reviewr` by bare name.
    ./no-launch-links.patch
  ];

  nativeCheckInputs = [ git ];

  # The suite treats its own checkout as a repository: tests/comment_shape.rs
  # runs `git ls-files` on it and fails on an empty listing, and
  # tests/pane_actions.rs opens reviewr on it (27 of its 58 fail without a
  # .git). The fetched tarball has none, so give it one.
  preCheck = ''
    git init --quiet
    git add --all
    git -c user.name=nix -c user.email=nix@localhost commit --quiet --message source
  '';

  # The build is unsandboxed on darwin, so the suite shares the machine with
  # whatever else is running, and these tests measure wall-clock time.
  # Built 2026-10-15 on this Mac: a_held_lock_holds_back_only_its_own_workspace
  # took over its 5 s bound at load ~11-23, and the three turn tests failed
  # once inside the full app_flow run at load ~50-60, though each passed 5/5
  # alone with and without .git. The other four pane_actions/watch tests
  # assert the same kind of `elapsed() <` bound. A check phase that fails by
  # load would fail a rebuild at random, so they are skipped; the other
  # ~1150 tests run.
  checkFlags = map (name: "--skip=${name}") [
    # Asserts the links the patch above removes.
    "an_action_repoints_the_stable_launch_paths_at_the_live_plugin_root"
    # Wall-clock bounds (tests/pane_actions.rs, tests/watch.rs).
    "a_held_lock_holds_back_only_its_own_workspace"
    "an_open_whose_pane_dies_at_launch_refuses_at_once"
    "auto_open_gives_way_to_a_held_lock"
    "workspace_ids_differing_only_in_case_hold_separate_locks"
    "a_watcher_that_cannot_start_restarts_and_asks_for_everything"
    # Turn baselines keyed on Instant::now() (tests/app_flow.rs).
    "a_question_only_turns_snapshot_expires_at_its_end"
    "a_question_only_turn_keeps_the_previous_turns_diff"
    "a_write_racing_the_start_snapshot_empties_the_turn_and_says_why"
  ];

  postInstall = ''
    root=$out/${finalAttrs.passthru.pluginSubdir}
    mkdir -p "$root/bin"
    mv "$out/bin/herdr-reviewr" "$root/bin/herdr-reviewr"
    ln -s "$root/bin/herdr-reviewr" "$out/bin/herdr-reviewr"
    cp herdr-plugin.toml LICENSE "$root/"

    # passthru repeats the manifest's id, version and herdr floor so a
    # consumer can register and gate the plugin without reading the store
    # at evaluation time; this fails the build when they drift.
    grep -Fxq 'id = "${finalAttrs.passthru.pluginId}"' herdr-plugin.toml
    grep -Fxq 'version = "${finalAttrs.version}"' herdr-plugin.toml
    grep -Fxq 'min_herdr_version = "${finalAttrs.passthru.minHerdrVersion}"' herdr-plugin.toml
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  # The binary has no --version: with no `--action` it starts the TUI
  # (src/main.rs), so it is not run here. The manifest check proves every
  # relative command herdr will run exists and is executable under the
  # root, which is what a wrong layout would break.
  installCheckPhase = ''
    runHook preInstallCheck
    python3 - "$out/${finalAttrs.passthru.pluginSubdir}" <<'EOF'
    import os, sys, tomllib
    root = sys.argv[1]
    with open(os.path.join(root, "herdr-plugin.toml"), "rb") as f:
        manifest = tomllib.load(f)
    commands = [
        entry["command"]
        for table in ("startup", "actions", "events", "panes")
        for entry in manifest.get(table, [])
    ]
    assert commands, "manifest names no runtime command"
    for argv in commands:
        path = os.path.join(root, argv[0])
        assert os.access(path, os.X_OK), f"{argv[0]} is not executable under {root}"
    assert not os.path.exists(os.path.join(root, "herdr")), "the downloading installer is in the root"
    print(f"manifest ok: {len(commands)} commands resolve under {root}")
    EOF
    runHook postInstallCheck
  '';

  passthru = {
    pluginId = "persiyanov.reviewr";
    pluginSubdir = "share/herdr-plugins/herdr-reviewr";
    minHerdrVersion = "0.9.3";
  };

  meta = {
    description = "herdr plugin: review an agent's diff beside the chat and send line comments to its input";
    homepage = "https://github.com/persiyanov/herdr-reviewr";
    license = lib.licenses.mit;
    mainProgram = "herdr-reviewr";
    platforms = lib.platforms.unix;
  };
})
