{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    # System-level VSCode dependencies (for all users)
    environment.systemPackages = with pkgs; [
      libsecret # For keyring integration
      libxkbcommon
    ];

    # Allow VSCode (unfree)
    my.system.allowedUnfreePackages = [
      "vscode"
      "vscode-with-extensions"
    ];

    # Per-user VSCode installation via home-manager
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.dev.tools.vscode.enable or false) {
          programs.vscode = {
            enable = true;
            package = pkgs.vscode;
          };
        })
      config.my.users;
  };
}
