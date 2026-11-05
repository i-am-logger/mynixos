# my.infra.signing: the shape of a signing service, and the cases it refuses.
#
# tests/vm-signing-service.nix proves the runtime claims. This proves, cheaply,
# that the unit stays shaped to make them, and that a host declaring no service
# gets nothing, including no sops secret to fail activation on.
{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseModules baseConfig;

  evalWith = testConfig:
    (lib.nixosSystem {
      inherit specialArgs;
      modules = baseModules ++ [ baseConfig { my.system.hostname = "signing-test"; } testConfig ];
    }).config;

  handler = pkgs.writeShellApplication {
    name = "fixture-handler";
    text = "exit 1";
  };

  withService = extra: evalWith (lib.recursiveUpdate
    {
      my.secrets = { enable = true; defaultSopsFile = "/persist/etc/sops/secrets.yaml"; };
      users.users.alice = { isNormalUser = true; };
      my.infra.signing.services.tool = {
        inherit handler;
        clients = [ "alice" ];
      };
    }
    extra);

  ourFailures = cfg:
    map (a: a.message)
      (lib.filter (a: !a.assertion && lib.hasInfix "my.infra.signing" a.message) cfg.assertions);

  service = withService { };
  unit = service.systemd.services."signing-tool@".serviceConfig;
  socket = service.systemd.sockets.signing-tool.socketConfig;

  check = name: cond: detail:
    pkgs.runCommand "signing-service-${name}" { } (
      if cond then "echo 'PASS: ${name}' > $out"
      else builtins.throw "FAIL: ${name} -- ${detail}"
    );
in
{
  signing-service-accepts-valid = check "accepts-valid"
    (ourFailures service == [ ])
    "a complete service raised an assertion: ${toString (ourFailures service)}";

  signing-service-requires-secrets = check "requires-secrets"
    (ourFailures (withService { my.secrets.enable = false; }) != [ ])
    "a service with my.secrets off raised no assertion";

  signing-service-rejects-unknown-client = check "rejects-unknown-client"
    (ourFailures (withService { my.infra.signing.services.tool.clients = [ "nobody-here" ]; }) != [ ])
    "a client with no account raised no assertion, and setfacl would fail at socket start";

  signing-service-rejects-container = check "rejects-container"
    (ourFailures (withService { boot.isContainer = true; }) != [ ])
    "a container raised no assertion, and LoadCredential cannot work there";

  # The key only ever arrives as a credential, from the root-owned secret.
  signing-service-key-is-a-credential = check "key-is-a-credential"
    (unit.LoadCredential == "signing-key:/run/secrets/signing/tool/key"
      && service.sops.secrets."signing/tool/key".mode == "0400"
      && service.sops.secrets."signing/tool/key".owner or null == null)
    "the key is not delivered by LoadCredential from a root-only secret";

  signing-service-own-account = check "own-account"
    (unit.User == "signing-tool"
      && service.users.users.signing-tool.isSystemUser
      && !(builtins.elem "signing-tool" service.users.users.alice.extraGroups))
    "the handler does not run under an account of its own";

  signing-service-socket-access = check "socket-access"
    (socket.SocketMode == "0600" && socket.Accept
      && lib.hasSuffix "setfacl -m u:alice:rw /run/signing/tool.sock" socket.ExecStartPost)
    "the socket is not closed to everyone but the named clients";

  signing-service-confined = check "confined"
    (unit.PrivateNetwork && unit.ProtectHome == "tmpfs" && unit.ProtectSystem == "strict"
      && unit.CapabilityBoundingSet == "" && unit.NoNewPrivileges)
    "the handler's confinement was loosened";

  # A host with no service must not gain a secret: sops-install-secrets would run
  # and fail on one that isn't in its sops file.
  signing-service-absent-is-inert = check "absent-is-inert"
    (
      let plain = evalWith { }; in
      !(plain.users.users ? signing-tool)
      && !(lib.any (lib.hasPrefix "signing/") (lib.attrNames plain.sops.secrets))
      && !(plain.systemd.sockets ? signing-tool)
    )
    "a host declaring no signing service still gained part of one";
}
