# The infra half of ./insecure.nix: the Radicle forge's services
# (my.infra.radicle) run the same radicle-node. Imported only by
# platforms/linux.nix, where my.infra is declared.
{ config, lib, ... }:

{
  config = lib.mkIf config.my.infra.radicle.enable {
    nixpkgs.config.permittedInsecurePackages = [ (import ./insecure-package.nix) ];
  };
}
