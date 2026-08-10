# Git forge transport.
#
# Declared beside ./default.nix, the only thing that reads it. Not an mkApp
# module — git is always on and has no `enable` — so the option lives in this
# sibling file, the same shape claude-code and 1password use.
#
# Common, and deliberately not a platform split: which transport works is a fact
# about the CREDENTIAL a host holds, not about its kernel. yoga and skyspy-dev
# answer to a YubiKey over SSH; aether5d-dev answers to a gh token over HTTPS.
# A darwin host with a provisioned Secure Enclave key would want "ssh" again, and
# stating it per host is what lets it.
{ lib, ... }:

{
  options.my.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.apps.dev.tools.git.protocol = lib.mkOption {
        type = lib.types.enum [ "ssh" "https" ];
        default = "ssh";
        description = ''
          How git reaches the forges.

          "ssh" rewrites `https://` forge URLs to their SSH form, so a URL
          written down anywhere — a `cloneConfigRepo`, a README, a `go get` —
          authenticates with an agent-held key instead of asking for a password.
          This covers github.com, gitlab.com and bitbucket.org, matching the
          three hosts my/users/apps/ssh configures.

          "https" leaves URLs alone and installs the forge CLI as git's
          credential helper, so the token `gh`/`glab` already holds is what
          authenticates. Use this on a host with no SSH identity the forge
          accepts.

          The two modes deliberately cover different sets. bitbucket.org has no
          packaged CLI holding a token, so under "https" it gets no helper from
          here and falls back to git's own credential store — which is the
          honest outcome, not an oversight.
        '';
      };
    });
  };
}
