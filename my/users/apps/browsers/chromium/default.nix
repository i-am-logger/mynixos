args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.browsers.chromium";
  option = {
    name = "chromium";
    default = false;
    description = "Chromium browser";
    persistedDirectories = [ ];
  };
  unfree = [
    "chromium"
    "chromium-unwrapped"
  ];
  home = _: {
    programs.chromium = {
      enable = true;
    };
  };
}
