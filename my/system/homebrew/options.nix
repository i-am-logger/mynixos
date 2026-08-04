{ lib, ... }:

{
  homebrew = lib.mkOption {
    description = ''
      Homebrew, for the few things Nix genuinely cannot package: Mac App Store
      apps (Apple-ID-bound, DRM'd, unfetchable by Nix) and installers that must
      write outside the store. Everything else should be a derivation.
    '';
    default = { };
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "Homebrew for what Nix cannot package";

        user = lib.mkOption {
          type = lib.types.str;
          description = "User owning the Homebrew prefix";
        };

        casks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "background-music" ];
          description = ''
            Casks to install. Keep this short — anything that is a plain signed
            .app belongs in a Nix derivation instead.
          '';
        };

        masApps = lib.mkOption {
          type = lib.types.attrsOf lib.types.ints.positive;
          default = { };
          example = { Tailscale = 1475387142; };
          description = ''
            Mac App Store apps by numeric ID. Requires being signed into the App
            Store; mas can only install titles already tied to that Apple ID.
          '';
        };

        cleanup = lib.mkOption {
          type = lib.types.enum [ "none" "uninstall" "zap" ];
          default = "uninstall";
          description = ''
            What to do with brew packages installed but not declared here.
            "uninstall" is what makes this declarative rather than additive;
            "zap" also deletes their data.
          '';
        };
      };
    };
  };
}
