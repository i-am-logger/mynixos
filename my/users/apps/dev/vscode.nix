{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    # System-level VSCode dependencies (for all users who enable it)
    environment.systemPackages = mkIf (any (u: u.apps.dev.vscode or false) (attrValues config.my.users)) (with pkgs; [
      libsecret # For keyring integration
      libxkbcommon
    ]);

    # Allow VSCode (unfree)
    nixpkgs.config.allowUnfreePredicate = mkIf (any (u: u.apps.dev.vscode or false) (attrValues config.my.users))
      (pkg:
        builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
          "vscode"
          "vscode-with-extensions"
        ]);

    # Per-user VSCode installation via home-manager
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.dev.vscode {
        programs.vscode = {
          enable = true;
          package = pkgs.vscode;
        };
      })
      config.my.users;
  };
}
