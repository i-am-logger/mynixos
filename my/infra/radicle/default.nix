# Tailnet-private Radicle forge: node + httpd + declarative seeding.
#
# Thin typed wrapper over nixpkgs' services.radicle, the same shape as
# my/infra/k3s over services.k3s. CI and GitHub mirroring live in the sibling
# files named in `imports` below.
#
# The privacy stance is layered, and none of it is `network = "test"` (which
# only empties the bootstrap list -- a "test" node still talks to any main
# node that reaches it):
#   - reachability: listen on [::] but open the port on tailscale0 ONLY, and
#     advertise no externalAddresses unless the host layer says so;
#   - static peers: `peers = { type = "static" }` disables opportunistic
#     dialing, and a non-empty `connect` keeps the public bootstrap seeds out
#     of the address book entirely (heartwood inserts iris/rosa only when
#     connect AND the address book are both empty);
#   - preferredSeeds pinned []: `rad auth` writes the public seeds there by
#     default, and they would otherwise leak into explorer links and seed
#     selection;
#   - per-repo allow lists (`rad init --private`) on top.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.infra.radicle;
  radProfile = import ./rad-profile.nix {
    inherit config pkgs;
    inherit (cfg) publicKey;
  };
in
{
  imports = [ ./ci.nix ./mirror.nix ./explorer.nix ];

  config = mkIf cfg.enable {
    assertions = [
      {
        # Only when sops is the delivery mechanism. A role that sets
        # `privateKeyFile` has the key by other means and must NOT enable
        # my.secrets: doing so is what makes sops-install-secrets run, and it
        # cannot (it mounts a ramfs, which needs CAP_SYS_ADMIN a rootless
        # container does not have).
        assertion = cfg.privateKeyFile != null -> !config.my.secrets.enable;
        message = ''
          my.infra.radicle.privateKeyFile is set AND my.secrets.enable is true.

          privateKeyFile exists for hosts that cannot run sops-install-secrets --
          a rootless container, which has no CAP_SYS_ADMIN to mount the secrets
          filesystem with. Leaving my.secrets enabled alongside it puts that tool
          back in the activation path, where it will fail, so the two are
          mutually exclusive rather than merely redundant.
        '';
      }
      {
        assertion = cfg.privateKeyFile == null -> config.my.secrets.enable;
        message = "my.infra.radicle requires my.secrets.enable = true (the node key comes from sops), or my.infra.radicle.privateKeyFile set to a key delivered another way.";
      }
      {
        assertion = config.my.network.tailscale.enable;
        message = "my.infra.radicle is tailnet-private by design and requires my.network.tailscale.enable = true.";
      }
      {
        assertion = all (p: hasInfix "@" p) cfg.node.connect;
        message = "my.infra.radicle.node.connect entries must be <nid>@<host>:<port>.";
      }
    ];

    # Root-owned, mode 0400: systemd reads LoadCredential sources as root
    # before User= drops privileges, so the radicle user never needs (and
    # never gets) direct read access.
    #
    # DECLARED ONLY when sops is the delivery mechanism. Declaring it is not
    # inert: sops-nix runs sops-install-secrets whenever any secret exists, and
    # that tool mounts a ramfs, which needs CAP_SYS_ADMIN. A rootless container
    # has no such capability, so on a role this declaration alone is the
    # difference between a node that starts and one that dies in activation --
    # which is why `privateKeyFile` suppresses the declaration rather than just
    # overriding what reads it.
    sops.secrets = mkIf (cfg.privateKeyFile == null) {
      ${cfg.privateKeySecret} = { mode = "0400"; };
    };

    services.radicle = {
      enable = true;
      # A path string takes the LoadCredential branch of the nixpkgs module.
      # (The option is `privateKey`; `privateKeyFile` died in 26.05 with no
      # rename alias.) The `or` fallback is the unifi-module idiom: same
      # value either way on a real host, and readable in tests that mkForce
      # the sops set away.
      #
      # Either way this is a PATH, and either way the file is read by systemd as
      # root before User= drops -- the delivery mechanism changes, the property
      # that the radicle user never holds the key does not.
      privateKey =
        if cfg.privateKeyFile != null then
          toString cfg.privateKeyFile
        else
          (config.sops.secrets.${cfg.privateKeySecret} or { path = "/run/secrets/${cfg.privateKeySecret}"; }).path;
      inherit (cfg) publicKey;

      node = {
        inherit (cfg.node) listenAddress listenPort;
        # openFirewall opens the port on EVERY interface; reachability is
        # tailscale0-only via my.network.tailscale.allowedTCPPorts below.
        openFirewall = false;
      };

      settings = {
        preferredSeeds = [ ];
        node = {
          # networking.hostName, not my.system.hostname: the latter is null
          # unless the host layer sets it, and `rad` rejects a null alias.
          alias =
            if cfg.node.alias != null then cfg.node.alias
            else config.networking.hostName;
          peers.type = "static";
          inherit (cfg.node) connect externalAddresses;
          # "allow" without a scope defaults to followed-only; a fleet seed
          # wants every peer's refs (they are all ours).
          seedingPolicy =
            if cfg.node.defaultSeedingPolicy == "allow"
            then { default = "allow"; scope = "all"; }
            else { default = "block"; };
        };
      };

      httpd = mkIf cfg.httpd.enable {
        enable = true;
        # Same wildcard-bind + interface-scoped-firewall strategy as the node,
        # and the same `[::]` for parity: 0.0.0.0 is IPv4-only, which would
        # leave the web view unreachable over the tailnet's IPv6 addresses.
        # `nginx` stays at its null default on purpose: its non-null branch
        # writes a public DNS name into the node's externalAddresses.
        listenAddress = "[::]";
        inherit (cfg.httpd) listenPort aliases;
      };
    };

    # Rendered onto networking.firewall.interfaces.tailscale0.allowedTCPPorts
    # by my/network/tailscale.
    my.network.tailscale.allowedTCPPorts =
      [ cfg.node.listenPort ]
      ++ optional cfg.httpd.enable cfg.httpd.listenPort;

    # The upstream unit orders only against network-online.target. Binding is
    # wildcard so there is no bind race, but dialing the static peers by
    # MagicDNS name wants tailscaled up first.
    systemd.services.radicle-node = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };

    # Declarative seeding -- administration without sudo. It needs the same
    # read-only profile at RAD_HOME that every non-node unit does; see
    # ./rad-profile.nix for what that is and why the key is excluded.
    systemd.services.radicle-seed-repos = mkIf (cfg.seedRepositories != [ ]) {
      description = "Declaratively seed Radicle repositories";
      after = [ "radicle-node.service" ];
      requires = [ "radicle-node.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        RAD_HOME = radProfile.radHome;
        HOME = radProfile.radHome;
      };
      path = [ config.services.radicle.package pkgs.gitMinimal ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "radicle";
        Group = "radicle";
        BindReadOnlyPaths = radProfile.bindReadOnlyPaths;
      };
      script = concatMapStrings
        (repo: ''
          rad seed ${escapeShellArg repo.rid} --scope ${repo.scope} --no-fetch || {
            echo "rad seed ${repo.rid} failed" >&2
            exit 1
          }
        '')
        cfg.seedRepositories;
    };

    my.system.persistence.features.systemDirectories =
      [ "/var/lib/radicle" ]
      ++ optionals cfg.ci.enable [ "/var/lib/radicle-ci" "/var/log/radicle-ci" ]
      ++ optionals cfg.mirror.enable [ "/var/lib/radicle-mirror" ];
  };
}
