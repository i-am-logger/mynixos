# The darwin-only module set, evaluated.
#
# Nothing else in this suite ever evaluates a nix-darwin configuration, so every
# module under platforms/darwin.nix -- homebrew, nix-gc, the Apple hardware
# profile, Touch ID, the pf ssh firewall, Colima, the darwin user module,
# keepingyouawake and the 1Password darwin half -- has been unexercised. A
# mistake in any of them shows up only when someone runs darwin-rebuild.
#
# This runs on a LINUX runner: darwinSystem's `config` evaluates without a darwin
# builder, because nothing here forces a derivation. Only `config` is read.
# `system.build.toplevel` is deliberately never touched -- that WOULD need
# aarch64-darwin.

{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs;

  # The Apple hardware profile is what sets nixpkgs.hostPlatform, exactly as a
  # motherboard profile does on NixOS -- so this asserts that wiring too.
  darwinConfigWith = extraModules: myConfig: (self.lib.mkSystem {
    platform = "darwin";
    hostname = "darwin-smoke";
    users = [{ name = "smoke"; homeManager = { home.stateVersion = "24.11"; }; }];
    my = lib.recursiveUpdate
      {
        hardware.laptops.apple.macbook-pro-m5-max.enable = true;
        system.enable = true;
        users.smoke = {
          fullName = "Smoke Test";
          description = "smoke";
          email = "smoke@example.com";
          terminal.enable = true;
        };
      }
      myConfig;
    extraModules = [{
      system.stateVersion = 7;
      system.primaryUser = "smoke";
    }] ++ extraModules;
  }).config;

  darwinConfig = darwinConfigWith [ ];

  # herdr at a named version, so the plugin cases do not depend on the one
  # mynixos's nixpkgs pin ships.
  herdrAt = version: {
    nixpkgs.overlays = [
      (_: prev: { herdr = prev.herdr.overrideAttrs (_: { inherit version; __intentionallyOverridingVersion = true; }); })
    ];
  };

  check = name: cond: detail:
    pkgs.runCommand "darwin-smoke-${name}" { }
      (if cond then ''
        echo "PASS: ${name}"
        touch $out
      '' else builtins.throw "FAIL: ${name} -- ${detail}");

  base = darwinConfig { };
in
{
  # The hardware profile, not mkSystem, decides the architecture.
  darwin-smoke-hostplatform = check "hostplatform"
    (base.nixpkgs.hostPlatform.system == "aarch64-darwin")
    "the Apple profile should set nixpkgs.hostPlatform to aarch64-darwin";

  # Touch ID: the profile turns on biometrics, which writes the sudo PAM rule.
  darwin-smoke-touchid = check "touchid"
    (base.security.pam.services.sudo_local.touchIdAuth or false)
    "enabling the MacBook profile should enable Touch ID for sudo";

  # macOS accounts are data-driven from my.users, like NixOS.
  darwin-smoke-user-home = check "user-home"
    (base.users.users.smoke.home == "/Users/smoke")
    "the darwin user module should place the home under /Users";

  # zsh is the macOS login shell, injected by my/users/users/mynixos-darwin.nix.
  darwin-smoke-shell-default = check "shell-default"
    (base.my.users.smoke.shell == "zsh")
    "darwin should default the login shell to zsh";

  # macOS cannot not be graphical; the flag is forced, not defaulted.
  darwin-smoke-graphical-forced = check "graphical-forced"
    base.my.users.smoke.graphical.enable
    "my/users/graphical/mynixos-darwin.nix should force graphical.enable";

  # Homebrew: nix-darwin writes the Brewfile, nix-homebrew installs brew itself.
  darwin-smoke-homebrew =
    let
      c = darwinConfig {
        homebrew = { enable = true; user = "smoke"; casks = [ "background-music" ]; };
      };
    in
    check "homebrew"
      (c.homebrew.enable && c.nix-homebrew.enable
        && builtins.any (k: k.name == "background-music") c.homebrew.casks)
      "my.homebrew should drive both nix-darwin's homebrew and nix-homebrew";

  # nix-darwin's own GC asserts nix.enable, which is false on this fleet, so
  # my/system/nix-gc uses plain launchd daemons instead.
  darwin-smoke-nix-gc =
    let c = darwinConfig { nixGc.enable = true; };
    in
    check "nix-gc"
      (c.launchd.daemons ? mynixos-nix-gc && c.launchd.daemons ? mynixos-nix-optimise)
      "my.nixGc should install the gc and optimise launchd daemons";

  # With nix.enable = false (this fleet: the nix-installer owns Nix),
  # nix-darwin writes no registry and no NIX_PATH, so my/system/nix-registry
  # does: `nixpkgs` is the nixpkgs the system was built from.
  darwin-smoke-nix-registry =
    let
      c = darwinConfigWith [{ nix.enable = false; }] { };
      registry = builtins.fromJSON (builtins.unsafeDiscardStringContext c.environment.etc."nix/registry.json".text);
      entry = builtins.head registry.flakes;
    in
    check "nix-registry"
      (entry.from.id == "nixpkgs"
        && entry.to.path == toString inputs.nixpkgs.outPath
        && c.environment.variables.NIX_PATH == "nixpkgs=flake:nixpkgs")
      "with nix.enable = false, /etc/nix/registry.json and NIX_PATH should pin nixpkgs to the system's own";

  # pf, because sshd_config's ListenAddress does nothing when launchd owns the
  # socket.
  darwin-smoke-ssh-firewall =
    let c = darwinConfig { network.sshFirewall = { enable = true; tailnetPorts = null; }; };
    in
    check "ssh-firewall"
      (c.environment.etc ? "pf.anchors/org.mynixos.firewall" && c.environment.etc ? "pf.conf")
      "my.network.sshFirewall should write a pf anchor and reference it from pf.conf";

  # Colima: macOS has no kernel to run containers on, so the runtime is in a VM.
  darwin-smoke-containers =
    let c = darwinConfig { users.smoke.dev = { enable = true; containers.enable = true; }; };
    in
    check "containers"
      (builtins.any (p: (p.pname or "") == "colima")
        c.home-manager.users.smoke.home.packages)
      "my.users.<n>.dev.containers on darwin should install colima";

  # The engine defaults follow the users: on darwin, a user who wants containers
  # gets docker (Colima) and never podman, which darwin cannot serve.
  darwin-smoke-containers-backend =
    let c = darwinConfig { users.smoke.dev.enable = true; };
    in
    check "containers-backend"
      (c.my.virtualisation.containers.docker.enable && !c.my.virtualisation.containers.podman.enable)
      "darwin should run docker (Colima) and not podman by default";

  # The darwin-only Colima setting lives under the feature's .darwin key.
  darwin-smoke-containers-colima-autostart =
    let c = darwinConfig { users.smoke.dev.enable = true; virtualisation.containers.darwin.colimaAutoStart = true; };
    in
    check "containers-colima-autostart"
      (c.home-manager.users.smoke.launchd.agents.colima.enable or false)
      "containers.darwin.colimaAutoStart should install the colima launchd agent";

  # And the mismatch is a hard error, not a silent no-op: podman on darwin would
  # otherwise evaluate to a host with dev enabled and no container runtime.
  darwin-smoke-containers-rejects-podman =
    let
      c = darwinConfig {
        virtualisation.containers.podman.enable = true;
        users.smoke.dev.enable = true;
      };
      failing = builtins.filter (a: !a.assertion) c.assertions;
    in
    check "containers-rejects-podman"
      (builtins.any (a: lib.hasInfix "not implemented on darwin" a.message) failing)
      "my.virtualisation.containers.podman.enable on darwin should fail an assertion";

  # keepingyouawake is darwin-only and drives IOKit power assertions.
  darwin-smoke-keepingyouawake =
    let c = darwinConfig { users.smoke.apps.graphical.utils.keepingyouawake.enable = true; };
    in
    check "keepingyouawake"
      (c.home-manager.users.smoke.launchd.agents ? keepingyouawake)
      "keepingyouawake should register a launchd user agent";

  # Discord is the one app whose darwin half deliberately is NOT a derivation:
  # nixpkgs stages native modules inside the signed bundle, which breaks the code
  # signature and makes macOS refuse to launch it. Assert both halves of that
  # decision -- the cask IS declared, and no nix discord sneaks in -- because a
  # well-meaning "just put pkgs.discord back" is exactly the regression here.
  darwin-smoke-discord =
    let c = darwinConfig { users.smoke.apps.communication.messaging.discord.enable = true; };
    in
    check "discord"
      (builtins.elem "discord" c.my.homebrew.casks
        && !(builtins.any (p: (p.pname or "") == "discord") c.environment.systemPackages)
        && !(builtins.any (p: (p.pname or "") == "discord")
        c.home-manager.users.smoke.home.packages))
      "discord on darwin should be a homebrew cask and never a nix package";

  # 1Password's darwin half installs the .app and the CLI.
  darwin-smoke-1password =
    let c = darwinConfig { users.smoke.apps.security.passwords.onePassword.enable = true; };
    in
    check "1password"
      (c.programs._1password.enable
        && builtins.any (p: (p.pname or "") == "1password") c.environment.systemPackages)
      "the darwin 1Password module should install the app and enable the CLI";

  # herdr-focus-notify is darwin-only (its option is declared by
  # platforms/darwin.nix alone): on, it is installed and linked; off, the
  # activation only ever unlinks a store-rooted entry.
  darwin-smoke-herdr-focus-notify =
    let
      c = darwinConfigWith [ (herdrAt "0.9.5") ] { users.smoke.terminal.herdr.plugins.focusNotify.enable = true; };
      hm = c.home-manager.users.smoke;
    in
    check "herdr-focus-notify"
      (builtins.any (p: (p.pname or "") == "herdr-focus-notify") hm.home.packages
        && lib.hasInfix "plugin link" hm.home.activation.herdrPluginsDarwin.data
        && lib.hasInfix "share/herdr-plugins/herdr-focus-notify" hm.home.activation.herdrPluginsDarwin.data
        # Only failing assertions' messages are read: some of nix-darwin's
        # own are only evaluable when they fail.
        && !(builtins.any (a: !a.assertion && lib.hasInfix "focusNotify" a.message) c.assertions))
      "focusNotify on should install and link herdr-focus-notify";

  darwin-smoke-herdr-focus-notify-off =
    let hm = (darwinConfigWith [ (herdrAt "0.9.5") ] { }).home-manager.users.smoke;
    in
    check "herdr-focus-notify-off"
      (!(builtins.any (p: (p.pname or "") == "herdr-focus-notify") hm.home.packages)
        && !(lib.hasInfix "plugin link" hm.home.activation.herdrPluginsDarwin.data)
        && lib.hasInfix "plugin unlink" hm.home.activation.herdrPluginsDarwin.data)
      "focusNotify off should neither install nor link herdr-focus-notify";

  darwin-smoke-herdr-focus-notify-old-herdr =
    let c = darwinConfigWith [ (herdrAt "0.9.0") ] { users.smoke.terminal.herdr.plugins.focusNotify.enable = true; };
    in
    check "herdr-focus-notify-old-herdr"
      (builtins.any (a: !a.assertion && lib.hasInfix "focusNotify needs herdr" a.message) c.assertions)
      "focusNotify should refuse a herdr older than 0.9.1";

  # The portable base CLI set must actually reach a Mac -- that split is what
  # my/system/base-packages exists for.
  darwin-smoke-base-packages = check "base-packages"
    (
      let names = map (p: p.pname or p.name or "") base.environment.systemPackages;
      in builtins.all (n: builtins.elem n names) [ "tree" "wget" "sops" ]
    )
    "the portable base package set should be installed on darwin";

  # A darwin host keeps its privacy grants across a switch. home-manager's
  # copyApps check runs `tccutil reset SystemPolicyAppBundles` when its probe is
  # denied, which clears App Management for EVERY app, so mynixos turns that check
  # off and runs its own probe, which stops the switch instead of resetting.
  darwin-smoke-tcc-kept =
    let
      c = darwinConfigWith [{ home-manager.users.smoke.targets.darwin.copyApps.enable = true; }] { };
      hm = c.home-manager.users.smoke;
      activationText = lib.concatMapStrings (e: e.data or "") (lib.attrValues hm.home.activation);
    in
    check "tcc-kept"
      (!hm.targets.darwin.copyApps.enableChecks
        && hm.home.activation ? checkAppManagement
        && !(lib.hasInfix "tccutil" activationText))
      "copyApps' tccutil-resetting check should be off, with mynixos's App Management probe in its place";

  # baud.app keeps its grants when signed with a certificate the machine holds:
  # the designated requirement is then the identifier and that certificate, not a
  # per-build cdhash. baud is the darwin default terminal, so naming an identity
  # is all a host does.
  darwin-smoke-baud-signing =
    let
      c = darwinConfig { users.smoke.terminal.baud.signingIdentity = "smoke signing"; };
      act = c.home-manager.users.smoke.home.activation;
    in
    check "baud-signing"
      (act ? signBaud
        && lib.hasInfix "codesign --force --sign \"$baudIdentity\" -i dev.baud.terminal" act.signBaud.data
        && lib.hasInfix "'smoke signing'" act.signBaud.data
        && builtins.elem "copyApps" act.signBaud.after)
      "terminal.baud.signingIdentity should sign baud.app after copyApps";

  # No identity, no signing step: the certificate belongs to one machine.
  darwin-smoke-baud-signing-off = check "baud-signing-off"
    (!(base.home-manager.users.smoke.home.activation ? signBaud))
    "with no signingIdentity, baud.app should stay ad hoc";

  # One completion dump per zsh version, and no global compinit fighting over it.
  # Apple's /bin/zsh (what launchd hands GUI launches) and nix's zsh both start
  # interactively on darwin; sharing one dump, each rebuilds it after the other,
  # 0.4-2.4 s per prompt.
  darwin-smoke-zsh-compdump =
    let
      c = darwinConfig { users.smoke.apps.terminal.shells.zsh.enable = true; };
    in
    check "zsh-compdump"
      (!c.programs.zsh.enableGlobalCompInit
        && lib.hasInfix "zcompdump-$ZSH_VERSION" c.home-manager.users.smoke.programs.zsh.completionInit)
      "a home-manager zsh should own compinit, with a per-version dump, and /etc/zshrc's should be off";
}
