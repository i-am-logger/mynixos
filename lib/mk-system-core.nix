# Parts of mkSystem that are identical on NixOS and nix-darwin.
#
# The two platforms differ in which evaluator they call, which module set they
# load, and which flavour of the home-manager / sops-nix modules they use. They
# do NOT differ in how users are validated, how home-manager is configured, how
# the hostname is resolved, or how `my` is threaded through -- and that similarity
# is the reason there is one public `mkSystem` rather than a second
# `mkDarwinSystem`.

{ inputs, lib }:

rec {
  # Two ways to name a host, not three: the `hostname` parameter or
  # `my.system.hostname`. There was a `my.hostname` fallback, but `my.hostname` is
  # not a declared option -- a host setting it would resolve here and then fail
  # module evaluation with "does not exist", so the branch was unreachable.
  resolveHostname = { hostname, my }:
    if hostname != null then hostname
    else if my.system.hostname or null != null then my.system.hostname
    else throw "mkSystem: set either the 'hostname' parameter or my.system.hostname";

  # Every user needs a name and a home-manager config. The per-platform system
  # user (nixosUser / darwinUser) is validated by the caller, because only NixOS
  # requires one.
  assertUsers = users:
    let
      invalid = lib.filter (u: !(u ? name && u ? homeManager)) users;
    in
    assert lib.assertMsg (invalid == [ ])
      "mkSystem: each user must have 'name' and 'homeManager' attributes";
    users;

  # home-manager wiring. Identical on both platforms -- which is exactly why
  # mynixos's 60-odd per-user app modules port to darwin unchanged: they only
  # ever write `home-manager.users.<name>.*`.
  #
  # `useUserPackages` yes, `useGlobalPkgs` deliberately NOT: mynixos propagates
  # allowed-unfree per user through its own `my.system.allowedUnfreePackages`,
  # and useGlobalPkgs would replace home-manager's pkgs and break that.
  homeManagerConfig = users: {
    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };

      users = lib.genAttrs (map (u: u.name) users) (
        name:
        let user = lib.findFirst (u: u.name == name) null users;
        in
        assert lib.assertMsg (user != null) "mkSystem: user '${name}' not found in users list";
        { imports = [ user.homeManager ]; }
      );
    };
  };

  # `my` may be a single attrset or a LIST of them. Each element becomes its own
  # module, so overlapping definitions are merged by the module system rather
  # than by `//`: lists concatenate, and two different values for one scalar are
  # a hard error instead of a silent last-wins.
  #
  # This is what lets a host contribute its own facts -- yoga's github
  # repositories, skyspy-dev's mounts -- without reaching into the shared user
  # profile and re-splicing it by hand.
  myLayers = my: if lib.isList my then my else [ my ];

  # A flattened READ-ONLY view, for the handful of places that must read a scalar
  # out of `my` before any module exists (hostname resolution, the darwin
  # argument rejections). Never used to produce configuration: recursiveUpdate
  # replaces lists wholesale and would silently drop entries.
  myView = my: lib.foldl' lib.recursiveUpdate { } (myLayers my);

  # `my.users.<n>` is authored in the consumer's repo as plain Nix -- an attrset,
  # not a module -- so it has no mkIf/mkDefault to express "only on this
  # platform". `linux` and `darwin` are therefore RESERVED keys inside a user
  # entry, holding values that apply on that platform alone.
  #
  # They are collapsed here and never reach the module system, so `my.*` keeps no
  # platform axis: `my.users.<n>.darwin` is not an option path and never becomes
  # one. A misspelt tier is not stripped, so it lands in the shared layer and
  # fails as an unknown option -- which is the wanted behaviour.
  platformTiers = [ "linux" "darwin" ];

  userTierLayers = platform: users:
    let
      shared = lib.mapAttrs (_: u: builtins.removeAttrs u platformTiers) users;
      scoped = lib.filterAttrs (_: v: v != { })
        (lib.mapAttrs (_: u: u.${platform} or { }) users);
    in
    [ shared ] ++ lib.optional (scoped != { }) scoped;

  # `my.*` passthrough, with layering and per-user platform tiers resolved.
  #
  # `platform` arrives as a literal from whichever mkSystem branch is running. It
  # is a plain function argument -- not a specialArg, not a _module.arg -- and
  # this runs in pure Nix on the attrset the host wrote, BEFORE any module
  # evaluates. It therefore cannot join the config -> imports -> config cycle
  # that ./mk-app.nix and platforms/common.nix document.
  myModules = platform: my:
    lib.concatMap
      (layer:
        let base = builtins.removeAttrs layer [ "users" ]; in
        lib.optional (base != { }) { my = base; }
        ++ map (users: { my.users = users; })
          (lib.optionals (layer ? users) (userTierLayers platform layer.users)))
      (myLayers my);
}
