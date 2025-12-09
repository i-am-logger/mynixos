{ config, lib, pkgs, ... }:

with lib;

let
  # mynixos logo from assets directory
  mynixosLogo = ../../../../../assets/logos/mynixos.txt;
in
{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.terminal.sysinfo.fastfetch.enable or false) {
          home.packages = with pkgs; [
            fastfetch
          ];
          
          # Configure fastfetch to use mynixos logo with categorized system info
          xdg.configFile."fastfetch/config.jsonc".text = ''
            {
              "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
              "logo": {
                "type": "file",
                "source": "${mynixosLogo}",
                "padding": {
                  "top": 1
                }
              },
              "display": {
                "separator": "  ",
                "percent": {
                  "type": 3,
                  "green": 60,
                  "yellow": 80
                },
                "color": {
                  "keys": "default"
                }
              },
              "modules": [
                {
                  "type": "title",
                  "format": "{user-name}@{host-name}"
                },
                "separator",
                {
                  "type": "custom",
                  "format": "       \u001b[1m\u001b[4mSystem\u001b[0m"
                },
                {
                  "type": "os",
                  "key": "           OS",
                  "format": "\u001b[1m{3} {12}\u001b[0m"
                },
                {
                  "type": "host",
                  "key": "         Host",
                  "keyColor": "reset_",
                  "format": "{2}"
                },
                {
                  "type": "uptime",
                  "key": "       Uptime",
                  "format": "\u001b[1m{10}\u001b[0m"
                },
                {
                  "type": "bootmgr",
                  "key": "      Bootmgr",
                  "keyColor": "reset_"
                },
                {
                  "type": "command",
                  "key": "  \u001b[1mSecure Boot\u001b[0m",
                  "text": "bash -c 'bootctl status 2>/dev/null | awk \"/Secure Boot: enabled/ {print \\\"Enabled\\\"; exit}\"'",
                  "format": "{#green}\u001b[1m{result}\u001b[0m{#}"
                },
                {
                  "type": "command",
                  "key": "  \u001b[1mSecure Boot\u001b[0m",
                  "text": "bash -c 'bootctl status 2>/dev/null | awk \"/Secure Boot: disabled/ {print \\\"Disabled\\\"; exit}\"'",
                  "format": "{#red}\u001b[1m\u001b[5m{result}\u001b[0m{#}"
                },
                {
                  "type": "kernel",
                  "key": "       Kernel",
                  "keyColor": "reset_"
                },
                {
                  "type": "lm",
                  "key": "Login Manager",
                  "keyColor": "reset_"
                },
                {
                  "type": "shell",
                  "key": "        Shell",
                  "keyColor": "reset_"
                },
                {
                  "type": "packages",
                  "key": "     Packages",
                  "keyColor": "reset_"
                },
                "break",
                {
                  "type": "custom",
                  "format": "     \u001b[1m\u001b[4mHardware\u001b[0m"
                },
                {
                  "type": "cpu",
                  "key": "          CPU",
                  "keyColor": "reset_"
                },
                {
                  "type": "gpu",
                  "key": "          GPU",
                  "keyColor": "reset_"
                },
                {
                  "type": "display",
                  "key": "      Display",
                  "keyColor": "reset_"
                },
                {
                  "type": "memory",
                  "key": "       Memory",
                  "keyColor": "reset_"
                },
                {
                  "type": "swap",
                  "key": "         Swap",
                  "keyColor": "reset_"
                },
                {
                  "type": "disk",
                  "key": "         Disk",
                  "keyColor": "reset_",
                  "folders": "/",
                  "format": "{size-percentage-bar} [       /] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "disk",
                  "key": "         Disk",
                  "keyColor": "reset_",
                  "folders": "/boot",
                  "hideFolders": [],
                  "format": "{size-percentage-bar} [   /boot] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "disk",
                  "key": "         Disk",
                  "keyColor": "reset_",
                  "folders": "/nix",
                  "format": "{size-percentage-bar} [    /nix] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "disk",
                  "key": "         Disk",
                  "keyColor": "reset_",
                  "folders": "/persist",
                  "format": "{size-percentage-bar} [/persist] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "battery",
                  "key": "      Battery",
                  "keyColor": "reset_"
                },
                {
                  "type": "keyboard",
                  "key": "          USB",
                  "keyColor": "reset_"
                },
                {
                  "type": "camera",
                  "key": "       Camera",
                  "keyColor": "reset_"
                },
                "break",
                {
                  "type": "custom",
                  "format": "      \u001b[1m\u001b[4mDesktop\u001b[0m"
                },
                {
                  "type": "wm",
                  "key": "           WM",
                  "keyColor": "reset_"
                },
                {
                  "type": "wmtheme",
                  "key": "     WM Theme",
                  "keyColor": "reset_"
                },
                {
                  "type": "theme",
                  "key": "        Theme",
                  "keyColor": "reset_"
                },
                {
                  "type": "font",
                  "key": "    Font (Qt)",
                  "keyColor": "reset_",
                  "format": "{1}"
                },
                {
                  "type": "font",
                  "key": "   Font (GTK)",
                  "keyColor": "reset_",
                  "format": "{2}"
                },
                {
                  "type": "terminal",
                  "key": "     Terminal",
                  "keyColor": "reset_"
                },
                {
                  "type": "terminalfont",
                  "key": "    Term Font",
                  "keyColor": "reset_"
                },
                "break",
                {
                  "type": "colors",
                  "symbol": "block",
                  "paddingLeft": 15,
                  "block": {
                    "width": 3,
                    "range": [0, 15]
                  }
                },
                "break",
                {
                  "type": "media",
                  "key": "               ♫",
                  "keyColor": "reset_",
                  "format": "\u001b[1mPlaying now - {artist} - {title}\u001b[0m"
                }
              ]
            }
          '';
        })
      config.my.users;
  };
}
