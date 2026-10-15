# herdr-focus-notify -- a clickable macOS notification when an agent pane
# turns `blocked` or `done`; clicking it focuses that pane.
#
# Built from source instead of the manifest's [[build]] (`cargo build
# --release` in the plugin root): herdr runs [[build]] only on a GitHub
# `plugin install`, never for a linked or local root (herdr docs/plugins.mdx
# "Build commands", v0.9.5), so a store path that already holds the binary
# where the manifest's commands name it is a complete plugin root.
#
# Layout is load-bearing. Every manifest command is the relative argv
# `target/release/herdr-focus-notify`, resolved against the plugin root, so
# the REAL file sits there and bin/ is the symlink. The binary also writes
# its own `current_exe()` into the click scripts it generates
# (src/script.rs), which therefore name this store path.
#
# Runtime requirement this package cannot provide: `alerter`
# (vjeantet/alerter), which draws the notification. It is not in nixpkgs,
# its Package.swift needs swift-tools 6.1 where nixpkgs has 5.10, and its
# Homebrew tap ships a prebuilt zip. The plugin looks for it on PATH, then
# /opt/homebrew/bin, /usr/local/bin and ~/.local/bin (src/notifier.rs); with
# none found every notification fails with "no alerter notifier found".
# terminal-notifier is no substitute: the click path depends on alerter's
# --actions, --close-label, --remove and @ACTIONCLICKED output.
{ lib
, rustPlatform
, fetchFromGitHub
, python3
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-focus-notify";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "yankewei";
    repo = "herdr-focus-notify";
    # One commit past v0.8.0; it only deletes agent configuration
    # (.agents/, .commandcode/), so src/, Cargo.* and the manifest are
    # v0.8.0's.
    rev = "94e8e1394e1bdbaa3dd55d4d83e0e3f98ecab743";
    hash = "sha256-LFK8660lhbdtz/p7+yoigmC6KJz8s1l0ulqYyKks8Fw=";
  };

  cargoHash = "sha256-cbxDZOvKLeEZ3raq1nMGioOv3+0ZLXNkAQ/wP2oLazQ=";

  postInstall = ''
    root=$out/${finalAttrs.passthru.pluginSubdir}
    mkdir -p "$root/target/release" "$root/assets/icons"
    mv "$out/bin/herdr-focus-notify" "$root/target/release/herdr-focus-notify"
    ln -s "$root/target/release/herdr-focus-notify" "$out/bin/herdr-focus-notify"
    cp herdr-plugin.toml "$root/"
    # The icons are compiled in (include_bytes!, src/icons.rs); their
    # licence notice travels with the root.
    cp assets/icons/NOTICE.md "$root/assets/icons/"

    # passthru repeats the manifest's id, version and herdr floor so a
    # consumer can register and gate the plugin without reading the store
    # at evaluation time; this fails the build when they drift.
    grep -Fxq 'id = "${finalAttrs.passthru.pluginId}"' herdr-plugin.toml
    grep -Fxq 'version = "${finalAttrs.version}"' herdr-plugin.toml
    grep -Fxq 'min_herdr_version = "${finalAttrs.passthru.minHerdrVersion}"' herdr-plugin.toml
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  # `--version` returns before any I/O (src/main.rs). The manifest check
  # proves every relative command herdr will run exists and is executable
  # under the root, which is what a wrong layout would break.
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/herdr-focus-notify" --version | grep -Fx "herdr-focus-notify ${finalAttrs.version}"
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
    print(f"manifest ok: {len(commands)} commands resolve under {root}")
    EOF
    runHook postInstallCheck
  '';

  passthru = {
    pluginId = "herdr-focus-notify";
    pluginSubdir = "share/herdr-plugins/herdr-focus-notify";
    minHerdrVersion = "0.7.5";
  };

  meta = {
    description = "herdr plugin: clickable macOS notifications that focus the blocked or finished agent pane";
    homepage = "https://github.com/yankewei/herdr-focus-notify";
    # Cargo.toml declares `license = "MIT"`, but the repository carries no
    # LICENSE file at this commit; the bundled icons are MIT per
    # assets/icons/NOTICE.md.
    license = lib.licenses.mit;
    mainProgram = "herdr-focus-notify";
    # The manifest says platforms = ["macos"]: lsappinfo, `open -b` and
    # alerter are macOS-only.
    platforms = lib.platforms.darwin;
  };
})
