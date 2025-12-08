{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        let
          browser = userCfg.environment.BROWSER;
          hasFirefox = browser != null && browser.enable && browser.package.pname or "" == "firefox";
        in
        mkIf hasFirefox {
          programs.firefox = mkMerge [
            {
              enable = true;
              package = browser.package;
            }
            # Merge settings if provided
            browser.settings
          ];
        }
      )
      config.my.users;
  };
}
