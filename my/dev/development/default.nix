{ activeUsers, config, lib, pkgs, ... }:

with lib;

# Development infrastructure. Container ENGINES are not here: they are
# my.virtualisation.containers (my/virtualisation/containers/engines.nix), which
# reads the same per-user dev.containers switch to pick its defaults.
let
  cfg = config.my.dev;

  # Auto-enable dev tools when any user has dev.enable = true
  anyUserDev = any (userCfg: userCfg.dev.enable or false) (attrValues config.my.users);
in
{
  config = mkMerge [
    # Set system flag
    { my.dev.enable = mkDefault anyUserDev; }

    # Base development groups
    (mkIf cfg.enable {
      users.users = mapAttrs
        (_name: _userCfg: {
          extraGroups = [ "disk" "dialout" ];
        })
        (activeUsers config.my.users);
    })

    # Binfmt emulation (dev feature)
    (mkIf cfg.enable {
      boot.binfmt = {
        emulatedSystems = [ "aarch64-linux" ];

        # AppImage support
        registrations.appimage = {
          wrapInterpreterInShell = false;
          interpreter = "${pkgs.appimage-run}/bin/appimage-run";
          recognitionType = "magic";
          offset = 0;
          mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
          magicOrExtension = ''\x7fELF....AI\x02'';
        };
      };
    })

    # Toolchain caches worth keeping across reboots on an impermanent host.
    (mkIf cfg.enable {
      my.system.persistence.features.userDirectories = [
        ".npm"
        ".cargo"
        ".rustup"
        ".gradle"
        ".m2"
      ];
    })
  ];
}
