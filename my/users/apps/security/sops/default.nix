args:

# sops, the editor for the host's secrets file. Decryption at activation is
# sops-nix's own sops-install-secrets, so a host needs no CLI; whoever edits
# secrets.yaml turns this on.
(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "security.secrets.sops";
  option = {
    name = "sops";
    default = false;
    description = "sops, the editor for encrypted secrets files";
  };
  home = { pkgs, ... }: {
    home.packages = [ pkgs.sops ];
  };
}
