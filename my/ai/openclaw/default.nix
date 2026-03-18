{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.ai.openclaw;

  openclaw = pkgs.buildNpmPackage rec {
    pname = "openclaw";
    version = "2026.3.13";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
      hash = "sha256-ZxHZ+MTxK9vc1QkOaGXi7hQbjNo+qo8gJZMEQGog6Wo=";
    };

    sourceRoot = "package";

    postPatch = ''
      cp ${./openclaw-package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-XWDzeIUTv/N79w/Ij8Fdaj+xw84bi+HXB51sG8Jgwo8=";

    nodejs = pkgs.nodejs_22;
    makeCacheWritable = true;
    npmFlags = [
      "--legacy-peer-deps"
      "--ignore-scripts"
    ];
    dontNpmBuild = true;

    postInstall = ''
      cd $out/lib/node_modules/openclaw
      npm rebuild --ignore-scripts 2>/dev/null || true
      cd -
      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/openclaw \
        --add-flags "$out/lib/node_modules/openclaw/openclaw.mjs"
    '';

    nativeBuildInputs = with pkgs; [
      makeWrapper
      python3
    ];

    meta = {
      description = "Multi-channel personal AI assistant";
      mainProgram = "openclaw";
    };
  };

  stateDir = "/var/lib/openclaw";

  openclawConfig = builtins.toJSON (
    lib.recursiveUpdate (
      {
        gateway = {
          port = cfg.port;
          bind = cfg.bind;
          mode = "local";
          auth = {
            mode = "token";
            token = cfg.gatewayToken;
          };
        };
        models = {
          providers = {
            ollama = {
              baseUrl = "http://127.0.0.1:11434";
              models = [
                {
                  id = cfg.ollamaModel;
                  name = cfg.ollamaModel;
                }
              ];
            };
          };
        };
      }
      // lib.optionalAttrs cfg.signal.enable {
        channels = {
          signal =
            {
              account = cfg.signal.account;
              allowFrom = cfg.signal.allowFrom;
            }
            // lib.optionalAttrs (cfg.signal.allowFrom != [ ]) {
              defaultTo = builtins.head cfg.signal.allowFrom;
            };
        };
      }
    ) cfg.extraConfig
  );
in
{
  config = mkIf cfg.enable {

    # CLI available system-wide
    environment.systemPackages = [ openclaw ];

    # Shared client config for CLI users
    environment.etc."openclaw-client.json" = {
      text = builtins.toJSON {
        gateway = {
          port = cfg.port;
          bind = cfg.bind;
          auth = {
            mode = "token";
            token = cfg.gatewayToken;
          };
        };
        models = {
          providers = {
            ollama = {
              baseUrl = "http://127.0.0.1:11434";
              models = [
                {
                  id = cfg.ollamaModel;
                  name = cfg.ollamaModel;
                }
              ];
            };
          };
        };
      };
      mode = "0644";
    };

    environment.variables = {
      OPENCLAW_CONFIG_PATH = "/etc/openclaw-client.json";
    };

    # Gateway service
    systemd.services.openclaw-gateway = {
      description = "OpenClaw Gateway";
      after = [
        "network-online.target"
        "ollama.service"
      ];
      wants = [
        "network-online.target"
        "ollama.service"
      ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        NODE_ENV = "production";
        OPENCLAW_STATE_DIR = "%S/openclaw";
        OPENCLAW_CONFIG_PATH = "%S/openclaw/openclaw.json";
        OPENCLAW_NIX_MODE = "1";
        HOME = "%S/openclaw";
      };

      serviceConfig = {
        ExecStartPre = pkgs.writeShellScript "openclaw-config" ''
          cat > /var/lib/openclaw/openclaw.json <<'CONFIGEOF'
          ${openclawConfig}
          CONFIGEOF
        '';

        ExecStart = ''
          ${openclaw}/bin/openclaw gateway run \
            --bind ${cfg.bind} \
            --port ${toString cfg.port} \
            --token ${cfg.gatewayToken} \
            --allow-unconfigured
        '';

        path = [ pkgs.lsof pkgs.psmisc ];

        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = 30;
        TimeoutStartSec = 60;
        DynamicUser = true;
        StateDirectory = "openclaw";
        StateDirectoryMode = "0750";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    # Persistence handled by StateDirectory + /var/lib/private (already persisted by AI module)
  };
}
