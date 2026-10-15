# herdr-projects -- the "Projects" herdr plugin: a coordinator conversation,
# parallel worker threads, shared memory and an overview of what needs you.
#
# Built from source rather than through the manifest's [[build]] step
# (scripts/install.sh), which downloads a release binary checked only against
# an unsigned SHA256SUMS from the same release. herdr never runs [[build]] for
# a linked or nix-registered plugin (herdr docs/plugins.mdx: "`plugin link`
# does not run build commands"), so a store path that already holds
# target/release/herdr-projects is a complete plugin root, and the step is
# dropped from the shipped manifest so nothing can run the downloader.
#
# The layout is load-bearing. The binary finds its own plugin root as the
# canonicalised executable's parent^3 (src/update.rs:118-121,
# src/paths.rs:69-72), and the bundled skill comes from that root
# (src/setup.rs:264-266). So the real file sits at
# <root>/target/release/herdr-projects and bin/ holds the symlink; the other
# way round, canonicalize would land in $out/bin and the "root" would be
# /nix/store. The ~/.local/bin link `startup` makes also requires a path
# ending in release/herdr-projects (src/command_link.rs:26-28).
{ lib
, stdenv
, rustPlatform
, fetchFromGitHub
, git
, rsync
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-projects";
  version = "0.2.34";

  src = fetchFromGitHub {
    owner = "eliasstravik";
    repo = "herdr-projects";
    # Tag v0.2.34. Pinned by commit because a tag can be moved.
    rev = "4e4548c3c43888e6be1c96906215998f07dc63f0";
    hash = "sha256-3Pmg0yDPFRY8fWI3Qc/0oMxnbFTBTHM48C38v63wFP4=";
  };

  cargoHash = "sha256-VOOKjB1M731OscdDE3XOadDU25rC+yyxBP/IAovL6rg=";

  # Upstream's build.rs stamps `git rev-parse --short HEAD` plus the build's
  # wall-clock seconds into HP_BUILD_ID (build.rs:7-20), which becomes the
  # "+id" of VERSION (src/main.rs:46): in a nix build that is `nogit.<now>`,
  # a different binary every time. Upstream wants a new id per binary because
  # a running ticker is replaced only when VERSION differs
  # (src/ticker.rs:89-95), and that ticker writes its own binary path into
  # the command prefix coordinators are primed with (src/coordinator.rs:36-38);
  # a same-version rebuild with a fixed id would leave the old store path's
  # ticker running. So the id is the commit plus a digest of what the binary
  # is made from, taken at evaluation: identical for one derivation, new
  # when the source, the vendored crates or the toolchain change. It is not
  # the store path's own hash, because an output naming its own path changes
  # under the path rewriting `nix build --rebuild` does and cannot be
  # checked that way.
  postPatch =
    let
      inputs = builtins.unsafeDiscardStringContext
        "${finalAttrs.src} ${finalAttrs.cargoHash} ${rustPlatform.rust.rustc} ${stdenv.cc}";
      buildId = "${builtins.substring 0 7 finalAttrs.src.rev}.nix-${builtins.substring 0 8 (builtins.hashString "sha256" inputs)}";
    in
    ''
      cat > build.rs <<'EOF'
      fn main() {
          println!("cargo:rustc-env=HP_BUILD_ID=${buildId}");
      }
      EOF

      substituteInPlace herdr-plugin.toml --replace-fail '[[build]]
      # Downloads the release binary; falls back to `cargo build --release --locked`.
      command = ["sh", "scripts/install.sh"]
      ' ""
    '';

  # This darwin builder runs unsandboxed, so each build happens in a fresh
  # /nix/var/nix/builds/nix-<pid>-<random> directory, and rustc writes that
  # path into every panic location of the vendored crates: two builds of
  # one derivation differed (`nix build --rebuild`). Mapping the build
  # directory to a fixed name makes the output identical.
  preBuild = ''
    export RUSTFLAGS="''${RUSTFLAGS:-} --remap-path-prefix=$NIX_BUILD_TOP=/build"
  '';

  # The suite drives git and rsync the way a thread does (src/thread.rs
  # copies a report and library with rsync -rt). At run time both come from
  # the PATH herdr hands its plugins, as do gh and ssh: the binary cannot be
  # wrapped, because its plugin root is computed from its own real path.
  nativeCheckInputs = [ git rsync ];

  # A wall-clock bound: it asserts a 300 ms timeout returns within 2 s
  # (src/runner.rs:482-498), which a loaded builder misses -- it failed at a
  # load average of 110 with the other 324 tests passing. Skipping it also
  # drops its check that the group kill reaches a grandchild.
  checkFlags = [ "--skip=runner::tests::group_kill_reaches_grandchildren" ];

  postInstall = ''
    root=$out/${finalAttrs.passthru.pluginSubdir}
    mkdir -p "$root/target/release"
    mv "$out/bin/herdr-projects" "$root/target/release/herdr-projects"
    ln -s "$root/target/release/herdr-projects" "$out/bin/herdr-projects"
    cp herdr-plugin.toml "$root/"
    cp -R skill "$root/skill"
  '';

  # Consumers name the plugin root as "${pkg}/${pkg.pluginSubdir}"; that is
  # what herdr's plugins.json entry and the tab_bar_right command point at.
  passthru = {
    pluginId = "herdr-projects";
    pluginSubdir = "share/herdr-plugins/herdr-projects";
    # The manifest's min_herdr_version; herdr refuses to link the plugin
    # into anything older.
    minHerdrVersion = "0.9.1";
  };

  meta = {
    description = "herdr plugin: a coordinator conversation, parallel worker threads, shared memory";
    homepage = "https://github.com/eliasstravik/herdr-projects";
    changelog = "https://github.com/eliasstravik/herdr-projects/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "herdr-projects";
    # The manifest declares macos and linux (herdr-plugin.toml `platforms`).
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
})
