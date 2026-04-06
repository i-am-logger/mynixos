{ activeUsers
, config
, lib
, pkgs
, ...
}:

with lib;

let
  bespec = pkgs.callPackage ../../../../../packages/bespec { };

  bespecConfig = vogixEnabled: {
    profile = {
      name = "vogix";
      visual_mode = "SegmentedBars";
      orientation = "BottomUp";
      num_bars = 32;
      bar_gap_px = 4;
      bar_opacity = 1.0;
      segment_height_px = 6.0;
      segment_gap_px = 3.0;
      fill_peaks = false;
      show_peaks = true;
      overlay_font = "Medium";
      sensitivity = 12.0;
      attack_time_ms = 100.0;
      release_time_ms = 100.0;
      peak_hold_time_ms = 200.0;
      peak_release_time_ms = 1000.0;
      aggregation_mode = "Peak";
      retro_coloring = true;
      color_link = if vogixEnabled
        then { Preset = "vogix theme"; }
        else { Preset = "VFD Blue"; };
      beos_enabled = false;
      background = null;
    };
    window_size = [ 800.0 400.0 ];
    window_position = null;
    always_on_top = false;
    window_locked = true;
    window_decorations = false;
    minimize_key = "H";
    show_stats = false;
    inspector_enabled = true;
    log_media_metadata = false;
    selected_device = "Default";
    noise_floor_db = -60.0;
    media_display_mode = "FadeOnUpdate";
    media_fade_duration_sec = 5.0;
    beos_tab_offset = 20.0;
    beos_window_collapsed = false;
  };
in
{
  config = {
    home-manager.users = mapAttrs
      (
        _name: userCfg:
          let
            cfg = userCfg.apps.terminal.visualizers.bespec;
          in
          let
            vogixEnabled = userCfg.theming.vogix.enable or false;
          in
          mkIf cfg.enable {
            home.packages = [ bespec ];

            xdg.configFile."bespec/config.json" = {
              text = builtins.toJSON (bespecConfig vogixEnabled);
              force = true;
            };
          }
      )
      (activeUsers config.my.users);
  };
}
