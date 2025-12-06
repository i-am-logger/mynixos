{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.graphical;
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base desktop configuration with Hyprland
    {
      # System-level Hyprland setup
      systemd.tmpfiles.rules = [
        "d /tmp/hypr 1777 root root -"
      ];

      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      services.xserver = {
        enable = true;
      };

      services.displayManager.gdm = {
        enable = true;
        wayland = true;
      };

      environment.systemPackages = with pkgs; [
        mako # notification daemon
      ];

      # Add users to graphical-related groups
      users.users = mapAttrs
        (name: userCfg: {
          extraGroups = [ "input" "gpu" "video" "render" ];
        })
        (filterAttrs (name: userCfg: userCfg.fullName or null != null) config.my.users);

      # 1Password integration
      programs._1password.enable = true;
      programs._1password-gui.enable = true;

      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
          "1password-gui"
          "1password"
          "1password-cli"
          "chromium"
          "chromium-unwrapped"
        ];
    }

    # Browser configuration
    (mkIf cfg.browser.enable {
      programs.chromium = {
        enable = true;
        extensions = [
          "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password extension
        ];
      };
    })

    # Audio tools are now in my.hardware.audio, not in graphical
  ]);
}
