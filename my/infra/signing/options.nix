# Option tree for signing services: a key held by an account of its own, used
# through a socket, so that a client can ask for a signature and cannot read the
# key. An options FRAGMENT loaded through mkOptionsModule from platforms/linux.nix.
{ lib, ... }:

let
  # Checked whenever the attribute set is read: a name becomes a unit name and
  # a socket file name, so it can't hold a `/` or an `@`.
  names = what: attrs:
    let
      bad = lib.filter (name: builtins.match "[a-z][a-z0-9-]*" name == null) (lib.attrNames attrs);
    in
    if bad == [ ] then attrs
    else throw "${what}: ${lib.concatStringsSep ", " bad}: a name is lower case letters, digits and `-`, starting with a letter.";
in
{
  # Type-only second declaration of `my.infra`; see my/infra/radicle/options.nix.
  infra = lib.mkOption {
    type = lib.types.submodule {
      options.signing.releasable = lib.mkOption {
        description = ''
          Pre-release signing for repositories released with releasable: the
          signing service `pre-release`, whose one key signs for every repository
          named here, each through an instance of its own. A repository's policy
          signs with key `/var/lib/signing-pre-release/key.pub` and program
          `releasable signing client --socket /run/signing/<name>.sock`.
        '';
        default = { };
        type = lib.types.submodule {
          options = {
            # No default: the handler decides what a signature means, and this
            # repository has no flake input to take it from.
            package = lib.mkOption {
              type = lib.types.package;
              description = ''
                The releasable package. Each instance runs
                `releasable signing handle --repo <checkout>/.git`, which signs
                only a pre-release, or a release commit, made from a commit that
                checkout's release loop recorded green.
              '';
            };

            repositories = lib.mkOption {
              type = lib.types.attrsOf (lib.types.strMatching "/.*[^/]");
              default = { };
              apply = names "my.infra.signing.releasable.repositories";
              example = { tool = "/home/alice/src/tool"; };
              description = ''
                Each repository's instance name and its main checkout, by
                absolute path: a checkout whose `.git` is a directory, not a
                linked worktree, whose `.git` is a file. An instance reads only
                its own checkout's `.git`, read-only.
              '';
            };

            clients = lib.mkOption {
              type = lib.types.listOf lib.types.nonEmptyStr;
              default = [ ];
              example = [ "alice" ];
              description = "Accounts that may connect to every repository's socket.";
            };
          };
        };
      };

      options.signing.services = lib.mkOption {
        description = ''
          Signing services, each with its own account and key, used through the
          sockets of its instances, at /run/signing/<instance>.sock.
        '';
        default = { };
        type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
          options = {
            user = lib.mkOption {
              type = lib.types.nonEmptyStr;
              default = "signing-${name}";
              description = ''
                The account that generates the key and runs the handler. Nothing else
                should use it. The key is at /var/lib/<user>/key, readable only by this
                account, and the public key beside it at key.pub, readable by anyone.
              '';
            };

            clients = lib.mkOption {
              type = lib.types.listOf lib.types.nonEmptyStr;
              default = [ ];
              example = [ "alice" ];
              description = ''
                Accounts that may connect to every instance's socket. Access is a
                named ACL entry rather than a group, so it reaches a client's
                running processes without a new login.
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

            path = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              example = lib.literalExpression "[ pkgs.git ]";
              description = ''
                Packages whose programs the handler runs by name, put on its PATH.
                A service's PATH holds only the coreutils, findutils, grep, sed and
                systemd, so a handler that runs `git` lists it here.
              '';
            };

            instances = lib.mkOption {
              description = ''
                The ways to the key: each instance is a socket at
                /run/signing/<instance>.sock whose connections run the handler
                with that instance's arguments, seeing only that instance's
                paths. An instance name is unique across every service.
              '';
              default = { };
              apply = names "my.infra.signing.services.${name}.instances";
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
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
              });
            };
          };
        }));
      };
    };
  };
}
