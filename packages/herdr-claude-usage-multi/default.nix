# herdr-claude-usage-multi -- a herdr plugin that puts each Claude account's
# 5-hour and weekly plan usage on the sidebar's Spaces rows.
#
# One stdlib-only Python file (monitor.py imports nothing outside the
# standard library), so the only thing to pin is the interpreter. The
# manifest runs `python3` through herdr's PATH (argv, no shell: herdr
# docs/plugins.mdx "Manifest"); every command is rewritten to a wrapper
# around this package's python3. The daemon re-spawns itself through
# sys.executable (monitor.py cmd_ensure) and inherits the wrapper's
# environment.
#
# The wrapper sets SSL_CERT_FILE because the plugin's one network call, to
# api.anthropic.com, goes through urllib. Nix's python3 otherwise looks for
# its CA bundle in /nix/var/nix/profiles/default, which is host state: where
# that file is missing every fetch fails, and the gauge reads "No usage
# data", the same as a logged-out account. --set-default keeps a caller's
# own SSL_CERT_FILE.
#
# Account discovery is upstream's, unchanged. Where clauth switches the
# login in ~/.claude, the default account is whichever profile clauth has
# active; clauth's other profiles live in ~/.clauth/profiles/<name>/
# credentials.json, which no accounts.json entry can name (monitor.py reads
# `<config_dir>/.credentials.json` and a Keychain item clauth does not
# write), so they show only once clauth makes them active.
{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, cacert
, makeWrapper
}:

stdenvNoCC.mkDerivation {
  pname = "herdr-claude-usage-multi";
  # herdr-plugin.toml's version; upstream tags no releases.
  version = "0.2.2-unstable-2026-09-04";

  src = fetchFromGitHub {
    owner = "iamhouser";
    repo = "herdr-claude-usage-multi";
    rev = "c0acb14392e97a63a5aceb9399a991d091e0b1cf";
    hash = "sha256-sMC4gjSFSDcHN9YZXfe12fXNOnrS/Y02zmYJjbPZkVM=";
  };

  nativeBuildInputs = [ makeWrapper python3 ];

  dontBuild = true;

  # Rendering, ageing and per-account backoff, against a faked herdr CLI and
  # fetch; no network, no Keychain.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME=$TMPDIR/home
    mkdir -p "$HOME"
    python3 -m unittest discover -s tests -v
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    root=$out/share/herdr-plugins/herdr-claude-usage-multi
    mkdir -p "$root"
    cp monitor.py herdr-plugin.toml LICENSE README.md "$root/"

    makeWrapper ${lib.getExe python3} "$root/bin/python3" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"

    substituteInPlace "$root/herdr-plugin.toml" \
      --replace-fail 'command = ["python3",' "command = [\"$root/bin/python3\","
    if grep -n '"python3"' "$root/herdr-plugin.toml"; then
      echo "herdr-plugin.toml still runs a bare python3" >&2
      exit 1
    fi
    runHook postInstall
  '';

  # Consumers name the root as "${pkg}/${pkg.pluginSubdir}"; a placeholder
  # would not be substituted inside passthru.
  passthru = {
    pluginId = "houser.claude-usage";
    pluginSubdir = "share/herdr-plugins/herdr-claude-usage-multi";
    minHerdrVersion = "0.7.5";
  };

  meta = {
    description = "herdr plugin: Claude plan usage gauges on the Spaces rows, per account";
    homepage = "https://github.com/iamhouser/herdr-claude-usage-multi";
    license = lib.licenses.mit;
    # It reads the login from the macOS Keychain, or from
    # <config dir>/.credentials.json elsewhere (monitor.py oauth_token).
    platforms = lib.platforms.unix;
  };
}
