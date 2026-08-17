# mynixos Opinionated Defaults: Terminal Apps, Linux
#
# zsh is the login shell (my/users/users/mynixos-linux.nix), so its
# home-manager config is on by default.
#
# bespec builds only on x86_64-linux (packages/bespec/default.nix declares
# `platforms = [ "x86_64-linux" ]`): alsa, dbus and pipewire at build time, and a
# Wayland/Vulkan surface at run time. A CoreAudio backend would be upstream work.
#
# Imported only by platforms/linux.nix.

{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.terminal.enable or false) {
        apps.terminal = {
          shells.zsh.enable = lib.mkDefault true;
          visualizers.bespec.enable = lib.mkDefault true;
        };
      };
    }));
  };
}
