{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.themes;
in
{
  config = mkIf cfg.enable {
    # Import Stylix for theming
    stylix = {
      enable = true;
      polarity = cfg.polarity;

      # Wallpaper configuration
      image = mkIf (cfg.wallpaper != null) cfg.wallpaper;

      # Color scheme configuration
      base16Scheme = mkIf (cfg.colorScheme != null) cfg.colorScheme;

      # Opacity settings
      opacity = {
        applications = cfg.opacity.applications;
        desktop = cfg.opacity.desktop;
        popups = cfg.opacity.popups;
        terminal = cfg.opacity.terminal;
      };

      # Font configuration
      fonts = {
        sizes = {
          applications = cfg.fonts.sizes.applications;
          desktop = cfg.fonts.sizes.desktop;
          popups = cfg.fonts.sizes.popups;
          terminal = cfg.fonts.sizes.terminal;
        };

        serif = {
          name = cfg.fonts.serif.name;
          package = cfg.fonts.serif.package;
        };

        sansSerif = {
          name = cfg.fonts.sansSerif.name;
          package = cfg.fonts.sansSerif.package;
        };

        monospace = {
          name = cfg.fonts.monospace.name;
          package = cfg.fonts.monospace.package;
        };

        emoji = {
          name = cfg.fonts.emoji.name;
          package = cfg.fonts.emoji.package;
        };
      };

      # Cursor configuration
      cursor = {
        name = cfg.cursor.name;
        package = cfg.cursor.package;
        size = cfg.cursor.size;
      };

      # Disable GRUB theming since we use systemd-boot
      targets.grub.enable = false;

      # Disable Qt theming to avoid compatibility issues with newer home-manager
      # (stylix uses qt5ctSettings/qt6ctSettings which were removed in newer HM)
      targets.qt.enable = false;
    };
  };
}
