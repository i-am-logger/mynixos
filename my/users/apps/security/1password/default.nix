{ config, lib, pkgs, ... }:

with lib;

let
  # Check if any user has 1Password enabled
  anyUser1Password = any
    (userCfg: userCfg.apps.security.onePassword.enable or false)
    (attrValues config.my.users);
in
{
  config = mkMerge [
    # System-level 1Password programs (when ANY user enables it)
    (mkIf anyUser1Password {
      programs._1password.enable = true;
      programs._1password-gui.enable = true;

      nixpkgs.config.allowUnfreePredicate = pkg:
        builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
          "1password-gui"
          "1password"
          "1password-cli"
        ];
    })
  ];
}
