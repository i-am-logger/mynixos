# macOS user accounts.
#
# The NixOS counterpart (./default.nix) builds a full account: isNormalUser,
# extraGroups, hashedPasswordFile, shell, security.sudo rules. None of that
# applies here. macOS accounts are created by the OS -- by Setup Assistant or by
# an admin -- and nix-darwin only manages an account it is explicitly told to
# manage via `users.knownUsers`, which gates dscl/sysadminctl creation and
# DELETION.
#
# So this deliberately stays minimal: tell nix-darwin where the home directory
# is, and nothing else. `knownUsers` is left alone on purpose -- adding a
# pre-existing admin account to it would put account deletion under the
# configuration's control, which is not a trade worth making for a laptop's
# primary user.
#
# Driven from `my.users` like every other mynixos module, so a host does not
# restate its users; `activeUsers` filters to fully-configured ones.
#
# Imported only by platforms/darwin.nix.
{ activeUsers, config, lib, pkgs, ... }:

let
  users = activeUsers config.my.users;
  shells = lib.unique (lib.filter (s: s != null) (lib.mapAttrsToList (_: u: u.shell) users));
in
{
  config = {
    # `packages` means the same thing here as on NixOS: nix-darwin builds
    # /etc/profiles/per-user/<name> from it and prepends that to
    # environment.profiles, so the option needs no platform-specific reading.
    users.users = lib.mapAttrs
      (name: userCfg: {
        inherit name;
        inherit (userCfg) packages;
        home = lib.mkDefault "/Users/${name}";
      })
      users;

    # `shell` does the two things that are within reach on macOS: it makes the
    # chosen shell a legal chsh(1) target, and it turns on the /etc/<shell>rc that
    # puts the Nix profiles on PATH -- without which Apple's /etc/zprofile runs
    # path_helper and reorders /usr/bin ahead of everything Nix installs.
    #
    # Changing the login shell itself stays a one-time `chsh -s`, because
    # nix-darwin only rewrites it for accounts listed in `users.knownUsers`, which
    # this module deliberately leaves alone (see the header). That asymmetry with
    # NixOS is the platform's, recorded here rather than modelled away.
    environment.shells = map (s: pkgs.${s}) shells;
    programs = lib.genAttrs shells (_: { enable = true; });
  };
}
