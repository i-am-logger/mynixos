{ activeUsers, config, lib, ... }:

with lib;

{
  # The portable half of XDG: the base-directory variables. home-manager's
  # `xdg.enable` sets XDG_CONFIG_HOME / XDG_DATA_HOME / XDG_CACHE_HOME, which
  # plenty of CLI tools honour on macOS too.
  #
  # The Linux-only half -- xdg-utils and the user-directory scheme -- is in
  # ./linux.nix, imported by platforms/linux.nix alone. Splitting by file rather
  # than guarding by predicate is the same rule the rest of the tree follows: a
  # `mkIf isLinux` with no else-branch inside a module common to both platforms
  # IS the defect, because the option stays reachable and does nothing.
  config = {
    home-manager.users = mapAttrs
      (_name: _userCfg: {
        xdg.enable = true;
      })
      (activeUsers config.my.users);
  };
}
