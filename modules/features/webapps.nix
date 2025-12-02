{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.graphical.webapps;

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
  config = mkIf cfg.enable (mkMerge [
    # Allow unfree packages for webapps (chromium, widevine, etc.)
    # Use allowUnfree = true instead of predicate to ensure it works at all evaluation levels
    {
      nixpkgs.config.allowUnfree = true;
    }

    # Electron apps
    (mkIf (cfg.slack || cfg.signal) {
      environment.systemPackages =
        (optional cfg.slack (wrapElectronApp pkgs.slack "slack")) ++
        (optional cfg.signal (wrapElectronApp pkgs.signal-desktop "signal-desktop"));
    })

    # 1Password
    (mkIf cfg.onePassword {
      programs._1password.enable = true;
      programs._1password-gui.enable = true;
    })

    # Browser-based webapps
    {
      home-manager.users = mapAttrs (name: userCfg: {
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

        # Configure webApps
        programs.webApps = {
          enable = true;
          browser = chromiumWithWidevine;

          apps = mkMerge [
            (mkWebapp { name = "gmail"; url = "https://mail.google.com"; icon = "gmail";
                        categories = [ "Network" "Email" "Office" ];
                        mimeTypes = [ "x-scheme-handler/mailto" ]; enabled = cfg.gmail; })
            (mkWebapp { name = "vscode"; url = "https://vscode.dev"; icon = "code";
                        categories = [ "Development" "TextEditor" ]; enabled = cfg.vscode; })
            (mkWebapp { name = "github"; url = "https://github.com"; icon = "github-desktop";
                        categories = [ "Development" "Network" ]; enabled = cfg.github; })
            (mkWebapp { name = "spotify"; url = "https://open.spotify.com"; icon = "spotify";
                        categories = [ "Audio" "Music" "AudioVideo" ]; enabled = cfg.spotify; })
            (mkWebapp { name = "discord"; url = "https://discord.com/app"; icon = "discord";
                        categories = [ "Network" "Chat" "Game" ]; enabled = cfg.discord; })
            (mkWebapp { name = "whatsapp"; url = "https://web.whatsapp.com"; icon = "whatsapp";
                        categories = [ "Network" "Chat" "InstantMessaging" ]; enabled = cfg.whatsapp; })
            (mkWebapp { name = "youtube"; url = "https://youtube.com"; icon = "youtube";
                        categories = [ "AudioVideo" "Network" "Video" ]; enabled = cfg.youtube; })
            (mkWebapp { name = "netflix"; url = "https://netflix.com"; icon = "netflix";
                        categories = [ "AudioVideo" "Video" "Network" ]; enabled = cfg.netflix; })
            (mkWebapp { name = "twitch"; url = "https://twitch.tv"; icon = "twitch";
                        categories = [ "AudioVideo" "Video" "Network" "Game" ]; enabled = cfg.twitch; })
            (mkWebapp { name = "zoom"; url = "https://zoom.us/signin"; icon = "zoom";
                        categories = [ "Network" "VideoConference" "Office" ]; enabled = cfg.zoom; })
            (mkWebapp { name = "chatgpt"; url = "https://chat.openai.com"; icon = "openai";
                        categories = [ "Network" "Office" "Education" ]; enabled = cfg.chatgpt; })
            (mkWebapp { name = "claude"; url = "https://claude.ai"; icon = "anthropic";
                        categories = [ "Network" "Office" "Education" ]; enabled = cfg.claude; })
            (mkWebapp { name = "grok"; url = "https://grok.com"; icon = "x";
                        categories = [ "Network" "Office" "Education" ]; enabled = cfg.grok; })
            (mkWebapp { name = "x"; url = "https://x.com"; icon = "twitter";
                        categories = [ "Network" "News" ]; enabled = cfg.x; })
          ];
        };
      }) config.my.users;
    }
  ]);
}
