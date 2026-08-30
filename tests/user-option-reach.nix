# Which `my.users.<name>` options each platform declares.
#
# mynixos declares an option where its implementation lives, so an option that
# cannot work on a platform does not exist there and setting it is a hard error
# rather than a silent no-op. That property is invisible on any single host --
# nothing on Linux notices a missing darwin option -- so it is asserted here, by
# enumerating both option trees and comparing them.
#
# Pure evaluation: only `options` is read, never `config`, so a Linux runner can
# enumerate the darwin module set (and no derivation is built to find out).
#
# The assertion is on PREFIXES, not leaves. Adding a sub-option to Hyprland is
# ordinary work and must not fail this test; adding a whole app to one platform
# only is a reach decision and must be recorded below.
#
# Failure means one of three things: an option was added to one platform and not
# the other (fix the module, or add it here), an option's declaration drifted out
# of the file that implements it (fix the module), or a genuinely platform-scoped
# app was added (add its prefix here, with the reason).

{ lib
, nixpkgs
, system
, self
, inputs
}:

let
  testLib = import ./lib.nix { inherit lib nixpkgs system self inputs; };
  inherit (testLib) pkgs specialArgs baseConfig baseModules;

  # Every option path under a `my.users.<name>` submodule, dotted and sorted.
  #
  # Two shapes have to be walked, not one. An OPTION whose type is a submodule
  # exposes its children through `type.getSubOptions`. But an option tree also
  # contains bare nested ATTRSETS -- `options.apps.graphical.viewers.feh` merged
  # in from an app module declares `apps`, `apps.graphical` and
  # `apps.graphical.viewers` as plain attrsets, not as submodule options. Walking
  # only `getSubOptions` silently stops at `apps` and reports nothing under it,
  # which would leave this test covering almost nothing while still passing.
  flatten = path: opts:
    lib.concatLists (lib.mapAttrsToList
      (name: v:
        let
          p = path ++ [ name ];
          here = [ (lib.concatStringsSep "." p) ];
          isOption = v ? _type && v._type == "option";
          sub =
            if isOption then (if v ? type && v.type ? getSubOptions then v.type.getSubOptions p else { })
            else if lib.isAttrs v then v
            else { };
        in
        here ++ lib.optionals (sub != { }) (flatten p sub))
      opts);

  userOptionPaths = evaluated:
    lib.sort (a: b: a < b) (flatten [ ] (evaluated.options.my.users.type.getSubOptions [ ]));

  # Everything under `my.` EXCEPT the per-user tree, which has its own table
  # below. Without this the test could not see the domain-level surface at all --
  # it is where the biggest reach mistakes live, because the central option files
  # are the easiest place to declare something for both platforms by accident.
  topOptionPaths = evaluated:
    lib.sort (a: b: a < b)
      (lib.filter (x: x != "users" && !(lib.hasPrefix "users." x))
        (flatten [ ] evaluated.options.my));

  linuxEval = lib.nixosSystem {
    inherit specialArgs;
    modules = baseModules ++ [ baseConfig { networking.hostName = "reach-linux"; } ];
  };

  darwinEval = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs self; };
    modules = [
      self.darwinModules.default
      inputs.home-manager.darwinModules.home-manager
      inputs.sops-nix.darwinModules.sops
      {
        nixpkgs.hostPlatform = "aarch64-darwin";
        system.stateVersion = 7;
        system.primaryUser = "reach";
        networking.hostName = "reach-darwin";
      }
    ];
  };

  linuxPaths = userOptionPaths linuxEval;
  darwinPaths = userOptionPaths darwinEval;
  topLinuxPaths = topOptionPaths linuxEval;
  topDarwinPaths = topOptionPaths darwinEval;

  # Option groups that deliberately exist on one platform only. Each entry is a
  # prefix: it and everything under it may be one-sided.
  linuxOnly = {
    "apps.graphical.windowManagers.hyprland" = "Wayland compositor; macOS owns its own window server.";
    "graphical.shell" = "The desktop-shell selection (vogix/none); the vogix shell is a Wayland layer-shell surface set.";
    "graphical.fontSize" = "The vogix HUD's type-scale root; the shell is Linux-only, and macOS type scaling is the OS's.";
    "graphical.idle" = "Idle staging for the shell's ext-idle-notify monitors; macOS owns its own idle/sleep policy.";
    "apps.graphical.viewers.feh" = "X11 image viewer.";
    "apps.terminal.visualizers.bespec" = "x86_64-linux only: alsa/dbus/pipewire at build, Wayland/Vulkan at run time.";
    "apps.media.tools.pipewireTools" = "PipeWire CLI; macOS uses CoreAudio.";
    "apps.media.tools.audioUtils" = "pavucontrol/pamixer are PulseAudio clients; CoreAudio is not a drop-in.";

    # Creative apps whose packages have no aarch64-darwin build. Their portable
    # siblings -- inkscape, blender, darktable, audacity, musikcube -- are
    # deliberately NOT here: they exist on both platforms.
    "apps.art.drawing.krita" = "krita: no aarch64-darwin build in nixpkgs.";
    "apps.art.drawing.mypaint" = "mypaint: no aarch64-darwin build in nixpkgs.";
    "apps.art.editing.gimp" = "gimp: no aarch64-darwin build in nixpkgs.";
    "apps.media.editors.kdenlive" = "kdenlive: no aarch64-darwin build in nixpkgs.";
    "apps.media.players.audacious" = "audacious: no aarch64-darwin build in nixpkgs.";
    "apps.media.players.qobine" = "packages/qobine builds against alsa-lib; upstream's own macOS build is not packaged here.";
    "input.accelSpeed" = "libinput's acceleration scale and com.apple.mouse.scaling have no common ground.";
    "input.keyboardLayouts" = "XKB layout list rendered into Hyprland's kb_layout; macOS input sources are not XKB.";

    # The per-user flags that DRIVE the one-sided apps above. graphical.enable
    # is deliberately NOT here -- it means the same thing on both platforms and
    # darwin forces it true; only what follows from it is Linux-only.
    "graphical.media" = "creative and audio apps, driven by my/users/graphical/media/mynixos-linux.nix.";
    "graphical.webapps" = "browser .desktop generation, which macOS has no counterpart for.";
    "graphical.streaming" = "OBS plus the v4l2loopback virtual camera.";
    "theming" = "vogix, which is NixOS + Hyprland.";
  };

  darwinOnly = {
    "apps.graphical.utils.keepingyouawake" = "Drives macOS IOKit power assertions.";
  };

  # ---------------------------------------------------------------------------
  # Domain-level reach: `my.*` outside the per-user tree.
  # ---------------------------------------------------------------------------
  topLinuxOnly = {
    "ai" = "Ollama with ROCm; no macOS equivalent wired up.";
    "boot" = "systemd-boot / lanzaboote; macOS owns its own boot chain.";
    "environment" = "XDG dirs, motd and the graphical login (my.environment.login) -- a Linux desktop's furniture.";
    "filesystem" = "disko; macOS owns the disk and APFS is not disko-managed.";
    "forensics" = "Linux-specific acquisition and analysis tooling.";
    "graphical" = "the Hyprland/greetd stack.";
    "hardware.bluetooth" = "bluez.";
    "hardware.cooling" = "liquidctl/OpenRGB over Linux HID.";
    "hardware.laptops.lenovo" = "x86 laptop profiles.";
    "hardware.memory" = "Linux VM tunables.";
    "hardware.motherboards" = "x86 desktop boards.";
    "hardware.peripherals" = "udev-driven device wiring.";
    "hardware.securityKeys" = "pcscd + udev; see docs/yubikey-on-darwin.md for the deliberate omission.";
    "hardware.storage" = "Linux block-device tuning.";
    "hardware.usb" = "Linux USB/Thunderbolt stack.";
    "infra" = "k3s and the self-hosted GitHub runner.";
    "network.headscale" = "self-hosted control server, run on the Linux boxes.";
    "network.ipv6" = "sysctl-driven privacy extensions.";
    "network.monitoring" = "Linux service monitoring.";
    "network.openssh" = "the NixOS sshd module; darwin uses launchd + my.network.sshFirewall.";
    "network.tailscale" = "the NixOS tailscaled module; the Mac runs the App Store build.";
    "network.tor" = "Linux tor service.";
    "network.unifi" = "Linux controller service.";
    "performance" = "zram and vmtouch.";
    "presets" = "bundles composed of Linux-only domains.";
    "security" = "secure boot, audit rules, PAM.";
    "storage" = "impermanence and disko.";
    "streaming" = "OBS plus the v4l2loopback virtual camera.";
    "system.architecture" = "read by my/system/kernel to set hostPlatform; the Apple profile does that itself.";
    "system.dualBoot" = "NTFS + local-time clock for a Windows dual-boot.";
    "system.kernel" = "there is no kernel to choose on macOS.";
    "system.persistence" = "impermanence's collection point; nothing wipes the disk on macOS.";
    "system.systemd" = "systemd.";
    "system.udev" = "udev.";
    "theming" = "vogix, which is NixOS + Hyprland.";
    "video" = "v4l2loopback.";
  };

  topDarwinOnly = {
    "hardware.biometrics" = "Touch ID / Apple Watch unlock.";
    "hardware.laptops.apple" = "Apple Silicon laptop profiles.";
    "homebrew" = "Mac App Store apps and the one cask Nix cannot package.";
    "network.sshFirewall" = "pf, because sshd_config's ListenAddress does nothing when launchd owns the socket.";
    "nixGc" = "launchd GC daemons; nix-darwin's own GC asserts nix.enable, which is false here.";
  };

  # `under`: the path IS the listed option or sits inside it.
  under = p: path: path == p || lib.hasPrefix (p + ".") path;

  # `related` additionally accepts an ANCESTOR of a listed option. Container
  # levels are not declared in their own right -- `apps.graphical.viewers` exists
  # only because feh is declared beneath it -- so a container whose every child
  # is one-sided is itself one-sided, and that is structure rather than a defect.
  # (A container with any cross-platform child exists on both sides and never
  # reaches this check.)
  related = p: path: under p path || lib.hasPrefix (path + ".") p;

  covered = prefixes: path: lib.any (p: related p path) (lib.attrNames prefixes);

  # Divergences that are NOT accounted for above -- the actual failure.
  unexpectedLinux = lib.filter (p: !(covered linuxOnly p)) (lib.subtractLists darwinPaths linuxPaths);
  unexpectedDarwin = lib.filter (p: !(covered darwinOnly p)) (lib.subtractLists linuxPaths darwinPaths);

  # A listed prefix must actually BE one-sided: present on its own platform and
  # absent from the other. It fails that either by disappearing (module deleted)
  # or by appearing on both (module ported, reach no longer scoped) -- both mean
  # this file is out of date, and neither is caught by the checks above.
  # Staleness uses `under`, NOT `related`: a listed option is one-sided only if it
  # actually exists on its own platform and is absent from the other. Matching
  # ancestors here would let a shared container like `apps.graphical` vouch for a
  # prefix that no longer exists.
  oneSided = mine: theirs: p:
    lib.any (under p) mine && !(lib.any (under p) theirs);

  staleLinux = lib.filter (p: !(oneSided linuxPaths darwinPaths p)) (lib.attrNames linuxOnly);
  staleDarwin = lib.filter (p: !(oneSided darwinPaths linuxPaths p)) (lib.attrNames darwinOnly);

  topUnexpectedLinux = lib.filter (p: !(covered topLinuxOnly p)) (lib.subtractLists topDarwinPaths topLinuxPaths);
  topUnexpectedDarwin = lib.filter (p: !(covered topDarwinOnly p)) (lib.subtractLists topLinuxPaths topDarwinPaths);
  topStaleLinux = lib.filter (p: !(oneSided topLinuxPaths topDarwinPaths p)) (lib.attrNames topLinuxOnly);
  topStaleDarwin = lib.filter (p: !(oneSided topDarwinPaths topLinuxPaths p)) (lib.attrNames topDarwinOnly);

  fmt = xs: lib.concatMapStrings (x: "\n    " + x) xs;
  problems =
    lib.optional (unexpectedLinux != [ ])
      "Declared on Linux but not darwin, and not listed as linux-only:${fmt unexpectedLinux}"
    ++ lib.optional (unexpectedDarwin != [ ])
      "Declared on darwin but not Linux, and not listed as darwin-only:${fmt unexpectedDarwin}"
    ++ lib.optional (staleLinux != [ ])
      "Listed as linux-only but not actually one-sided -- either gone, or now declared on darwin too:${fmt staleLinux}"
    ++ lib.optional (staleDarwin != [ ])
      "Listed as darwin-only but not actually one-sided -- either gone, or now declared on Linux too:${fmt staleDarwin}"
    ++ lib.optional (topUnexpectedLinux != [ ])
      "my.* declared on Linux but not darwin, and not listed as linux-only:${fmt topUnexpectedLinux}"
    ++ lib.optional (topUnexpectedDarwin != [ ])
      "my.* declared on darwin but not Linux, and not listed as darwin-only:${fmt topUnexpectedDarwin}"
    ++ lib.optional (topStaleLinux != [ ])
      "my.* listed as linux-only but not actually one-sided:${fmt topStaleLinux}"
    ++ lib.optional (topStaleDarwin != [ ])
      "my.* listed as darwin-only but not actually one-sided:${fmt topStaleDarwin}";
in
{
  user-option-reach =
    if problems != [ ] then
      throw
        ("my.users option reach differs from what is recorded in tests/user-option-reach.nix:\n\n"
          + lib.concatStringsSep "\n\n" problems + "\n")
    else
      pkgs.runCommand "user-option-reach" { } ''
        echo "linux:  ${toString (lib.length linuxPaths)} my.users option paths"
        echo "darwin: ${toString (lib.length darwinPaths)} my.users option paths"
        echo "one-sided by design: ${toString (lib.length (lib.attrNames linuxOnly))} linux, ${toString (lib.length (lib.attrNames darwinOnly))} darwin"
        echo "my.* domains: ${toString (lib.length topLinuxPaths)} linux / ${toString (lib.length topDarwinPaths)} darwin paths"
        touch $out
      '';
}
