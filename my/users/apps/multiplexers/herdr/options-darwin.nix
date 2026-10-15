# herdr's macOS-only plugin option.
#
# herdr-focus-notify shows clickable notifications that bring the right
# terminal window and agent pane forward. Its manifest declares `platforms =
# ["macos"]` and its package builds only there (packages/herdr-focus-notify),
# so the option exists only on darwin: a Linux host setting it gets "option
# does not exist" rather than a package that cannot build.
#
# Imported only by platforms/darwin.nix; ./darwin.nix implements it.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.terminal = lib.mkOption {
        type = lib.types.submodule {
          options.herdr.plugins.focusNotify.enable = lib.mkEnableOption ''
            the herdr-focus-notify plugin. It cannot show a notification until
            `alerter` is on PATH, and nixpkgs has no alerter
          '';
        };
      };
    });
  };
}
