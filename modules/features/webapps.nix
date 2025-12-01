{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.features.webapps;

  # Helper function to wrap Electron apps
  # TODO: Re-enable libsecret when pass-secret-service is properly configured
  wrapElectronApp = pkg: bin: pkgs.symlinkJoin {
    name = "${pkg.pname or pkg.name}-wrapped";
    paths = [ pkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/${bin} \
        --add-flags "--password-store=basic"
    '';
  };
in
{
  config = mkIf cfg.enable (mkMerge [
    # Base webapps configuration
    {
      # Allow unfree packages for webapps
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
          "slack"
          "signal-desktop"
          "1password-gui"
          "1password"
          "1password-cli"
        ];
    }

    # Electron apps (Slack, Signal)
    (mkIf cfg.electronApps.enable {
      environment.systemPackages = [
        (wrapElectronApp pkgs.slack "slack")
        (wrapElectronApp pkgs.signal-desktop "signal-desktop")
      ];
    })

    # 1Password
    (mkIf cfg.onePassword.enable {
      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
      };
    })
  ]);
}
