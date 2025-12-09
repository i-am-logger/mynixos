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
                  "key": "        \u001b[1mOS\u001b[0m"
                },
                {
                  "type": "host",
                  "key": "      \u001b[1mHost\u001b[0m"
                },
                {
                  "type": "uptime",
                  "key": "    \u001b[1mUptime\u001b[0m"
                },
                {
                  "type": "kernel",
                  "key": "    \u001b[1mKernel\u001b[0m"
                },
                {
                  "type": "shell",
                  "key": "     \u001b[1mShell\u001b[0m"
                },
                {
                  "type": "packages",
                  "key": "  \u001b[1mPackages\u001b[0m"
                },
                "break",
                {
                  "type": "custom",
                  "format": "  \u001b[1m\u001b[4mHardware\u001b[0m"
                },
                {
                  "type": "cpu",
                  "key": "       \u001b[1mCPU\u001b[0m"
                },
                {
                  "type": "gpu",
                  "key": "       \u001b[1mGPU\u001b[0m"
                },
                {
                  "type": "memory",
                  "key": "    \u001b[1mMemory\u001b[0m"
                },
                {
                  "type": "disk",
                  "key": "        \u001b[1m/\u001b[0m",
                  "folders": "/"
                },
                {
                  "type": "disk",
                  "key": "    \u001b[1m/boot\u001b[0m",
                  "folders": "/boot",
                  "hideFolders": []
                },
                {
                  "type": "disk",
                  "key": "     \u001b[1m/nix\u001b[0m",
                  "folders": "/nix"
                },
                {
                  "type": "disk",
                  "key": " \u001b[1m/persist\u001b[0m",
                  "folders": "/persist"
                },
                {
                  "type": "swap",
                  "key": "      \u001b[1mSwap\u001b[0m"
                },
                {
                  "type": "display",
                  "key": "   \u001b[1mDisplay\u001b[0m"
                },
                {
                  "type": "battery",
                  "key": "   \u001b[1mBattery\u001b[0m"
                },
                "break",
                {
                  "type": "custom",
                  "format": "   \u001b[1m\u001b[4mDesktop\u001b[0m"
                },
                {
                  "type": "wm",
                  "key": "        \u001b[1mWM\u001b[0m"
                },
                {
                  "type": "theme",
                  "key": "     \u001b[1mTheme\u001b[0m"
                },
                {
                  "type": "font",
                  "key": " \u001b[1mFont (Qt)\u001b[0m",
                  "format": "{1}"
                },
                {
                  "type": "font",
                  "key": "\u001b[1mFont (GTK)\u001b[0m",
                  "format": "{2}"
                },
                {
                  "type": "terminal",
                  "key": "  \u001b[1mTerminal\u001b[0m"
                },
                {
                  "type": "terminalfont",
                  "key": " \u001b[1mTerm Font\u001b[0m"
                }
              ]
            }
          '';
        })
      config.my.users;
  };
}
