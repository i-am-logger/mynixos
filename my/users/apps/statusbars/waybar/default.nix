# Waybar - Wayland status bar
# Enabled automatically when user has graphical.enable = true
{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable when any user has graphical.enable = true
  anyUserGraphical = any (userCfg: userCfg.graphical.enable or false) (attrValues config.my.users);
in
{
  config = mkIf anyUserGraphical {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.graphical.enable or false) {
          programs.waybar = {
            enable = true;

            # Use systemd service for auto-start
            systemd.enable = true;

            # Waybar settings
            settings = [
              {
                # TOP BAR
                layer = "top";
                position = "top";
                height = 28;

                modules-left = [
                  "hyprland/workspaces"
                ];

                modules-center = [
                  "clock"
                  "custom/seperator"
                  "custom/weather"
                ];

                modules-right = [
                  "privacy"
                  "custom/seperator"
                  "network"
                  "custom/seperator"
                  "pulseaudio"
                  "custom/seperator"
                  "custom/audio"
                  "custom/seperator"
                  "cava"
                  "custom/seperator"
                  "battery"
                  "custom/seperator"
                  "upower"
                  "custom/seperator"
                  "tray"
                ];

                "custom/seperator" = {
                  format = "|";
                  tooltip = false;
                };

                "custom/audio" = {
                  format = " |";
                  tooltip = false;
                };

                "hyprland/workspaces" = {
                  active-only = false;
                  format-window-separator = "|";
                  format = "{name}";
                };

                clock = {
                  interval = 1;
                  format = "{:%A | %r | %m-%d-%Y}";
                  tooltip = false;
                };

                "custom/weather" = {
                  format = "{}";
                  interval = 600;
                  exec = "${pkgs.wttrbar}/bin/wttrbar --location auto --fahrenheit --main-indicator temp_F";
                  return-type = "json";
                };

                network = {
                  format-wifi = "{essid} ({signalStrength}%) ";
                  format-ethernet = "{ifname} ";
                  format-disconnected = "Disconnected ";
                  tooltip-format = "{ipaddr}/{cidr}";
                  on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
                };

                pulseaudio = {
                  format = "{volume}% {icon}";
                  format-bluetooth = "{volume}% {icon}";
                  format-muted = "";
                  format-icons = {
                    headphones = "";
                    default = [ "" "" ];
                  };
                  on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
                };

                battery = {
                  interval = 60;
                  states = {
                    warning = 30;
                    critical = 15;
                  };
                  format = "{capacity}% {icon}";
                  format-icons = [ "" "" "" "" "" ];
                };

                upower = {
                  show-icon = true;
                  hide-if-empty = true;
                  tooltip = true;
                  tooltip-spacing = 20;
                };

                privacy = {
                  icon-spacing = 4;
                  icon-size = 18;
                  transition-duration = 250;
                  modules = [
                    {
                      type = "screenshare";
                      tooltip = true;
                      tooltip-icon-size = 24;
                    }
                    {
                      type = "audio-in";
                      tooltip = true;
                      tooltip-icon-size = 24;
                    }
                  ];
                };

                tray = {
                  icon-size = 18;
                  spacing = 10;
                };

                cava = {
                  framerate = 30;
                  autosens = 1;
                  bars = 14;
                  method = "pipewire";
                  source = "auto";
                  stereo = true;
                  bar_delimiter = 0;
                  input_delay = 2;
                  sleep_timer = 5;
                  hide_on_silence = true;
                  format-icons = [ "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
                };
              }

              {
                # BOTTOM BAR
                layer = "top";
                position = "bottom";
                height = 28;

                modules-left = [
                  "hyprland/window"
                ];

                modules-center = [
                  "mpris"
                ];

                modules-right = [
                  "cpu"
                  "custom/seperator"
                  "temperature"
                  "custom/seperator"
                  "memory"
                  "custom/seperator"
                  "disk"
                ];

                "custom/seperator" = {
                  format = "|";
                  tooltip = false;
                };

                "hyprland/window" = {
                  max-length = 100;
                  icon = true;
                  icon-size = 22;
                };

                mpris = {
                  format = "{player_icon} {artist} - {title}";
                  format-paused = "{status_icon} {artist} - {title}";
                  player-icons = {
                    default = "";
                    spotify = "";
                    chromium = "";
                    brave = "";
                    firefox = "";
                  };
                  status-icons = {
                    paused = "";
                  };
                };

                cpu = {
                  interval = 5;
                  format = "CPU: {usage}%";
                  tooltip = true;
                };

                temperature = {
                  interval = 5;
                  format = "{temperatureC}C";
                  tooltip = true;
                };

                memory = {
                  interval = 5;
                  format = "RAM: {percentage}%";
                  tooltip = true;
                  tooltip-format = "{used:0.1f}G / {total:0.1f}G";
                };

                disk = {
                  interval = 30;
                  format = "Disk: {percentage_used}%";
                  path = "/";
                  tooltip = true;
                  tooltip-format = "{used} / {total}";
                };
              }
            ];

            # Waybar styling - minimal base, Stylix handles colors
            style = ''
              * {
                font-family: "FiraCode Nerd Font", "Font Awesome 6 Free", monospace;
                font-size: 14px;
                min-height: 0;
              }

              window#waybar {
                background: transparent;
              }

              #workspaces button {
                padding: 0 5px;
                border-radius: 0;
              }

              #workspaces button.active {
                font-weight: bold;
              }

              #clock, #battery, #cpu, #memory, #disk, #temperature, #network, #pulseaudio, #tray, #mpris {
                padding: 0 10px;
              }

              #privacy {
                padding: 0 5px;
              }

              #cava {
                padding: 0 5px;
              }
            '';
          };

          # Add waybar and related packages
          home.packages = with pkgs; [
            wttrbar # Weather for waybar
            # cava is managed via programs.cava (enabled by terminal feature)
          ];
        }
      )
      config.my.users;
  };
}
