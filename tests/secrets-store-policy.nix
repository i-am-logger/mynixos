# my.secrets must keep sops files OUT of /nix/store.
#
# The store is world-readable and permanent, so a sops file placed there is
# published to every user and every process on the host. The regression this
# guards against is not someone writing a store path on purpose -- it is
# `defaultSopsFile = "${secretsInput}/secrets.yaml"`, which looks like a
# reference to one file and actually copies the whole directory that file sits
# in, along with anything else that happens to be there.
#
# Each case is paired with its opposite: a policy that only ever says "no" is
# indistinguishable from an assertion that never fires, and one that only says
# "yes" is indistinguishable from a policy that is not wired up at all.
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
      modules = baseModules ++ [ baseConfig { my.system.hostname = "sops-policy-test"; } testConfig ];
    }).config;

  # Only the assertions this module raises. Reading every assertion's `message`
  # would force unrelated ones -- nixpkgs' filesystem assertions in particular
  # fire first on a host with no fileSystems, and would stand in for ours.
  ourFailures = cfg:
    map (a: a.message)
      (lib.filter (a: !a.assertion && lib.hasInfix "/nix/store is world-readable" a.message)
        cfg.assertions);

  # A real store path, so the check tests the prefix rule rather than a string
  # that merely looks store-shaped.
  storeFile = "${nixpkgs}/README.md";
  runtimeFile = "/persist/etc/sops/secrets.yaml";

  check = name: cond: detail:
    pkgs.runCommand "secrets-store-policy-${name}" { } (
      if cond then "echo 'PASS: ${name}' > $out"
      else builtins.throw "FAIL: ${name} -- ${detail}"
    );
in
{
  # The default sops file, the fleet-wide setting.
  secrets-store-policy-rejects-store-default = check "rejects-store-default"
    (ourFailures
      (evalWith {
        my.secrets = { enable = true; defaultSopsFile = storeFile; };
      }) != [ ])
    "a store-path defaultSopsFile raised no assertion; secrets would be published to /nix/store silently";

  secrets-store-policy-accepts-runtime-default = check "accepts-runtime-default"
    (ourFailures
      (evalWith {
        my.secrets = { enable = true; defaultSopsFile = runtimeFile; };
      }) == [ ])
    "a runtime-path defaultSopsFile was rejected; the policy is refusing the configuration it exists to encourage";

  # A single per-secret override, which bypasses my.secrets entirely and is the
  # easier one to add without thinking about where the file lands.
  secrets-store-policy-rejects-store-per-secret = check "rejects-store-per-secret"
    (ourFailures
      (evalWith {
        my.secrets = { enable = true; defaultSopsFile = runtimeFile; };
        sops.secrets."some/key" = { sopsFile = storeFile; format = "binary"; key = ""; };
      }) != [ ])
    "a store-path sops.secrets.<name>.sopsFile raised no assertion even though the default was clean";

  # The escape hatch, for encrypted secrets deliberately committed beside the
  # configuration that reads them.
  secrets-store-policy-escape-hatch-permits = check "escape-hatch-permits"
    (ourFailures
      (evalWith {
        my.secrets = { enable = true; allowSecretsInStore = true; defaultSopsFile = storeFile; };
      }) == [ ])
    "allowSecretsInStore = true did not lift the assertion, leaving no way to use upstream sops-nix' normal pattern";

  # validateSopsFiles and the policy are the same switch seen from two sides:
  # sops-nix validates by hashing the file at EVAL time, which only a store path
  # allows. If these ever drift apart, a runtime path fails at evaluation with
  # an unrelated "path does not exist" instead of the message above.
  secrets-store-policy-validation-tracks-policy = check "validation-tracks-policy"
    (
      (evalWith { my.secrets = { enable = true; defaultSopsFile = runtimeFile; }; }).sops.validateSopsFiles == false
      && (evalWith { my.secrets = { enable = true; allowSecretsInStore = true; defaultSopsFile = storeFile; }; }).sops.validateSopsFiles == true
    )
    "sops.validateSopsFiles no longer tracks my.secrets.allowSecretsInStore; a runtime path will fail at eval time with a confusing error";
}
