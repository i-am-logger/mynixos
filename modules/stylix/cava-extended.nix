{ config, lib, ... }:

with lib;

let
  cfg = config.stylix.targets.cava;
  colors = config.lib.stylix.colors;
in
{
  # Extend stylix.targets.cava with additional gradient options
  options.stylix.targets.cava = {
    gradientMode = mkOption {
      type = types.enum [ "rainbow" "vumeter" "custom" ];
      default = "rainbow";
      description = ''
        Gradient mode for cava visualization:
        - rainbow: Full spectrum (magenta → blue → cyan → green → yellow → orange → red)
        - vumeter: VU meter/dB scale (cyan → green → yellow → orange → red)
          Represents audio levels: quiet → normal → loud → clipping
        - custom: Disable automatic gradient (user provides own via programs.cava.settings.color)
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.gradientMode != "custom") {
    programs.cava.settings.color = mkMerge [
      # VU meter gradient mode: Bars show text color → yellow → orange → red vertically
      # 8 gradient steps: [5555yyor] distribution
      # Each color represents bar height (amplitude):
      # - 0-50% height: Text default color (quiet/normal levels) - 4 steps
      # - 50-75% height: Yellow (moderate levels) - 2 steps
      # - 75-87.5% height: Orange (loud/warning) - 1 step
      # - 87.5-100% height: Red (very loud/peaks) - 1 step
      (mkIf (cfg.gradientMode == "vumeter") (mkForce {
        background = "'#${colors.base00}'"; # Stylix background color
        gradient = 1;
        gradient_count = 8;
        # VU meter gradient - bar colors change with HEIGHT (amplitude)
        # Color at bottom of bar (0% height) → top of bar (100% height)
        gradient_color_1 = "'#${colors.base05}'"; # 0-12.5% - Text color (bottom/quiet)
        gradient_color_2 = "'#${colors.base05}'"; # 12.5-25% - Text color
        gradient_color_3 = "'#${colors.base05}'"; # 25-37.5% - Text color
        gradient_color_4 = "'#${colors.base05}'"; # 37.5-50% - Text color (normal)
        gradient_color_5 = "'#${colors.base0A}'"; # 50-62.5% - Yellow (moderate)
        gradient_color_6 = "'#${colors.base0A}'"; # 62.5-75% - Yellow
        gradient_color_7 = "'#${colors.base09}'"; # 75-87.5% - Orange (loud)
        gradient_color_8 = "'#${colors.base08}'"; # 87.5-100% - Red (peaks)
      }))

      # Rainbow gradient mode (extends default stylix behavior)
      # This is handled by stylix's rainbow.enable, but we provide explicit colors
      (mkIf (cfg.gradientMode == "rainbow" && !cfg.rainbow.enable) {
        background = "'#${colors.base00}'";
        gradient = 1;
        gradient_count = 7;
        # Full spectrum gradient
        gradient_color_1 = "'#${colors.base0E}'"; # Magenta
        gradient_color_2 = "'#${colors.base0D}'"; # Blue
        gradient_color_3 = "'#${colors.base0C}'"; # Cyan
        gradient_color_4 = "'#${colors.base0B}'"; # Green
        gradient_color_5 = "'#${colors.base0A}'"; # Yellow
        gradient_color_6 = "'#${colors.base09}'"; # Orange
        gradient_color_7 = "'#${colors.base08}'"; # Red
      })
    ];
  };
}
