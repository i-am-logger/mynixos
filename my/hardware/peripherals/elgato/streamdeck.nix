{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.peripherals.elgato.streamdeck;
in
{
  config = mkIf cfg.enable {
    # Add Stream Deck udev rules for hardware access
    services.udev.packages = [
      pkgs.streamdeck-ui
    ];

    # Enable udev rules for Stream Deck devices
    services.udev.extraRules = ''
      # Stream Deck Original
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", MODE="0664", GROUP="users"
      # Stream Deck Mini
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", MODE="0664", GROUP="users"
      # Stream Deck XL
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", MODE="0664", GROUP="users"
      # Stream Deck V2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", MODE="0664", GROUP="users"
      # Stream Deck MK.2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", MODE="0664", GROUP="users"
      # Stream Deck Plus
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0084", MODE="0664", GROUP="users"
    '';

    # Ensure the user is in the required groups
    users.groups.streamdeck = { };

    # Add streamdeck-ui with Qt platform fixes (only for users with streaming enabled)
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.graphical.streaming.enable or false) {
          home.packages = with pkgs; [
            streamdeck-ui
            # Qt platform dependencies
            libsForQt5.qt5.qtwayland
            qt6.qtwayland
          ];
        }
      )
      config.my.users;

    # Fix Qt platform plugin issues for streamdeck-ui
    environment.sessionVariables = {
      # Set Qt platform plugins path
      QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.libsForQt5.qt5.qtbase.bin}/lib/qt-${pkgs.libsForQt5.qt5.qtbase.version}/plugins/platforms:${pkgs.qt6.qtbase}/lib/qt-6/plugins/platforms";
      # Prefer Wayland but fallback to xcb
      QT_QPA_PLATFORM = "wayland;xcb";
      # Enable Qt logging for debugging
      QT_LOGGING_RULES = "qt.qpa.plugin.debug=false";
    };

    # Disable streamdeck-ui system service if it's causing issues
    # Users should run it manually from their desktop session
    systemd.user.services.streamdeck-ui = {
      enable = false;
    };
  };
}
