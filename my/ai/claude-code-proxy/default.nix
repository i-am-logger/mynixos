{ activeUsers, config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.ai.claudeCodeProxy;

  claude-code-proxy = pkgs.rustPlatform.buildRustPackage {
    pname = "claude-code-proxy";
    version = "0.4.0";

    src = pkgs.fetchCrate {
      pname = "claude-code-proxy";
      version = "0.4.0";
      hash = "sha256-dUjBBakdUtCkS6ZOTted2PDvK1QnABfL2ddnWtLu/5Y=";
    };

    cargoHash = "sha256-N9kHKV8bIcWw0gFocA+nfGJq/DYr9p66td7CoV6tZcw=";

    meta = {
      description = "OpenAI-compatible API proxy for Claude Code CLI";
      mainProgram = "claude-code-proxy";
    };
  };
in
{
  config = mkIf cfg.enable {
    # Per-user systemd service via home-manager (needs ~/.claude credentials)
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.ai.enable or false) {
          home.packages = [ claude-code-proxy ];

          systemd.user.services.claude-code-proxy = {
            Unit = {
              Description = "Claude Code OpenAI-compatible proxy";
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };

            Service = {
              Environment = [
                "PROXY_API_KEY=${cfg.apiKey}"
              ];
              ExecStart = "${claude-code-proxy}/bin/claude-code-proxy --host 127.0.0.1 --port ${toString cfg.port} --model ${cfg.model}";
              Restart = "on-failure";
              RestartSec = 5;
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        })
      (activeUsers config.my.users);
  };
}
