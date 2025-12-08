{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.peripherals.elgato.streamdeck;

  # Script to toggle microphone mute/unmute with visual feedback
  # Usage: mic-toggle [on|off|toggle]
  micToggleScript = pkgs.writeShellScript "mic-toggle" ''
    #!/bin/bash
    
    # Microphone control script with on/off/toggle support
    # Usage: mic-toggle [on|off|toggle]
    # If no argument provided, defaults to toggle
    
    ACTION="''${1:-toggle}"
    
    case "$ACTION" in
        "on")
            # Unmute microphone
            ${pkgs.pamixer}/bin/pamixer --default-source -u
            ;;
        "off")
            # Mute microphone
            ${pkgs.pamixer}/bin/pamixer --default-source -m
            ;;
        "toggle"|*)
            # Toggle microphone (default behavior)
            ${pkgs.pamixer}/bin/pamixer --default-source -t
            ;;
    esac
    
    # Get current mute status and provide feedback
    if ${pkgs.pamixer}/bin/pamixer --default-source --get-mute | grep -q "true"; then
        # Muted - send notification
        ${pkgs.libnotify}/bin/notify-send -i audio-input-microphone-muted "Microphone" "Muted" -t 2000
        echo "MUTED"
    else
        # Unmuted - send notification  
        ${pkgs.libnotify}/bin/notify-send -i audio-input-microphone "Microphone" "Unmuted" -t 2000
        echo "UNMUTED"
    fi
  '';

  # Script to get microphone status for Stream Deck display
  micStatusScript = pkgs.writeShellScript "mic-status" ''
    #!/bin/bash
    if ${pkgs.pamixer}/bin/pamixer --default-source --get-mute | grep -q "true"; then
      echo "🔇 MUTED"
    else
      echo "🎙️ LIVE"
    fi
  '';

  # Script to get background color based on mic status
  micColorScript = pkgs.writeShellScript "mic-color" ''
    #!/bin/bash
    if ${pkgs.pamixer}/bin/pamixer --default-source --get-mute | grep -q "true"; then
      echo "#ff4444"  # Red when muted
    else
      echo "#44ff44"  # Green when live/unmuted
    fi
  '';

  # Script to toggle audio output devices only (speakers/headphones)
  # Usage: audio-toggle [on|off|toggle]
  audioToggleScript = pkgs.writeShellScript "audio-toggle" ''
    #!/bin/bash
    
    # Audio control script with on/off/toggle support
    # Usage: audio-toggle [on|off|toggle]
    # If no argument provided, defaults to toggle
    
    ACTION="''${1:-toggle}"
    
    case "$ACTION" in
        "on")
            # Unmute output device (speakers/headphones)
            ${pkgs.pamixer}/bin/pamixer -u
            ;;
        "off")
            # Mute output device (speakers/headphones)
            ${pkgs.pamixer}/bin/pamixer -m
            ;;
        "toggle"|*)
            # Toggle output device (speakers/headphones)
            ${pkgs.pamixer}/bin/pamixer -t
            ;;
    esac
    
    # Get final mute status and send notification
    if ${pkgs.pamixer}/bin/pamixer --get-mute | grep -q "true"; then
        # Muted - send notification
        ${pkgs.libnotify}/bin/notify-send -i audio-volume-muted "Audio Output" "Muted" -t 2000
        echo "MUTED"
    else
        # Unmuted - send notification  
        ${pkgs.libnotify}/bin/notify-send -i audio-volume-high "Audio Output" "Unmuted" -t 2000
        echo "UNMUTED"
    fi
  '';

  # Script to get audio status for Stream Deck display
  audioStatusScript = pkgs.writeShellScript "audio-status" ''
    #!/bin/bash
    if ${pkgs.pamixer}/bin/pamixer --get-mute | grep -q "true"; then
      echo "🔇 AUDIO MUTED"
    else
      echo "🔊 AUDIO LIVE"
    fi
  '';

  # Script to get background color based on audio status
  audioColorScript = pkgs.writeShellScript "audio-color" ''
    #!/bin/bash
    if ${pkgs.pamixer}/bin/pamixer --get-mute | grep -q "true"; then
      echo "#ff4444"  # Red when muted
    else
      echo "#44ff44"  # Green when live/unmuted
    fi
  '';

  # Script to toggle OBS Virtual Camera on/off
  # Uses obs-cmd to control OBS WebSocket API
  obsVirtualCamToggleScript = pkgs.writeShellScript "obs-virtualcam-toggle" ''
    #!/bin/bash
    
    # OBS Virtual Camera control script
    # Requires OBS to be running with WebSocket server enabled
    
    # Check if OBS is running
    if ! ${pkgs.procps}/bin/pgrep -x "obs" > /dev/null; then
        ${pkgs.libnotify}/bin/notify-send -i dialog-error "OBS Virtual Camera" "OBS is not running" -t 3000
        echo "ERROR: OBS not running"
        exit 1
    fi
    
    # Try to toggle virtual camera using obs-cli (if available) or fallback to obs-cmd
    if command -v obs-cli > /dev/null 2>&1; then
        # Using obs-cli if available
        obs-cli virtualcam toggle
    else
        # Fallback: Use obs-cmd or direct WebSocket call
        # Note: This requires obs-websocket plugin and proper configuration
        ${pkgs.curl}/bin/curl -s -X POST "http://localhost:4455/api/v1/virtualcam/toggle" || {
            # Alternative: Use dbus to send OBS commands if available
            ${pkgs.libnotify}/bin/notify-send -i dialog-warning "OBS Virtual Camera" "Unable to toggle - check OBS WebSocket configuration" -t 3000
            echo "WARNING: Could not toggle virtual camera"
            exit 1
        }
    fi
    
    # Wait a moment for the state to change
    sleep 0.5
    
    # Get current virtual camera status and provide feedback
    # This is a simplified check - you may need to adjust based on your OBS setup
    if ${pkgs.procps}/bin/pgrep -f "obs.*virtual" > /dev/null; then
        ${pkgs.libnotify}/bin/notify-send -i camera-video "OBS Virtual Camera" "Started" -t 2000
        echo "STARTED"
    else
        ${pkgs.libnotify}/bin/notify-send -i camera-video "OBS Virtual Camera" "Stopped" -t 2000
        echo "STOPPED"
    fi
  '';

  # Script to get OBS Virtual Camera status for Stream Deck display
  obsVirtualCamStatusScript = pkgs.writeShellScript "obs-virtualcam-status" ''
    #!/bin/bash
    if ${pkgs.procps}/bin/pgrep -f "obs.*virtual" > /dev/null || ${pkgs.procps}/bin/pgrep -x "obs" > /dev/null; then
      # Check if virtual camera is actually running (simplified check)
      if ls /dev/video* 2>/dev/null | grep -q "video"; then
        echo "📹 CAM ON"
      else
        echo "📹 CAM OFF"
      fi
    else
      echo "📹 OBS OFF"
    fi
  '';

  # Script to get background color based on OBS Virtual Camera status
  obsVirtualCamColorScript = pkgs.writeShellScript "obs-virtualcam-color" ''
    #!/bin/bash
    if ${pkgs.procps}/bin/pgrep -f "obs.*virtual" > /dev/null; then
      echo "#4444ff"  # Blue when virtual camera is active
    elif ${pkgs.procps}/bin/pgrep -x "obs" > /dev/null; then
      echo "#ffaa44"  # Orange when OBS is running but virtual camera is off
    else
      echo "#666666"  # Gray when OBS is not running
    fi
  '';

  # Stream Deck UI configuration for ~/.streamdeck_ui.json
  streamdeckConfig = builtins.toJSON {
    streamdeck_ui_version = 2;
    state = {
      "0fd9:0063" = {
        brightness = 100;
        brightness_dimmed = 30;
        display_timeout = 0;
        rotation = 0;
        page = 0;
        buttons = {
          "0" = {
            "0" = {
              command = toString micToggleScript;
              keys = "🎙️";
              write = toString micStatusScript;
              change_brightness = false;
            };
          };
          "1" = {
            "0" = {
              command = toString audioToggleScript;
              keys = "🔊";
              write = toString audioStatusScript;
              change_brightness = false;
            };
          };
          "2" = {
            "0" = {
              command = toString obsVirtualCamToggleScript;
              keys = "📹";
              write = toString obsVirtualCamStatusScript;
              change_brightness = false;
            };
          };
        };
      };
    };
  };
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
            # Audio utilities (already have pamixer from your config)
            pamixer
            # Notification support
            libnotify
            # Additional useful packages for Stream Deck
            imagemagick # For image processing
          ];

          # Create symbolic links for easy access to scripts
          home.file = {
            ".local/bin/mic-toggle" = {
              source = micToggleScript;
              executable = true;
            };

            ".local/bin/mic-status" = {
              source = micStatusScript;
              executable = true;
            };

            ".local/bin/mic-color" = {
              source = micColorScript;
              executable = true;
            };

            ".local/bin/audio-toggle" = {
              source = audioToggleScript;
              executable = true;
            };

            ".local/bin/audio-status" = {
              source = audioStatusScript;
              executable = true;
            };

            ".local/bin/audio-color" = {
              source = audioColorScript;
              executable = true;
            };

            ".local/bin/obs-virtualcam-toggle" = {
              source = obsVirtualCamToggleScript;
              executable = true;
            };

            ".local/bin/obs-virtualcam-status" = {
              source = obsVirtualCamStatusScript;
              executable = true;
            };

            ".local/bin/obs-virtualcam-color" = {
              source = obsVirtualCamColorScript;
              executable = true;
            };

            # Stream Deck icons directory
            ".local/share/streamdeck/icons/mic-muted.png" = {
              # You can replace this with a custom icon file
              text = "";
            };

            ".local/share/streamdeck/icons/mic-live.png" = {
              # You can replace this with a custom icon file  
              text = "";
            };

            ".local/share/streamdeck/icons/audio-muted.png" = {
              # You can replace this with a custom icon file
              text = "";
            };

            ".local/share/streamdeck/icons/audio-live.png" = {
              # You can replace this with a custom icon file  
              text = "";
            };

            # Stream Deck UI configuration file
            ".streamdeck_ui.json" = {
              text = streamdeckConfig;
            };
          };

          # Add desktop entry for manual launching
          xdg.desktopEntries.streamdeck = {
            name = "Stream Deck";
            comment = "Configure Stream Deck buttons";
            exec = "${pkgs.streamdeck-ui}/bin/streamdeck";
            icon = "preferences-desktop-peripherals";
            categories = [ "Settings" "HardwareSettings" ];
          };
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
