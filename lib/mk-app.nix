# mkApp — collapse the repeated per-user "enable an app via home-manager"
# boilerplate shared by the simple app modules under my/users/apps/.
#
# Usage (in an app's default.nix):
#
#   { mkApp, ... } @ args:
#   mkApp args {
#     path = "graphical.terminals.alacritty";          # under userCfg.apps
#     home = { ... }: { programs.alacritty.enable = true; };
#   }
#
# Spec fields:
#   path   : dotted path under `userCfg.apps` to the app submodule. The submodule
#            must expose `.enable`. e.g. "graphical.terminals.alacritty".
#   option : optional mkAppOption spec ({ name, description, default ? false,
#            persistedDirectories ? [], persistedFiles ? [], extraOptions ? {} }).
#            When present, the app DECLARES its own option at `path` instead of
#            relying on a central options file.
#   home   : function producing the per-user home-manager config. It receives the
#            full module-args set extended with { cfg, userCfg, name } where `cfg`
#            is the app submodule located at `path`. Defaults to producing {}.
#   unfree : optional list of package names added to
#            `my.system.allowedUnfreePackages` when ANY user enables the app.
#
# `option` is what makes platform reach enforceable. Declaration and
# implementation come from the same file, so the `platforms/*.nix` that imports
# it decides both at once: an app absent from a platform has no option there, and
# setting it is the module system's own "does not exist" error rather than a
# silent no-op. It also makes a path typo unrepresentable — the declaration and
# the read are built from the same `path` string.
#
# The declaration is built from `lib` ALONE. Capturing `pkgs` in an options
# module would pull `_module.args.pkgs` -> `config.nixpkgs` and recurse, which is
# why `pkgs` below stays inside the lazily-forced `home` path.
#
# App modules import this file directly (relative path) and call it with their
# module args: `(import .../lib/mk-app.nix).mkApp args { ... }`. It is deliberately
# NOT delivered via _module.args — doing so caused infinite recursion, because an
# app module's return value *is* `mkApp args {...}`, forcing mkApp at module
# structure time, and resolving _module.args.mkApp requires the full config.
# For the same reason mkApp self-computes `activeUsers` from config instead of
# taking the `activeUsers` _module.arg (which would force app modules to name an
# otherwise-unused argument).
{
  mkApp = moduleArgs@{ config, lib, ... }: spec:
    let
      inherit (lib) mapAttrs mkIf mkMerge attrByPath splitString any attrValues;

      activeUsers = import ./active-users.nix lib;

      # `pkgs` is a _module.args entry: the module system only injects it into
      # modules that NAME it. The app modules are bare `args:` lambdas (naming
      # pkgs would make deadnix flag it as unused), so they do NOT receive pkgs —
      # `mkSystem` does not pass it via specialArgs either. Source it from config
      # (where the nixpkgs module stores it) so `home` always gets it. In the test
      # harness pkgs IS a specialArg, so it stays in moduleArgs and short-circuits.
      pkgs = moduleArgs.pkgs or config._module.args.pkgs;

      pathList = splitString "." spec.path;
      getCfg = userCfg:
        attrByPath pathList
          (throw "mkApp: no app option at userCfg.apps.${spec.path}")
          userCfg.apps;

      home = spec.home or (_: { });
      unfree = spec.unfree or [ ];

      perUser = mapAttrs
        (name: userCfg:
          let cfg = getCfg userCfg;
          in mkIf cfg.enable (home (moduleArgs // { inherit cfg userCfg name pkgs; })))
        (activeUsers config.my.users);

      anyEnabled = any
        (userCfg: (getCfg userCfg).enable or false)
        (attrValues config.my.users);
      # Declared per-user, so it merges with the other `my.users` submodule
      # declarations rather than redeclaring the attribute.
      optionModule = lib.optionalAttrs (spec ? option) {
        options.my.users = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = lib.setAttrByPath ([ "apps" ] ++ pathList)
              ((import ./app-options.nix { inherit lib; }).mkAppOption spec.option);
          });
        };
      };
    in
    optionModule // {
      config =
        if unfree == [ ] then {
          home-manager.users = perUser;
        } else
          mkMerge [
            (mkIf anyEnabled { my.system.allowedUnfreePackages = unfree; })
            { home-manager.users = perUser; }
          ];
    };
}
