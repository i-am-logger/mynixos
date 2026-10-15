# herdr-radar -- a herdr plugin that groups the sidebar's agents by project,
# marks each with its vendor's logo and says which are waiting on you.
#
# Pure JavaScript on Node's standard library. package-lock.json holds one
# package, prettier, and only as a devDependency for `npm run format`, so
# there is nothing to vendor; the build asserts that, so a release that adds
# a runtime dependency fails here instead of shipping without it.
#
# Every manifest command is `["node", ...]`, which herdr runs through its own
# PATH (argv, no shell: herdr docs/plugins.mdx "Manifest"). Pinning
# `node` to the store path makes the runtime this package's; the daemon
# re-spawns its helpers through process.execPath (lib/spawn.js), so the pin
# carries through.
#
# `herdr plugin link` never runs [[build]] (herdr docs/plugins.mdx "Build
# commands"), so `bin/setup.js` only runs when called. The daemon launcher
# calls the same setup on every start, though; see no-automatic-setup.patch.
{ lib
, stdenvNoCC
, fetchFromGitHub
, nodejs
, jq
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-radar";
  version = "1.4.4";

  src = fetchFromGitHub {
    owner = "hhdebb";
    repo = "herdr-radar";
    tag = "v${finalAttrs.version}";
    # v1.4.4 is commit dd42772da4b8b9e18660d653d08149c7da1d2964
    hash = "sha256-aFQqPFSNG33Ois2niAwKrQXqNWgNqreO282PdXSzSEw=";
  };

  patches = [
    # The daemon launcher (bin/agent-state.js) runs lib/setup.js ensure() on
    # every start until it writes a stamp: it writes the managed blocks into
    # herdr's config.toml, copies the icon font into the user font directory
    # and appends a codepoint map to any ghostty/kitty config it finds. Under
    # Nix all three are the configuration's to declare. This keeps only the
    # explicit `node bin/setup.js --force` path.
    ./no-automatic-setup.patch
  ];

  nativeBuildInputs = [ jq nodejs ];

  postPatch = ''
    if jq -e '.packages | to_entries | any(.key != "" and (.value.dev // false) == false)' \
        package-lock.json >/dev/null; then
      echo "package-lock.json now has a runtime dependency; vendor it" >&2
      exit 1
    fi

    substituteInPlace herdr-plugin.toml \
      --replace-fail 'command = ["node",' 'command = ["${lib.getExe nodejs}",'
    if grep -n '"node"' herdr-plugin.toml; then
      echo "herdr-plugin.toml still runs a bare node" >&2
      exit 1
    fi
  '';

  dontBuild = true;

  # The suite is Node's built-in runner plus the repository's invariant
  # checks; neither needs herdr or the network. HOME and the XDG dirs point
  # into the build tree so nothing reads or writes a real home.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME=$TMPDIR/home XDG_CONFIG_HOME=$TMPDIR/xdg-config \
      XDG_STATE_HOME=$TMPDIR/xdg-state XDG_DATA_HOME=$TMPDIR/xdg-data
    mkdir -p "$HOME"
    node tools/check.js
    node --test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    root=$out/share/herdr-plugins/herdr-radar
    mkdir -p "$root"
    cp -R herdr-plugin.toml package.json bin lib dist shell \
      LICENSE THIRD_PARTY_NOTICES.md README.md "$root/"

    # The icon font, where a font list can name it. The plugin only counts
    # its own hashed copy in ~/Library/Fonts as installed (lib/font.js), so
    # a configuration that installs this one sets the plugin's `variant`.
    install -Dm444 dist/HerdrAgentIconsMax-Regular.ttf \
      "$out/share/fonts/truetype/HerdrAgentIconsMax-Regular.ttf"

    # What `configure` would write into config.toml, per glyph variant and
    # appearance, generated from the plugin's own builders (no herdr, no
    # network): reference text for declaring the same tables in Nix.
    for variant in text font; do
      conf=$TMPDIR/conf-$variant
      mkdir -p "$conf"
      printf 'variant = "%s"\n' "$variant" > "$conf/config.toml"
      (
        cd "$TMPDIR"
        HOME=$TMPDIR/home XDG_STATE_HOME=$TMPDIR/xdg-state \
          HERDR_PLUGIN_CONFIG_DIR=$conf \
          HERDR_PLUGIN_STATE_DIR='@HERDR_PLUGIN_STATE_DIR@' \
          node ${./reference-config.js} "$root" "$variant" \
            "$out/share/herdr-radar/reference-config"
      )
    done
    runHook postInstall
  '';

  # Consumers name the root as "${pkg}/${pkg.pluginSubdir}"; a placeholder
  # would not be substituted inside passthru.
  passthru = {
    pluginId = "hhdebb.herdr-radar";
    pluginSubdir = "share/herdr-plugins/herdr-radar";
    minHerdrVersion = "0.9.0";
  };

  meta = {
    description = "herdr plugin: agents grouped by project, vendor logos, who is waiting on you";
    homepage = "https://github.com/hhdebb/herdr-radar";
    changelog = "https://github.com/hhdebb/herdr-radar/blob/v${finalAttrs.version}/CHANGELOG.md";
    # The code is MIT. dist/JetBrainsMonoHerdr-Regular.ttf is a modified
    # JetBrains Mono under the OFL (THIRD_PARTY_NOTICES.md, dist/OFL.txt).
    license = with lib.licenses; [ mit ofl ];
    platforms = lib.platforms.unix;
  };
})
