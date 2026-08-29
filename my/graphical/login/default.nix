# my.environment.login — the graphical login's mechanism.
#
# The intent (backend + look) is declared in my/environment/options.nix;
# this file turns it into services. The vogix LOOK's machinery — the SDDM
# theme package, the theme.conf palette, the Hyprland Lua greeter
# compositor config, /var/lib/vogix/greeter — lives in vogix's NixOS module
# (vogix.greeter), which my/theming/vogix enables; here mynixos owns only
# what is host policy: which backend runs, autologin, session registration
# and the persistence of the greeter drop zone.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.environment.login;
  vogixLook = cfg.look == "vogix";
in
{
  config = mkIf config.my.graphical.enable (mkMerge [
    {
      assertions = [
        {
          assertion = !vogixLook || (config.my.theming.enable && config.my.theming.vogix.enable);
          message = ''
            my.environment.login.look = "vogix" requires my.theming.enable and
            my.theming.vogix.enable: the greeter surface is rendered by the
            theme system it displays. Use look = "stock" without theming.
          '';
        }
        {
          # The vogix look IS the SDDM QML greeter — no other backend has a
          # themed greeter, so accepting the pair silently would hand a host
          # stock tuigreet while its config claims otherwise.
          assertion = !vogixLook || cfg.backend == "sddm";
          message = ''
            my.environment.login.look = "vogix" is SDDM-only. A non-sddm
            backend needs look = "stock" (greetd's text greeter is tuigreet).
          '';
        }
        {
          assertion = !cfg.autologin.enable || cfg.autologin.user != null;
          message = "my.environment.login.autologin.enable needs autologin.user";
        }
      ];

      # greetd is the one backend with no X11 anywhere; the others keep
      # xserver on (nixpkgs' own modules lean on it).
      services.xserver.enable = mkDefault (cfg.backend != "greetd");
    }

    (mkIf (cfg.backend == "greetd") {
      services.greetd = {
        enable = true;
        settings.default_session = {
          # start-hyprland (Hyprland's watchdog wrapper), not bare Hyprland:
          # launching directly trips its "highly advised against" warning
          # (main.cpp:261) and skips proper Nix session-env setup. Needs
          # os-release NAME="NixOS" (set in my/system/core).
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd start-hyprland";
          user = "greeter";
        };
      };
    })

    (mkIf (cfg.backend == "sddm") {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
    })

    (mkIf (cfg.backend == "gdm") {
      services.displayManager.gdm.enable = true;
    })

    (mkIf (cfg.backend == "lightdm") {
      services.xserver.displayManager.lightdm.enable = true;
    })

    (mkIf cfg.autologin.enable {
      services.displayManager = {
        autoLogin = {
          enable = true;
          inherit (cfg.autologin) user;
        };
        # nixpkgs requires a default session for autologin.
        defaultSession = cfg.session;
      };
      # Autologin skips the authenticate step — and with it any configured
      # security key. A silent skip of that morphism is a decision the host
      # should see.
      warnings = optional (config.my.hardware.securityKeys.yubico.enable or false)
        "my.environment.login.autologin bypasses the YubiKey at login (the key stays required for sudo/TTY/lock).";
    })

    # The vogix greeter's runtime-follow drop zone survives reboots on
    # impermanent hosts (theme + wallpaper reference, not secrets).
    (mkIf (vogixLook && cfg.backend == "sddm") {
      my.system.persistence.features.systemDirectories = [ "/var/lib/vogix/greeter" ];
    })
  ]);
}
