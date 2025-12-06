{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable when any user has webapps.enable = true
  anyUserWebapps = any (userCfg: (userCfg.webapps.enable or false)) (attrValues config.my.users);

  # Check if any user has specific apps enabled
  anyUserSlack = any (userCfg: (userCfg.webapps.slack or false)) (attrValues config.my.users);
  anyUserSignal = any (userCfg: (userCfg.webapps.signal or false)) (attrValues config.my.users);
  anyUser1Password = any (userCfg: (userCfg.webapps.onePassword or false)) (attrValues config.my.users);

  # mynixos opinionated defaults for webapps
  defaults = {
    # Browser-based webapps
    gmail = true;
    vscode = true;
    github = true;
    spotify = true;
    discord = true;
    whatsapp = true;
    youtube = true;
    netflix = true;
    twitch = true;
    zoom = true;
    chatgpt = true;
    claude = true;
    grok = true;
    x = true;

    # Electron apps
    slack = false;
    signal = false;

    # Password managers
    onePassword = false;
  };

  # Helper function to wrap Electron apps
  wrapElectronApp = pkg: bin: pkgs.symlinkJoin {
    name = "${pkg.pname or pkg.name}-wrapped";
    paths = [ pkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/${bin} \
        --add-flags "--password-store=basic"
    '';
  };

  # Create chromium with Widevine enabled for DRM content
  chromiumWithWidevine = pkgs.chromium.override {
    enableWideVine = true;
  };

  # Helper to create webapp definition
  mkWebapp = { name, url, icon, categories ? [ "Network" ], mimeTypes ? [ ], enabled ? true }:
    optionalAttrs enabled {
      ${name} = {
        inherit url;
        name = builtins.replaceStrings [ "-" ] [ " " ] (lib.toUpper (builtins.substring 0 1 name) + builtins.substring 1 (builtins.stringLength name) name);
        icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/${icon}.svg";
        inherit categories mimeTypes;
        startupWmClass = "${name}-webapp";
      };
    };
in
{
  config = mkIf anyUserWebapps (mkMerge [
    # Allow unfree packages for webapps (chromium, widevine, etc.)
    # Use allowUnfree = true instead of predicate to ensure it works at all evaluation levels
    {
      nixpkgs.config.allowUnfree = true;
    }

    # Electron apps
    (mkIf (anyUserSlack || anyUserSignal) {
      environment.systemPackages =
        (optional anyUserSlack (wrapElectronApp pkgs.slack "slack")) ++
        (optional anyUserSignal (wrapElectronApp pkgs.signal-desktop "signal-desktop"));
    })

    # 1Password
    (mkIf anyUser1Password {
      programs._1password.enable = true;
      programs._1password-gui.enable = true;
    })

    # Browser-based webapps (per-user configuration)
    {
      home-manager.users = mapAttrs
        (name: userCfg:
          let
            # Get user-level webapp config (with mynixos opinionated defaults)
            userWebapps = userCfg.webapps or { };
          in
          mkIf (userWebapps.enable or false) {
            # Allow chromium unfree in home-manager context
            nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
              "chromium"
              "chromium-unwrapped"
              "widevine-cdm"
            ];

            # Icon theme packages
            home.packages = with pkgs; [
              papirus-icon-theme
              adwaita-icon-theme
            ];

            # Configure webApps (using per-user config)
            programs.webApps = {
              enable = true;
              browser = chromiumWithWidevine;

              apps = mkMerge [
                (mkWebapp {
                  name = "gmail";
                  url = "https://mail.google.com";
                  icon = "gmail";
                  categories = [ "Network" "Email" "Office" ];
                  mimeTypes = [ "x-scheme-handler/mailto" ];
                  enabled = userWebapps.gmail or defaults.gmail;
                })
                (mkWebapp {
                  name = "vscode";
                  url = "https://vscode.dev";
                  icon = "code";
                  categories = [ "Development" "TextEditor" ];
                  enabled = userWebapps.vscode or defaults.vscode;
                })
                (mkWebapp {
                  name = "github";
                  url = "https://github.com";
                  icon = "github-desktop";
                  categories = [ "Development" "Network" ];
                  enabled = userWebapps.github or defaults.github;
                })
                (mkWebapp {
                  name = "spotify";
                  url = "https://open.spotify.com";
                  icon = "spotify";
                  categories = [ "Audio" "Music" "AudioVideo" ];
                  enabled = userWebapps.spotify or defaults.spotify;
                })
                (mkWebapp {
                  name = "discord";
                  url = "https://discord.com/app";
                  icon = "discord";
                  categories = [ "Network" "Chat" "Game" ];
                  enabled = userWebapps.discord or defaults.discord;
                })
                (mkWebapp {
                  name = "whatsapp";
                  url = "https://web.whatsapp.com";
                  icon = "whatsapp";
                  categories = [ "Network" "Chat" "InstantMessaging" ];
                  enabled = userWebapps.whatsapp or defaults.whatsapp;
                })
                (mkWebapp {
                  name = "youtube";
                  url = "https://youtube.com";
                  icon = "youtube";
                  categories = [ "AudioVideo" "Network" "Video" ];
                  enabled = userWebapps.youtube or defaults.youtube;
                })
                (mkWebapp {
                  name = "netflix";
                  url = "https://netflix.com";
                  icon = "netflix";
                  categories = [ "AudioVideo" "Video" "Network" ];
                  enabled = userWebapps.netflix or defaults.netflix;
                })
                (mkWebapp {
                  name = "twitch";
                  url = "https://twitch.tv";
                  icon = "twitch";
                  categories = [ "AudioVideo" "Video" "Network" "Game" ];
                  enabled = userWebapps.twitch or defaults.twitch;
                })
                (mkWebapp {
                  name = "zoom";
                  url = "https://zoom.us/signin";
                  icon = "zoom";
                  categories = [ "Network" "VideoConference" "Office" ];
                  enabled = userWebapps.zoom or defaults.zoom;
                })
                (mkWebapp {
                  name = "chatgpt";
                  url = "https://chat.openai.com";
                  icon = "openai";
                  categories = [ "Network" "Office" "Education" ];
                  enabled = userWebapps.chatgpt or defaults.chatgpt;
                })
                (mkWebapp {
                  name = "claude";
                  url = "https://claude.ai";
                  icon = "anthropic";
                  categories = [ "Network" "Office" "Education" ];
                  enabled = userWebapps.claude or defaults.claude;
                })
                (mkWebapp {
                  name = "grok";
                  url = "https://grok.com";
                  icon = "x";
                  categories = [ "Network" "Office" "Education" ];
                  enabled = userWebapps.grok or defaults.grok;
                })
                (mkWebapp {
                  name = "x";
                  url = "https://x.com";
                  icon = "twitter";
                  categories = [ "Network" "News" ];
                  enabled = userWebapps.x or defaults.x;
                })
              ];
            };
          })
        config.my.users;
    }
  ]);
}
