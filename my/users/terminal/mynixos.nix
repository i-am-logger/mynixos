# mynixos Opinionated Defaults: Terminal Apps
#
# Apps enabled when terminal.enable = true. Users override with
# apps.{app}.enable = false.
#
# Apps whose answer differs by platform live in ./mynixos-{linux,darwin}.nix, so
# this file states only what holds everywhere.

{ lib, ... }:

{
  # Inject opinionated defaults into user submodule
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config = lib.mkIf (config.terminal.enable or false) {
        apps.terminal = {
          # Shells. zsh is defaulted per platform in ./mynixos-{linux,darwin}.nix.
          shells = {
            bash.enable = lib.mkDefault true;
            fish.enable = lib.mkDefault false;
          };

          # Prompts
          prompts.starship.enable = lib.mkDefault true;

          # Viewers
          viewers.bat.enable = lib.mkDefault true;
          # feh is handled by graphical feature

          # File utilities
          fileUtils.lsd.enable = lib.mkDefault true;

          # File managers
          # environment.FILE_MANAGER picks the primary file manager.
          fileManagers.mc.enable = lib.mkDefault false;

          # System info
          sysinfo = {
            fastfetch.enable = lib.mkDefault true;
            btop.enable = lib.mkDefault true;
            neofetch.enable = lib.mkDefault false;
          };

          # Network tools
          network.termscp.enable = lib.mkDefault false;

          # Visualizers
          visualizers.cava.enable = lib.mkDefault true;

          # Fun/Eye candy
          fun.pipes.enable = lib.mkDefault false;

          # Note: Multiplexers (herdr, zellij, tmux) are controlled by the
          # terminal.multiplexer setting, not as apps. Each one contributes its
          # own name to that enum from my/users/apps/multiplexers/*/options.nix,
          # and herdr's declaration also carries the enum's default -- so the
          # default deliberately does NOT live in this file, which is gated on
          # terminal.enable.
        };
      };
    }));
  };
}
