# Hypr-vogix implementation module
# Installs hypr-vogix and configures auto-restore on Hyprland startup
{ config
, lib
, pkgs
, hypr-vogix
, ...
}:

with lib;

let
  cfg = config.my.themes.hypr-vogix;

  # Build the exec-once command with configured defaults
  restoreCmd = concatStringsSep " " ([
    "${pkgs.hypr-vogix}/bin/hypr-vogix"
    "--restore"
    "--theme"
    cfg.defaultTheme
    "--opacity"
    (toString cfg.defaultOpacity)
    "--brightness"
    (toString cfg.defaultBrightness)
    "--saturation"
    (toString cfg.defaultSaturation)
  ] ++ optionals (cfg.defaultInvert != null) [
    "--invert"
    cfg.defaultInvert
  ]);
in
{
  config = mkMerge [
    # Overlay and unfree allowlist always set (predicate must exist before package evaluation)
    {
      nixpkgs.overlays = [ hypr-vogix.overlays.default ];
      my.system.allowedUnfreePackages = [ "hypr-vogix" ];
    }

    # Per-user config only when enabled
    (mkIf (config.my.themes.enable && cfg.enable) {
      home-manager.users = mapAttrs
        (_name: userCfg:
          mkIf (userCfg.graphical.enable or false) {
            home.packages = [ pkgs.hypr-vogix ];

            # Auto-restore overlay on Hyprland startup
            wayland.windowManager.hyprland.settings.exec-once = [ restoreCmd ];
          })
        config.my.users;

      # Persist state directory for impermanence systems
      environment.persistence = mkIf config.my.storage.impermanence.enable {
        ${config.my.storage.impermanence.persistPath}.users = mapAttrs
          (_name: userCfg:
            mkIf (userCfg.graphical.enable or false) {
              directories = [ ".local/state/hypr-vogix" ];
            })
          config.my.users;
      };
    })
  ];
}
