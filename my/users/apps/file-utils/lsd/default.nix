args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.fileUtils.lsd";
  option = {
    name = "lsd";
    default = false;
    description = "LSDeluxe file lister";
    persistedDirectories = [ ];
  };
  home = _: {
    programs.lsd = {
      enable = true;
      settings = {
        date = "+%y-%m-%d %H:%M:%S";
        indicators = true;
        recursion = {
          depth = 2;
        };
        sorting = {
          dir-grouping = "first";
        };
        symlink-arrow = "~>";
        header = true;
        color = {
          when = "auto";
        };
        icons = {
          when = "auto";
        };
        blocks = [ "permission" "user" "group" "size" "date" "name" ];
      };
    };
  };
}
