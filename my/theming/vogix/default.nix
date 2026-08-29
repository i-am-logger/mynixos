# Vogix implementation module
# Wires vogix NixOS and Home Manager modules based on my.theming.vogix configuration
# Also wires kanata service for behavior/modes (evdev key remapping)
{ activeUsers
, config
, lib
, vogix
, ...
}:

with lib;

let
  cfg = config.my.theming;
  vogixCfg = cfg.vogix;

in
{
  imports = [
    vogix.nixosModules.default
  ];

  # The vogix desktop shell's contribution to the `graphical.shell`
  # distributed enum — and, with waybar deleted, the enum's DEFAULT OWNER:
  # vogix whenever the theming gates are up (system theming + this user's
  # theming.vogix, which the mynixos injector defaults on for graphical
  # users), the bare "none" otherwise. The default is computed rather than
  # written to my.users from here — that write recurses. Declared
  # unconditionally (this module is always imported on Linux); a mismatch
  # between selection and gates is made loud by the assertion below.
  options.my.users = mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: {
      options.graphical = mkOption {
        type = types.submodule {
          options.shell = mkOption {
            type = types.enum [ "vogix" ];
            default =
              if cfg.enable && vogixCfg.enable && (config.theming.vogix.enable or false)
              then "vogix"
              else "none";
            defaultText = literalExpression ''"vogix" when theming is enabled system-wide and for this user, else "none"'';
          };
        };
      };
    }));
  };

  config = mkMerge [
    # Selecting the vogix shell without the theme system that renders it
    # would silently produce a bare desktop — fail the build instead. Lives
    # outside the theming gate on purpose: it must fire exactly when the
    # gates are off.
    {
      assertions = [{
        assertion = all
          (userCfg:
            (userCfg.graphical.shell or "") != "vogix"
            || (cfg.enable && vogixCfg.enable && (userCfg.theming.vogix.enable or false)))
          (attrValues config.my.users);
        message = ''
          graphical.shell = "vogix" requires my.theming.enable,
          my.theming.vogix.enable and the user's theming.vogix.enable: the
          vogix shell is rendered by the theme system it displays.
        '';
      }];
    }

    (mkIf (cfg.enable && vogixCfg.enable) {
      # Add vogix overlay to make pkgs.vogix available
      nixpkgs.overlays = [ vogix.overlays.default ];

      # Allow vogix unfree license
      my.system.allowedUnfreePackages = [ "vogix" "vogix-desktop-qml" "vogix-sddm-theme" "vogix-plymouth" ];

      # Enable vogix at the NixOS level (console colors, hardware, etc.) and
      # auto-enable its hardware modules from the mynixos hardware config.
      vogix = {
        enable = true;
        hardware.kraken-elite.enable = config.my.hardware.cooling.nzxt.kraken-elite-rgb.elite-240-rgb.enable;
        hardware.keychron-k2-he.enable = config.my.hardware.peripherals.keychron.k2-he.enable;
        # The vogix greeter mechanism (SDDM theme.conf from the first vogix
        # user's palette, the Hyprland Lua greeter compositor, the
        # /var/lib/vogix/greeter drop zone) follows the login intent.
        greeter = {
          enable = config.my.graphical.enable
            && config.my.environment.login.backend == "sddm"
            && config.my.environment.login.look == "vogix";
          compositor = config.my.environment.login.compositor;
        };
        # Boot splash from the same palette (text-only script theme —
        # nothing to recolor). mkDefault: a host turns it off in one line.
        plymouth.enable = mkDefault config.my.graphical.enable;
      };

      # With the theme system on, the login defaults to the vogix-themed
      # SDDM greeter — tuigreet (greetd) stays one line away as the text
      # fallback, exactly like every other predecessor this effort retired.
      my.environment.login = {
        backend = mkDefault "sddm";
        look = mkDefault "vogix";
      };

      # Configure home-manager for each user with vogix enabled
      home-manager.users = mapAttrs
        (
          _name: userCfg:
            let
              userVogixCfg = userCfg.theming.vogix or { };
              userEnabled = userVogixCfg.enable or false;
            in
            mkIf userEnabled {
              imports = [ vogix.homeManagerModules.default ];

              # Propagate the vogix overlay to home-manager's pkgs so
              # `pkgs.vogix` resolves via the flake's devenv build instead
              # of falling back to packages/vogix.nix (which would re-build
              # vogix via rustPlatform and need outputHashes for git deps).
              nixpkgs.overlays = [ vogix.overlays.default ];

              programs.vogix = {
                enable = true;
                # Daemon does session auto-save and (since 0.6.4+) submap-mode telemetry
                # to ~/.local/state/vogix/modes.log — required for keybinding ergonomics
                # analysis. Cheap (one socket, no polling), so always on.
                enableDaemon = true;
                # Auto-SAVE stays on; auto-RESTORE does not. The daemon restores
                # whatever the 'last' snapshot holds, however old, so a machine that
                # has been off for a while comes back to a long-stale desktop with
                # every window relaunched at once -- enough to reach the OOM killer.
                # `vogix session restore` is the deliberate way to ask for it.
                # mkDefault, so a host that wants the behaviour can still opt in.
                autoRestoreSession = mkDefault false;
                appearance = {
                  scheme = userVogixCfg.scheme or "vogix16";
                  theme = userVogixCfg.theme or "yoga";
                  variant = userVogixCfg.variant or "night";
                };
                # Pass hardware theme apply commands from NixOS to home-manager
                themeApply = config.vogix.hardware.themeApply;

                # Pointer preferences belong to the person (my.users.<name>.input),
                # not to the theme system: route them into vogix's Hyprland
                # generation, whose own defaults are neutral. Without this the
                # per-user options were silently ignored whenever vogix owned the
                # Hyprland config.
                behavior.input = {
                  inherit (userCfg.input) leftHanded naturalScroll;
                  sensitivity = userCfg.input.accelSpeed;
                };

                # The desktop shell follows the user's `graphical.shell`
                # selection: the bar, its theme.json contract, desktop.json and
                # the vogix-desktop unit exist exactly when this user chose the
                # vogix shell. mkDefault so a host can force the contract on
                # without the shell (or off with it).
                desktop.enable = mkDefault
                  ((userCfg.graphical.enable or false) && userCfg.graphical.shell == "vogix");

                # Idle staging is the PERSON's policy
                # (my.users.<n>.graphical.idle); the shell just renders it.
                desktop.idle = {
                  screensaver = mkDefault userCfg.graphical.idle.screensaver;
                  dim = mkDefault userCfg.graphical.idle.dim;
                  lock = mkDefault userCfg.graphical.idle.lock;
                  screenOff = mkDefault userCfg.graphical.idle.screenOff;
                  suspend = mkDefault userCfg.graphical.idle.suspend;
                };

                # Runtime follow for the greeter: with the vogix greeter on,
                # every theme switch syncs the live palette into
                # /var/lib/vogix/greeter (warn-only themeApply hook).
                greeter.sync = mkDefault config.vogix.greeter.enable;
              };
            }
        )
        (activeUsers config.my.users);
    })
  ];
}
