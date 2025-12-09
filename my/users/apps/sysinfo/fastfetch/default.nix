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
                  "type": 3
                },
                "color": {
                  "keys": "white"
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
                  "format": "    \u001b[1m\u001b[4mSystem\u001b[0m"
                },
                {
                  "type": "os",
                  "key": "        OS",
                  "format": "\u001b[1m{3} {12}\u001b[0m"
                },
                {
                  "type": "host",
                  "key": "      Host"
                },
                {
                  "type": "uptime",
                  "key": "    Uptime",
                  "format": "\u001b[1m{10}\u001b[0m"
                },
                {
                  "type": "kernel",
                  "key": "    Kernel"
                },
                {
                  "type": "shell",
                  "key": "     Shell"
                },
                {
                  "type": "packages",
                  "key": "  Packages"
                },
                "break",
                {
                  "type": "custom",
                  "format": "  \u001b[1m\u001b[4mHardware\u001b[0m"
                },
                {
                  "type": "cpu",
                  "key": "       CPU"
                },
                {
                  "type": "gpu",
                  "key": "       GPU"
                },
                {
                  "type": "display",
                  "key": "   Display"
                },
                {
                  "type": "memory",
                  "key": "    Memory"
                },
                {
                  "type": "swap",
                  "key": "      Swap"
                },
                {
                  "type": "disk",
                  "key": "      Disk",
                  "folders": "/",
                  "format": "{size-percentage-bar} [       /] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "disk",
                  "key": "      Disk",
                  "folders": "/boot",
                  "hideFolders": [],
                  "format": "{size-percentage-bar} [   /boot] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "disk",
                  "key": "      Disk",
                  "folders": "/nix",
                  "format": "{size-percentage-bar} [    /nix] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "disk",
                  "key": "      Disk",
                  "folders": "/persist",
                  "format": "{size-percentage-bar} [/persist] {size-used} / {size-total} ({size-percentage}) - {filesystem}"
                },
                {
                  "type": "battery",
                  "key": "   Battery"
                },
                "break",
                {
                  "type": "custom",
                  "format": "   \u001b[1m\u001b[4mDesktop\u001b[0m"
                },
                {
                  "type": "wm",
                  "key": "        WM"
                },
                {
                  "type": "theme",
                  "key": "     Theme"
                },
                {
                  "type": "font",
                  "key": " Font (Qt)",
                  "format": "{1}"
                },
                {
                  "type": "font",
                  "key": "Font (GTK)",
                  "format": "{2}"
                },
                {
                  "type": "terminal",
                  "key": "  Terminal"
                },
                {
                  "type": "terminalfont",
                  "key": " Term Font"
                }
              ]
            }
          '';
        })
      config.my.users;
  };
}
