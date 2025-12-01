{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.users;
in
{
  config = mkIf (cfg != {}) {
    # Generate NixOS users from my.features.users
    users.users = mapAttrs (name: userCfg: {
      isNormalUser = true;
      description = userCfg.fullName;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
      shell = if userCfg.shell == "fish" then pkgs.fish
              else if userCfg.shell == "zsh" then pkgs.zsh
              else pkgs.bash;
      packages = userCfg.packages;
    }) cfg;

    # Enable required programs based on user shells
    programs.fish.enable = mkIf (any (u: u.shell == "fish") (attrValues cfg)) true;
    programs.zsh.enable = mkIf (any (u: u.shell == "zsh") (attrValues cfg)) true;

    # TODO: Generate Home Manager configs
    # This will be added in Phase 2.2
  };
}
