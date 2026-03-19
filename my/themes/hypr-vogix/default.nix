# Hypr-vogix implementation module
# Installs hypr-vogix and configures auto-restore on Hyprland startup
{ activeUsers
, config
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
  config = mkIf (config.my.themes.enable && cfg.enable) (mkMerge [
    # Overlay and unfree allowlist
    {
      nixpkgs.overlays = [ hypr-vogix.overlays.default ];
      my.system.allowedUnfreePackages = [ "hypr-vogix" ];
    }

    # Per-user config
    {
      home-manager.users = mapAttrs
        (_name: userCfg:
          mkIf (userCfg.graphical.enable or false) {
            home.packages = [ pkgs.hypr-vogix ];

            # Auto-restore overlay on Hyprland startup and after config reload
            wayland.windowManager.hyprland.settings.exec = [ restoreCmd ];
          })
        (activeUsers config.my.users);

      # Persist state directory for impermanence systems
      environment.persistence = mkIf config.my.storage.impermanence.enable {
        ${config.my.storage.impermanence.persistPath}.users = mapAttrs
          (_name: userCfg:
            mkIf (userCfg.graphical.enable or false) {
              directories = [ ".local/state/hypr-vogix" ];
            })
          (activeUsers config.my.users);
      };
    }
  ]);
}
