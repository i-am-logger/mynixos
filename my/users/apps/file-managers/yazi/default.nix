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
              # Keep the legacy wrapper name (HM 26.11 changed the default to "y").
              shellWrapperName = "yy";
            }
            # Merge settings if provided
            fileManager.settings
          ];
        }
      )
      (activeUsers config.my.users);
  };
}
