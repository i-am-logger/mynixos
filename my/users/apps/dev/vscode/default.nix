{ config, lib, pkgs, appHelpers, ... }:

with lib;

{
  config = {
    # System-level VSCode dependencies (for all users)
    environment.systemPackages = with pkgs; [
      libsecret # For keyring integration
      libxkbcommon
    ];

    # Allow VSCode (unfree)
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
        "vscode"
        "vscode-with-extensions"
      ];

    # Per-user VSCode installation via home-manager
    home-manager.users = mapAttrs
      (name: userCfg:
        # Enable if: app explicitly enabled OR dev feature enabled
        mkIf (appHelpers.shouldEnable userCfg "dev" "vscode") {
          programs.vscode = {
          enable = true;
          package = pkgs.vscode;
        };
      })
      config.my.users;
  };
}
