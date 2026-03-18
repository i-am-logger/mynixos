{ activeUsers, config, lib, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          browser = userCfg.environment.BROWSER;
          hasFirefox = browser != null && browser.enable && browser.package.pname or "" == "firefox";
        in
        mkIf hasFirefox {
          programs.firefox = mkMerge [
            {
              enable = true;
              inherit (browser) package;
            }
            # Merge settings if provided
            browser.settings
          ];
        }
      )
      (activeUsers config.my.users);
  };
}
