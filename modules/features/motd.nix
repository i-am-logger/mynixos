{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.motd;
in
{
  options.my.features.motd = {
    enable = mkEnableOption "message of the day";

    content = mkOption {
      type = types.str;
      default = "";
      description = "MOTD content to display on login";
    };
  };

  config = mkIf cfg.enable {
    users.motd = cfg.content;
  };
}
