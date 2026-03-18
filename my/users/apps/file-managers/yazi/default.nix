{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        let
          fileManager = userCfg.environment.FILE_MANAGER;
          hasYazi = fileManager != null && fileManager.enable && fileManager.package.pname or "" == "yazi";
        in
        mkIf hasYazi {
          home.packages = with pkgs; [
            yazi
          ];

          programs.yazi = mkMerge [
            {
              enable = true;
              inherit (fileManager) package;
              enableBashIntegration = true;
              enableFishIntegration = true;
              enableZshIntegration = true;
            }
            # Merge settings if provided
            fileManager.settings
          ];
        }
      )
      (activeUsers config.my.users);
  };
}
