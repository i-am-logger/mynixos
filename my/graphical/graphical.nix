{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable graphical when any user has graphical.enable = true
  anyUserGraphical = any (userCfg: userCfg.graphical.enable or false) (attrValues config.my.users);
  dmCfg = config.my.environment.displayManager;
  dmType = dmCfg.type;
in
{
  config = mkMerge [
    # Set read-only system flag
    { my.graphical.enable = anyUserGraphical; }

    # Feature configuration
    (mkIf config.my.graphical.enable (mkMerge [
      # Base desktop configuration with Hyprland
    {
      # System-level Hyprland setup
      systemd.tmpfiles.rules = [
        "d /tmp/hypr 1777 root root -"
      ];

      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      services.xserver = {
        enable = true;
      };
    }

    # Display manager configuration (auto-enabled based on my.environment.displayManager.type)
    (mkIf (dmType == "greetd") {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${dmCfg.greetd.settings.default_session.command}";
            user = dmCfg.greetd.settings.default_session.user;
          };
        };
      };
    })

    (mkIf (dmType == "gdm") {
      services.xserver.displayManager.gdm = {
        enable = true;
        wayland = dmCfg.gdm.wayland;
      };
    })

    (mkIf (dmType == "sddm") {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = dmCfg.sddm.wayland.enable;
      };
    })

    (mkIf (dmType == "lightdm") {
      services.xserver.displayManager.lightdm = {
        enable = true;
        greeters.gtk.enable = dmCfg.lightdm.greeters.gtk;
      };
    })

    # XDG portal configuration (for Wayland/Hyprland)
    (mkIf config.my.environment.xdg.enable {
      xdg.portal = {
        enable = true;
        configPackages = [ pkgs.xdg-desktop-portal-gtk ];
        xdgOpenUsePortal = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
        config = {
          common = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Settings" = [
              "gtk"
            ];
          };
          hyprland = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.Settings" = [
              "gtk"
            ];
          };
        };
      };

      environment.systemPackages = with pkgs; [
        qt6.qtwayland
      ];

      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1"; # For Electron apps
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
        XDG_SESSION_DESKTOP = "Hyprland";
        GDK_BACKEND = "wayland";
        QT_QPA_PLATFORM = "wayland;xcb";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        MOZ_ENABLE_WAYLAND = "1";
        WAYLAND_DISPLAY = "wayland-1";
      };

      services.dbus.enable = true;
    })

    # Common graphical configuration
    {
      environment.systemPackages = with pkgs; [
        mako # notification daemon
      ];

      # Add users to graphical-related groups
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "input" "gpu" "video" "render" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

      # 1Password integration
      programs._1password.enable = true;
      programs._1password-gui.enable = true;

      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
          "1password-gui"
          "1password"
          "1password-cli"
          "chromium"
          "chromium-unwrapped"
        ];
    }

    # Audio tools are now in my.hardware.audio, not in graphical
    ]))
  ];
}
