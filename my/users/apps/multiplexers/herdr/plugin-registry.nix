# The activation script that keeps herdr's plugin registry in step with the
# plugins a user has switched on. A plain function, not a module: ./default.nix
# and ./darwin.nix both import it by path.
#
# herdr keeps its registry in <config dir>/plugins.json, a file it writes
# itself and snapshots each manifest into (actions, panes, startup). This
# never writes that file. It runs `herdr plugin link <store root>`, which
# validates the manifest, refuses a plugin newer than herdr, creates the
# plugin's config and state directories, and works with or without a running
# server: with none it writes the registry itself (herdr 0.9.5
# src/cli/plugin.rs:50-87, `offline_plugin_link_response`).
#
# It relinks on every package change: link canonicalises the manifest path, so
# linking a stable symlink would still record a store path, which a GC then
# removes. Link is an upsert by plugin id, so it also replaces a GitHub install
# of the same id.
{ lib, pkgs }:

with lib;

let
  herdr = "${pkgs.herdr}/bin/herdr";
  jq = "${pkgs.jq}/bin/jq";
in
{
  # `plugins`: a list of { id, root, enable }. `configHome`/`stateHome` are the
  # user's XDG directories: herdr reads XDG_CONFIG_HOME and XDG_STATE_HOME
  # when they are set (src/config/io.rs:30-42), and activation does not
  # inherit the session's environment, so they are passed explicitly. That
  # keeps the registry herdr writes and the one read here the same file.
  script = { configHome, stateHome, plugins }:
    let
      registry = "${configHome}/herdr/plugins.json";
      runHerdr = args: "run ${pkgs.coreutils}/bin/env XDG_CONFIG_HOME=${escapeShellArg configHome} XDG_STATE_HOME=${escapeShellArg stateHome} ${herdr} ${args}";
      field = id: f: "${jq} -r --arg id ${escapeShellArg id} '.[] | select(.plugin_id == $id) | .${f}' ${escapeShellArg registry} 2>/dev/null || true";

      # Link `root` as `id` unless the registry already records exactly that
      # manifest. A runtime `herdr plugin disable` is kept: link defaults to
      # enabled, so a disabled entry is relinked with --disabled.
      link = { id, root, ... }: ''
        recorded=$(${field id "manifest_path"})
        if [ "$recorded" != ${escapeShellArg "${root}/herdr-plugin.toml"} ]; then
          flag=
          [ "$(${field id "enabled"})" = false ] && flag=--disabled
          # Activation runs under `set -e`; a failed link must not abort the
          # whole switch.
          ${runHerdr "plugin link ${escapeShellArg root} $flag"} >/dev/null \
            || echo "WARNING: herdr plugin link ${id} failed; run it by hand: herdr plugin link ${root}" >&2
        fi
      '';

      # Unlink `id` only when its root is a store path, so only an entry this
      # module made goes; a GitHub install or a checkout linked by hand stays.
      # Unlike link, unlink has no offline path (src/cli/plugin.rs:143-156,
      # `print_plugin_response`): with no herdr server running it fails, and
      # the warning says what to run once one is.
      unlink = { id, ... }: ''
        current=$(${field id "plugin_root"})
        case "$current" in
          ${builtins.storeDir}/*)
            ${runHerdr "plugin unlink ${escapeShellArg id}"} >/dev/null \
              || echo "WARNING: herdr plugin unlink ${id} failed (it needs a running herdr server); run it by hand: herdr plugin unlink ${id}" >&2
            ;;
        esac
      '';
    in
    concatMapStrings (p: if p.enable then link p else unlink p) plugins;

  rootOf = pkg: "${pkg}/${pkg.pluginSubdir}";
}
