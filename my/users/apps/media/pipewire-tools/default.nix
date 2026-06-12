args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "media.tools.pipewireTools";
  home = { pkgs, ... }: {
    home.packages = with pkgs; [
      # PipeWire CLI tools
      pipewire
    ];
  };
}
