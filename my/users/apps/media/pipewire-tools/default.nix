args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.tools.pipewireTools";
  option = {
    name = "PipeWire Tools";
    default = false;
    description = "PipeWire CLI tools";
  };
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      # PipeWire CLI tools
      pipewire
    ];
  };
}
