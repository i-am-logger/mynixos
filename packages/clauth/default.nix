# clauth -- Claude Code multi-account manager and 5h/7d usage monitor, CLI +
# TUI, with a herdr plugin in its herdr-plugin/ directory.
#
# The whole source tree is built, plugins/ included: build.rs fails unless
# plugins/.claude-plugin/plugin.json carries the crate's version
# (build.rs:14-18, agentgear), and the Claude Code plugin is embedded in the
# binary from that tree.
#
# Self-update is off. clauth replaces its own binary from GitHub releases and
# reinstalls its herdr plugin from GitHub over whatever is registered unless
# CLAUTH_NO_UPDATE=1 (src/update.rs:58-64, src/herdr.rs:774-786); its only
# "installed by a package manager" test is ~/.cargo/bin (src/update.rs:288),
# so from a store path it would poll GitHub and try to self_replace a
# read-only file. CLAUTH_NO_COMPLETIONS=1 stops the first TUI launch offering
# to append a `source` line to the shell rc; the completions are generated
# here instead.
#
# The wrapper is a compiled one (makeBinaryWrapper) in front of a real binary
# still named `clauth`, because clauth recognises its own processes by name:
# the daemon API takes a pane's session from a process named exactly
# `clauth` (src/daemon/api/panes.rs:324-326), `daemon --replace` checks
# argv0's basename (src/daemon/probe.rs:661-668), and the herdr plugin skips
# delegate runs by matching `ps` args against `clauth mcp`
# (herdr-plugin/report-profile.sh:68,207). wrapProgram would rename the
# binary to .clauth-wrapped and, as a shell script, hand on its full store
# path as argv0; --inherit-argv0 passes on exactly what the caller used.
{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, makeBinaryWrapper
, installShellFiles
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "clauth";
  version = "0.17.0";

  src = fetchFromGitHub {
    owner = "uwuclxdy";
    repo = "clauth";
    # Tag v0.17.0, not the default branch: `mommy` runs well past the tag
    # with the same Cargo version, so a branch pin would drift silently.
    # Pinned by commit because a tag can be moved.
    rev = "800202771cfc7d0a5db4c277ede980aacf68cea6";
    hash = "sha256-hbiBVUMZ0RO1+JqohtlwJ+NpBOl/jOZpkVDdEHShuNs=";
  };

  cargoHash = "sha256-A897WAfqn5YP09b1IKo8wV4avzzjNm6wUJ2tL6hHLE0=";

  # This darwin builder runs unsandboxed, so each build happens in a fresh
  # /nix/var/nix/builds/nix-<pid>-<random> directory, and rustc writes that
  # path into every panic location of the vendored crates, so two builds of
  # one derivation differ (measured on packages/herdr-projects with
  # `nix build --rebuild`). Mapping the build directory to a fixed name
  # removes that difference.
  preBuild = ''
    export RUSTFLAGS="''${RUSTFLAGS:-} --remap-path-prefix=$NIX_BUILD_TOP=/build"
  '';

  nativeBuildInputs = [ makeBinaryWrapper installShellFiles ];

  # Off, measured: on this darwin builder 38 tests failed and 4840 passed
  # (11 ignored). All 38 are in the daemon, gateway and proxy supervision
  # paths, which read processes through `ps` and the host name through
  # `hostname` ("ps: command not found", "could not run `hostname`"), and
  # a nix build's PATH carries neither. Upstream CI runs the suite on
  # macos-latest (.github/workflows/ci.yml:68-76), and the tests that would
  # drive the real Keychain are #[ignore]d there
  # (tests/inline/keychain.rs:1-13).
  doCheck = false;

  postInstall = ''
    mkdir -p "$out/libexec/clauth"
    mv "$out/bin/clauth" "$out/libexec/clauth/clauth"
    makeWrapper "$out/libexec/clauth/clauth" "$out/bin/clauth" \
      --inherit-argv0 \
      --set CLAUTH_NO_UPDATE 1 \
      --set CLAUTH_NO_COMPLETIONS 1

    # The herdr plugin root. Its pane runs bare `clauth` and its scripts call
    # bare `clauth` (herdr-plugin/README.md, "Requires: clauth on PATH");
    # herdr starts them with the server's PATH and no shell profile. Pin both
    # to this output, so the plugin never runs whatever clauth PATH finds.
    root=$out/${finalAttrs.passthru.pluginSubdir}
    mkdir -p "$root"
    cp herdr-plugin/herdr-plugin.toml herdr-plugin/*.sh herdr-plugin/README.md "$root/"
    substituteInPlace "$root/herdr-plugin.toml" \
      --replace-fail 'command = ["clauth"]' "command = [\"$out/bin/clauth\"]"
    for script in "$root"/*.sh; do
      sed -i "1a PATH=\"$out/bin:\$PATH\"; export PATH" "$script"
    done
  '' + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    # The scripts are static templates (src/completions.rs:417-427); profile
    # names are completed at run time through `clauth __complete`.
    for shell in bash zsh fish; do
      HOME=$TMPDIR "$out/bin/clauth" completions "$shell" > "clauth.$shell"
    done
    installShellCompletion clauth.{bash,zsh,fish}
  '';

  # Consumers name the plugin root as "${pkg}/${pkg.pluginSubdir}"; that is
  # what herdr's plugins.json entry points at.
  passthru = {
    pluginId = "clauth";
    pluginSubdir = "share/herdr-plugins/clauth";
    # herdr-plugin/herdr-plugin.toml min_herdr_version.
    minHerdrVersion = "0.8.0";
  };

  meta = {
    description = "Claude Code multi-account manager and usage monitor";
    homepage = "https://github.com/uwuclxdy/clauth";
    changelog = "https://github.com/uwuclxdy/clauth/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "clauth";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
})
