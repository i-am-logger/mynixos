{ config, lib, pkgs, ... }:

with lib;

let
  # Auto-enable graphical when any user has graphical = true
  anyUserGraphical = any (userCfg: userCfg.graphical or false) (attrValues config.my.users);
in
{
  config = mkIf anyUserGraphical (mkMerge [
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

      # Minimal display manager for Hyprland
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
            user = "greeter";
          };
        };
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

    # Audio tools are now in my.hardware.audio, not in graphical
  ]);
}
