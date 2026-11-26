{ activeUsers, config, lib, ... }:

with lib;

let
  cfg = config.my.environment;
  motdCfg = cfg.motd;
in
{
  config = mkMerge [
    # MOTD configuration
    (mkIf motdCfg.enable {
      users.motd = motdCfg.content;
    })

    (mkIf cfg.enable (mkMerge [
      # Persistence: XDG base and user directories
      {
        my.system.persistence.features = {
          userDirectories = [
            ".local"
            ".cache"
            ".config"
            "Documents"
            "Downloads"
          ];
        };
      }

      # EDITOR, BROWSER and the MIME defaults are per-user selections
      # (my/users/environment-defaults), never host-wide store paths.
      {
        environment.pathsToLink = [ "libexec" ];
      }

      # Common environment configuration (always enabled with environment feature)
      {
        # Disable wpa_supplicant in favor of NetworkManager (opinionated)
        networking.wireless.enable = lib.mkDefault false;

        # Auto-mounting support for removable media (opinionated default)
        services.udisks2.enable = mkDefault true;

        # Locale and timezone (mynixos opinionated defaults)
        time.timeZone = mkDefault cfg.timezone;
        i18n.defaultLocale = mkDefault cfg.locale;
        i18n.extraLocaleSettings = mkDefault {
          LC_ADDRESS = cfg.locale;
          LC_IDENTIFICATION = cfg.locale;
          LC_MEASUREMENT = cfg.locale;
          LC_MONETARY = cfg.locale;
          LC_NAME = cfg.locale;
          LC_NUMERIC = cfg.locale;
          LC_PAPER = cfg.locale;
          LC_TELEPHONE = cfg.locale;
          LC_TIME = cfg.locale;
        };

        # Keyboard layout (mynixos opinionated defaults)
        services.xserver.xkb = {
          layout = mkDefault cfg.keyboardLayout;
          variant = mkDefault "";
        };

        # Opinionated stateVersion - using 26.11 as baseline (can be overridden)
        system.stateVersion = lib.mkDefault "26.11";
      }

      # Set home.stateVersion for all users (opinionated)
      {
        home-manager.users = mapAttrs
          (_name: _userCfg: {
            home.stateVersion = lib.mkDefault "26.11";
            # Keep the legacy default (HM 26.11 sets this false for stateVersion >= 26.05).
            xdg.userDirs.setSessionVariables = lib.mkDefault true;
          })
          (activeUsers config.my.users);
      }
    ]))
  ];
}
