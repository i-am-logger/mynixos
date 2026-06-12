args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "graphical.browsers.chromium";
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
