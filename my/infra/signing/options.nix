# Option tree for signing services: a key held by an account of its own, used
# through a socket, so that a client can ask for a signature and cannot read the
# key. An options FRAGMENT loaded through mkOptionsModule from platforms/linux.nix.
{ lib, ... }:

{
  # Type-only second declaration of `my.infra`; see my/infra/radicle/options.nix.
  infra = lib.mkOption {
    type = lib.types.submodule {
      options.signing.services = lib.mkOption {
        description = "Signing services, each with its own account, key and socket at /run/signing/<name>.sock";
        default = { };
        type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
          options = {
            secret = lib.mkOption {
              type = lib.types.nonEmptyStr;
              default = "signing/${name}/key";
              description = ''
                The sops secret holding the private key. It must exist in the
                sops file before this service is declared, because activation
                fails on a secret it cannot decrypt.
              '';
            };

            user = lib.mkOption {
              type = lib.types.nonEmptyStr;
              default = "signing-${name}";
              description = "The account the handler runs as. Nothing else should use it.";
            };

            clients = lib.mkOption {
              type = lib.types.listOf lib.types.nonEmptyStr;
              default = [ ];
              example = [ "alice" ];
              description = ''
                Accounts that may connect to the socket. Access is a named ACL
                entry rather than a group, so it reaches a client's running
                processes without a new login.
              '';
            };

            # No default: what a signature means is decided here, and a default
            # would be a service that signs whatever it is sent.
            handler = lib.mkOption {
              type = lib.types.package;
              description = ''
                The program run for each connection, by its mainProgram. Standard
                input and output are the connection, and the caller's identity is
                SO_PEERCRED on it. The key is at
                `$CREDENTIALS_DIRECTORY/signing-key`. Whatever it writes to
                standard error reaches the journal, so it must not print the key.
              '';
            };

            handlerArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments passed to the handler.";
            };

            readOnlyPaths = lib.mkOption {
              type = lib.types.listOf lib.types.nonEmptyStr;
              default = [ ];
              description = ''
                Paths the handler can read. /home is empty to it and it has no
                network, so what it checks before signing has to be listed here.
              '';
            };
          };
        }));
      };
    };
  };
}
