# baud: the terminal's config.toml, owned by home-manager, the way wezterm.lua
# is (../wezterm).
#
# For a vogix user the [palette] names vogix's two theme links, which baud
# resolves in ~/.config/baud/themes/: vogix links them into its current theme
# and `touch -h`es them after every apply, which is what baud's watch hears (a
# re-pointed current-theme alone is not). baud's own light/dark follows the
# portal, so both are named. A palette in `settings` wins over these.
#
# The file is written only when there is something in it. Otherwise baud's
# own first-launch file, every key commented, stays as it is. When it is
# written, it replaces that file (force): baud never rewrites a config that
# exists, so there is no fight afterwards, and a hand edit is replaced on the
# next switch.
#
# `package` defaults to null and installs nothing: baud is not a mynixos
# input.
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.terminals.baud";
  option = {
    name = "baud";
    default = false;
    description = "baud terminal";
    persistedDirectories = [ ];
    extraOptions = {
      package = args.lib.mkOption {
        type = args.lib.types.nullOr args.lib.types.package;
        default = null;
        description = "The baud package to install, or null to manage only its config.";
      };
      settings = args.lib.mkOption {
        type = args.lib.types.attrsOf args.lib.types.anything;
        default = { };
        example = { screen.notifications = "on"; };
        description = "baud's config.toml, as TOML-shaped attributes. Keys baud does not know are reported by baud.";
      };
    };
  };
  home = { cfg, userCfg, pkgs, lib, ... }:
    let
      vogixOn = userCfg.theming.vogix.enable or false;
      settings = lib.recursiveUpdate
        (lib.optionalAttrs vogixOn { palette = { dark = "vogix-dark"; light = "vogix-light"; }; })
        cfg.settings;
    in
    {
      home.packages = lib.optional (cfg.package != null) cfg.package;

      xdg.configFile."baud/config.toml" = lib.mkIf (settings != { }) {
        source = (pkgs.formats.toml { }).generate "baud-config.toml" settings;
        force = true;
      };
    };
}
