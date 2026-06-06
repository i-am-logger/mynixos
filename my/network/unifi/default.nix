{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.my.network.unifi;
  secretsCfg = config.my.secrets;

  apiKeyPath = config.sops.secrets.${cfg.apiKeySecret}.path or null;
  desiredStatePath = config.sops.secrets.${cfg.desiredStateSecret}.path or null;

  reconciler = pkgs.writeShellApplication {
    name = "unifi-reconciler";
    runtimeInputs = with pkgs; [
      curl
      jq
      yq-go
      diffutils
      coreutils
    ];
    text = builtins.readFile ./reconciler.sh;
  };
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = secretsCfg.enable;
        message = "my.network.unifi requires my.secrets.enable = true (API key + desired state come from sops).";
      }
    ];

    sops.secrets.${cfg.apiKeySecret} = {
      mode = "0400";
      inherit (cfg) owner;
    };

    sops.secrets.${cfg.desiredStateSecret} = {
      mode = "0400";
      inherit (cfg) owner;
    };

    environment.systemPackages = [ reconciler ];

    environment.variables = {
      UNIFI_URL = cfg.controller.url;
      UNIFI_SITE = cfg.controller.site;
      UNIFI_API_KEY_FILE = apiKeyPath;
      UNIFI_DESIRED_STATE = desiredStatePath;
    };
  };
}
