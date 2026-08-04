args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.prompts.starship";
  option = {
    name = "Starship";
    default = false;
    description = "Starship prompt";
    persistedDirectories = [ ".config/starship" ];
  };
  home = _: {
    programs.starship = {
      enable = true;
      # Load settings from the original TOML file
      settings = builtins.fromTOML (builtins.readFile ./config/starship.toml);
    };
  };
}
