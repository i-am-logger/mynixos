args:

# GNU screen: a terminal multiplexer, kept here as the serial console
# (`screen /dev/ttyUSB0 115200`). The multiplexer a session runs in is
# terminal.multiplexer, not this.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.tools.screen";
  option = {
    name = "screen";
    default = false;
    description = "GNU screen, for serial consoles";
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.screen ];
  };
}
