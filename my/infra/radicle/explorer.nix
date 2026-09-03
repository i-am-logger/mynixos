# radicle-explorer: the browsable forge UI, served from this host.
#
# radicle-httpd (the sibling in ./default.nix) is a JSON API -- every path
# answers application/json, so a browser pointed at it shows data, not a page.
# radicle-explorer is the static SPA that turns that API into a readable
# forge: repositories, patches, issues, history.
#
# It is served from OUR nginx rather than by sending anyone to a hosted
# explorer. On a tailnet-private network that is the whole point: the SPA is
# client-side, so a hosted copy would put a third party's JavaScript in front
# of every RID and path it fetches. A local copy keeps that inside the tailnet.
#
# SINGLE ORIGIN. nginx serves the SPA and proxies /api to radicle-httpd, so
# the page and its API share one origin. That is not tidiness -- it is what
# makes HTTPS possible at all: a page served over https cannot call an http
# API (mixed content is blocked), and a cross-origin API would need CORS on
# top. One origin removes both problems.
#
# NOTE the explorer only ever shows PUBLIC repos, because radicle-httpd is a
# public gateway and 404s private ones. Private repos are browsed with rad,
# rad-tui or radicle-desktop, which read the local node directly. That is by
# design, not a misconfiguration.
#
# nginx is configured by hand rather than through services.radicle.httpd.nginx:
# that option's non-null branch rewrites the node's externalAddresses to a
# public DNS name and switches on ACME, which is exactly wrong here.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.my.infra.radicle;
  ecfg = cfg.httpd.explorer;

  seedHost =
    if ecfg.seedHostname != null then ecfg.seedHostname
    else config.networking.hostName;

  https = ecfg.scheme == "https";
  # What the browser will actually connect to. Over https that is the
  # `tailscale serve` front door; over http it is nginx directly.
  browserPort = if https then ecfg.externalPort else ecfg.listenPort;

  acfg = ecfg.avatars;

  # Gravatar keys on md5 of the lowercased address, so publishing each image
  # under that exact name means the rewritten URL resolves with no further
  # code change. Files are extensionless, matching the URL shape.
  avatarRoot = pkgs.runCommand "radicle-explorer-avatars" { } (''
    mkdir -p $out/avatars
  '' + optionalString (acfg.default != null) ''
    cp ${acfg.default} $out/avatars/default
  '' + concatStrings (mapAttrsToList
    (email: image: ''
      cp ${image} $out/avatars/${builtins.hashString "md5" (toLower email)}
    '')
    acfg.byEmail));

  explorerBase = pkgs.radicle-explorer.withConfig {
    # The seed the UI offers by default: ours, reached the same way the page
    # itself was -- same scheme, same host, same port -- so the API call lands
    # on the /api proxy below rather than on a second origin.
    preferredSeeds = [{
      hostname = seedHost;
      port = browserPort;
      inherit (ecfg) scheme;
    }];
  };

  # Rewrite the hard-coded gravatar host to a same-origin path. Done to the
  # BUILT bundle because the URL is baked into the JavaScript -- there is no
  # runtime setting for it, and leaving it would have the browser call
  # gravatar.com with an md5 of every committer's address.
  explorer =
    if acfg.enable then
      explorerBase.overrideAttrs
        (prev: {
          postInstall = (prev.postInstall or "") + ''
            find $out -name '*.js' -exec \
              sed -i 's|https://www\.gravatar\.com/avatar/|/avatars/|g' {} +
            if grep -rq "gravatar\.com" $out; then
              echo "gravatar.com still referenced after rewrite" >&2
              exit 1
            fi
          '';
        })
    else explorerBase;
in
{
  config = mkIf (cfg.enable && cfg.httpd.enable && ecfg.enable) {
    assertions = [
      {
        assertion = ecfg.listenPort != cfg.httpd.listenPort;
        message = "my.infra.radicle.httpd.explorer.listenPort must differ from httpd.listenPort (${toString cfg.httpd.listenPort}).";
      }
      {
        # tailscale serve is what terminates TLS; without the tailnet there is
        # no certificate and no front door.
        assertion = https -> config.my.network.tailscale.enable;
        message = "my.infra.radicle.httpd.explorer.scheme = \"https\" needs my.network.tailscale.enable: the certificate is the tailnet's.";
      }
    ];

    services.nginx = {
      enable = true;
      # No ACME and no TLS here on purpose: over https, tailscale serve holds
      # the certificate and this vhost only ever sees loopback traffic.
      virtualHosts."radicle-explorer" = {
        # Over https nginx listens on LOOPBACK ONLY: `tailscale serve` is the
        # single front door, so there is no second, unencrypted way in. Over
        # plain http it must be reachable on the tailnet itself, since nothing
        # is proxying it.
        listen =
          if https then [
            { addr = "127.0.0.1"; port = ecfg.listenPort; }
            { addr = "[::1]"; port = ecfg.listenPort; }
          ] else [
            { addr = "0.0.0.0"; port = ecfg.listenPort; }
            { addr = "[::]"; port = ecfg.listenPort; }
          ];
        root = "${explorer}";
        locations = {
          # A single-page app: every route falls back to index.html, or a deep
          # link to a repo or patch 404s on reload.
          "/".tryFiles = "$uri $uri/ /index.html";
          # The SPA shell must NOT be cached. Without this nginx sends it with
          # an etag but no Cache-Control, so browsers cache it heuristically --
          # and because the fallback answers EVERY unknown path with 200, a
          # path that later becomes real (like /ci/) keeps rendering the stale
          # app, which then reports "repository not found". Hashed assets under
          # /assets/ are still cached normally; only the shell is exempt.
          "= /index.html".extraConfig = ''
            add_header Cache-Control "no-store" always;
          '';
          # Raw blobs, which is how the explorer renders any image a README
          # references. `radicle-httpd` mounts this OUTSIDE the API -- see
          # `.nest("/raw", raw_router)` in crates/radicle-httpd/src/lib.rs --
          # serving /raw/:rid/:sha/*path, /raw/:rid/head/*path and
          # /raw/:rid/blobs/:oid. It does not appear in the /api/v1 link index,
          # which is why enumerating that index says no such endpoint exists.
          #
          # Without this location the request falls through to the SPA fallback
          # above and gets index.html with a 200, so a committed badge renders
          # as a broken image and following the link by hand shows the
          # explorer's own "Page not found". Nothing anywhere reports an error:
          # the status is 200, the file is present and valid in the tree, and
          # the explorer built the URL correctly. The only clue is that the
          # response is text/html where an image was asked for.
          "/raw/".proxyPass = "http://127.0.0.1:${toString cfg.httpd.listenPort}/raw/";
          # Same-origin API. The trailing slashes matter: /api/v1/x must reach
          # httpd as /api/v1/x, not /api/api/v1/x.
          "/api/".proxyPass = "http://127.0.0.1:${toString cfg.httpd.listenPort}/api/";
          # CI reports come from wherever CI actually RAN. `proxyTo` covers the
          # case that broke silently: CI moved to a builder container, this
          # host's own ci.enable went false, and the /ci/ location disappeared
          # with it -- so the page went blank rather than wrong, which is harder
          # to notice. With proxyTo set the local report_dir is irrelevant and
          # the condition no longer depends on ci.enable at all.
        } // optionalAttrs (ecfg.ciReports.enable && (cfg.ci.enable || ecfg.ciReports.proxyTo != null)) {
          # Without this, /ci (no trailing slash) does not match the /ci/
          # location, falls through to the SPA, and the explorer reports
          # "repository not found" -- which looks like a broken CI page
          # rather than a missing slash.
          ${removeSuffix "/" ecfg.ciReports.path} = {
            return = "301 ${ecfg.ciReports.path}";
          };
          ${ecfg.ciReports.path} =
            if ecfg.ciReports.proxyTo != null then {
              # The builder serves its own reports; this is a window onto them.
              # Reading its filesystem from here instead would mean matching
              # subuid mappings across a userns boundary by hand.
              proxyPass = ecfg.ciReports.proxyTo;
            } else {
              # The broker writes HTML reports here; autoindex so a run is
              # reachable without knowing its filename. Read-only, and on the
              # same tailnet-only origin as everything else.
              alias = "${config.services.radicle.ci.broker.settings.report_dir}/";
              extraConfig = ''
                autoindex on;
              '';
            };
        } // optionalAttrs acfg.enable {
          # Served from here rather than gravatar.com. Unknown addresses fall
          # back to the default image, so a missing avatar is a local 200
          # rather than an outbound request.
          "/avatars/" = {
            root = "${avatarRoot}";
            extraConfig = ''
              default_type image/png;
            '' + optionalString (acfg.default != null) ''
              try_files $uri /avatars/default =204;
            '' + optionalString (acfg.default == null) ''
              try_files $uri =204;
            '';
          };
        };
      };
    };

    # The report dir belongs to the radicle user; nginx needs group read to
    # serve it. Read-only: nginx never writes there.
    # Only when nginx READS the reports off this machine. Proxying needs no
    # group membership -- and granting it anyway would hand nginx access to the
    # radicle user.s files on a host that has no reason to touch them.
    users.users.nginx.extraGroups =
      optional (ecfg.ciReports.enable && cfg.ci.enable && ecfg.ciReports.proxyTo == null) "radicle";

    # Only opened on the tailnet when nginx is the front door. Under https
    # the port is loopback-only and opening it would be a lie -- the entrance
    # is tailscale serve, which needs no firewall rule of its own.
    my.network.tailscale.allowedTCPPorts = optional (!https) ecfg.listenPort;

    # HTTPS without running a CA or an ACME client: tailscaled already holds a
    # real certificate for this node's tailnet name, and `serve` terminates TLS
    # with it and proxies to nginx on loopback. Idempotent, so re-running on
    # every activation just reasserts the same config.
    systemd.services.radicle-explorer-serve = mkIf https {
      description = "Publish the radicle explorer over HTTPS via tailscale serve";
      after = [ "tailscaled.service" "nginx.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ config.services.tailscale.package ];
      script = ''
        # Wait for the backend: `serve` needs a logged-in tailscaled to have a
        # certificate to offer.
        for _ in $(seq 1 30); do
          if [ "$(tailscale status --json | ${getExe pkgs.jq} -r .BackendState)" = "Running" ]; then
            exec tailscale serve --bg --https=${toString ecfg.externalPort} \
              http://127.0.0.1:${toString ecfg.listenPort}
          fi
          sleep 2
        done
        echo "tailscaled not Running after 60s; explorer stays on http://…:${toString ecfg.listenPort}" >&2
        exit 0
      '';
    };
  };
}
