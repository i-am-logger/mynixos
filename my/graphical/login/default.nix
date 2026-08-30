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

      # The intended session is the DEFAULT everywhere, not only under
      # autologin — a greeter picking a stale remembered session must still
      # start from the right one.
      services.displayManager.defaultSession = mkDefault cfg.session;
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
        # SDDM ≤0.21.0 arms VT_PROCESS (release signal SIGRTMAX) on the
        # session child and then execve()s it, which resets the handler
        # while the kernel still holds the child as VT owner — a VT switch
        # during greeter teardown kills the Wayland session before the
        # compositor starts. Upstream fix is unmerged (sddm/sddm#2204);
        # drop the patch when it lands in the packaged release.
        package = pkgs.kdePackages.sddm.override (prev: {
          sddm-unwrapped = prev.sddm-unwrapped.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./sddm-wayland-session-vt-auto.patch ];
          });
        });
      };

      # nixpkgs' SDDM PAM delegates auth to `substack login`, which drags
      # the fleet's INTERACTIVE pam_u2f (login.u2fAuth, "press the key,
      # then ENTER") into the greeter — a conversation SDDM's helper cannot
      # answer, wedging every login. The per-service `sddm.u2fAuth = false`
      # flag cannot help: the module never consults it, it substacks login
      # wholesale. Replace ONLY the auth section (account/password/session
      # keep the login delegation):
      #
      # - pam_unix first, sufficient: a typed password logs in instantly.
      # - pam_u2f second, sufficient, NON-interactive with cue (`cue
      #   authfile=…`, no `interactive`) — the shape that makes hardware
      #   keys work under prompt-less PAM helpers. Touch-to-login: submit
      #   an empty password, the cue shows on the card, one touch
      #   authenticates. The YubiKey is the PRIMARY login; the password is
      #   the backup.
      security.pam.services.sddm.rules.auth = lib.mkForce (
        {
          unix = {
            control = "sufficient";
            modulePath = "${pkgs.pam}/lib/security/pam_unix.so";
            order = 10900;
            settings = {
              likeauth = true;
              nullok = true;
              try_first_pass = true;
            };
          };
          deny = {
            control = "required";
            modulePath = "${pkgs.pam}/lib/security/pam_deny.so";
            order = 12500;
          };
        } // lib.optionalAttrs config.security.pam.u2f.enable {
          u2f = {
            control = config.security.pam.u2f.control;
            modulePath = "${pkgs.pam_u2f}/lib/security/pam_u2f.so";
            order = 11700;
            settings = config.security.pam.u2f.settings // {
              interactive = false;
            };
          };
        }
      );
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
