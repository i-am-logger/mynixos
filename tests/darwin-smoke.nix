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
  darwinConfig = myConfig: (self.lib.mkSystem {
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
    }];
  }).config;

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

  # pf, because sshd_config's ListenAddress does nothing when launchd owns the
  # socket.
  darwin-smoke-ssh-firewall =
    let c = darwinConfig { network.sshFirewall = { enable = true; tailnetPorts = null; }; };
    in
    check "ssh-firewall"
      (c.environment.etc ? "pf.anchors/org.mynixos.firewall" && c.environment.etc ? "pf.conf")
      "my.network.sshFirewall should write a pf anchor and reference it from pf.conf";

  # Colima: macOS has no kernel to run containers on, so the daemon is in a VM.
  darwin-smoke-docker =
    let c = darwinConfig { users.smoke.dev = { enable = true; docker.enable = true; }; };
    in
    check "docker"
      (builtins.any (p: (p.pname or "") == "colima")
        c.home-manager.users.smoke.home.packages)
      "my.users.<n>.dev.docker on darwin should install colima";

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

  # The portable base CLI set must actually reach a Mac -- that split is what
  # my/system/base-packages exists for.
  darwin-smoke-base-packages = check "base-packages"
    (
      let names = map (p: p.pname or p.name or "") base.environment.systemPackages;
      in builtins.all (n: builtins.elem n names) [ "tree" "wget" "sops" ]
    )
    "the portable base package set should be installed on darwin";
}
