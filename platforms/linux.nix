# mynixos composition layer: NixOS.
#
# Everything here touches options that only NixOS declares -- `boot.*`,
# `systemd.*`, `services.*`, `hardware.*`, `users.users.<n>.isNormalUser`,
# `environment.persistence`, `security.pam` (the Linux flavour) -- or ships
# packages that only build on Linux.
#
# See ./common.nix for the classification rule and the file-placement principle.

{ lib, ... }:

let
  mkOptionsModule = path: args: _: { options.my = import path args; };
in
{
  imports = [
    ../my/graphical/hyprland/options-user.nix
    ./common.nix
  ]

  # -----------------------------------------------------------------------
  # Options whose implementation is Linux-only. Declared HERE, not in
  # ./common.nix, so that a darwin host setting them fails with
  # "The option `my.security.secureBoot' does not exist" rather than
  # silently doing nothing -- the mirror of what ./darwin.nix does for
  # my.homebrew / my.nixGc / my.network.sshFirewall.
  # -----------------------------------------------------------------------
  ++ [
    (mkOptionsModule ../my/security/options.nix { inherit lib; })
    (mkOptionsModule ../my/users/graphical/options-linux.nix { inherit lib; })
    (mkOptionsModule ../my/users/theming/options-linux.nix { inherit lib; })
    (mkOptionsModule ../my/storage/impermanence/options.nix { inherit lib; })
    (mkOptionsModule ../my/filesystem-options.nix { inherit lib; })
    (mkOptionsModule ../my/system/core/options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/bluetooth/options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/motherboards/options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/cooling/options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/peripherals/options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/laptops/lenovo/options.nix { inherit lib; })

    # Each of these has NO darwin implementation, so declaring them in
    # ./common.nix would make them settable-but-inert there. my/presets sets
    # my.environment.enable and my.performance.enable, so it is Linux-only too.
    (mkOptionsModule ../my/forensics/options.nix { inherit lib; })
    (mkOptionsModule ../my/environment/options.nix { inherit lib; })
    (mkOptionsModule ../my/performance/options.nix { inherit lib; })
    (mkOptionsModule ../my/presets-options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/security-keys/options.nix { inherit lib; })
    (mkOptionsModule ../my/users/input/options-linux.nix { inherit lib; })
    (mkOptionsModule ../my/graphical/options.nix { inherit lib; })
    (mkOptionsModule ../my/streaming/options.nix { inherit lib; })
    (mkOptionsModule ../my/ai/options.nix { inherit lib; })
    (mkOptionsModule ../my/video/virtual/options.nix { inherit lib; })
    (mkOptionsModule ../my/theming/options.nix { inherit lib; })
    (mkOptionsModule ../my/infra/options.nix { inherit lib; })
    (mkOptionsModule ../my/infra/radicle/options.nix { inherit lib; })
    # The two SERVICES a radicle node can be. Declarations rather than
    # implementations: each sets defaults on its own submodule, which is what
    # keeps them out of the infinite recursion a sibling module would hit -- see
    # the header of my/infra/radicle/seed.nix. Imported bare, not through
    # mkOptionsModule, because they declare `options.my.infra` directly.
    ../my/infra/radicle/seed.nix
    ../my/infra/radicle/builder.nix
    (mkOptionsModule ../my/virtualisation/options.nix { inherit lib; })
    (mkOptionsModule ../my/dev/remote-builders/options-linux.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/boot/options.nix { inherit lib; })
    (mkOptionsModule ../my/storage/options.nix { inherit lib; })
    (mkOptionsModule ../my/network/options.nix { inherit lib; })
  ]

  # Hyprland/vogix opinionated defaults.
  ++ [
    ../my/users/theming/vogix/mynixos-linux.nix
    ../my/theming/hypr-vogix/mynixos-linux.nix
  ]

  # NOTE: there is deliberately no "this option is darwin-only" stub module
  # here. Declaring such an option in order to attach a nicer message makes the
  # option EXIST on Linux, and an `apply = _: throw ...` only fires when the
  # option is read -- which nothing on Linux does. The result is a silent no-op,
  # i.e. strictly worse than the structural behaviour.
  #
  # Leaving darwin-only options declared solely in ./darwin.nix means the module
  # system rejects them at definition-merge time, unconditionally:
  #
  #     error: The option `my.homebrew' does not exist.
  #
  # (nixpkgs' mkRemovedOptionModule gets away with `apply` because it also emits
  # a `config.assertions` entry; assertions only fire at build time, so even that
  # would be weaker than not declaring the option at all.)

  # -----------------------------------------------------------------------
  # Opinionated defaults that only make sense on Linux
  # -----------------------------------------------------------------------
  ++ [
    # launcher/locker selectors (the vogix shell's own tools) -- these name
    # the package in the option value, so they must not be declared on darwin.
    ../my/users/environment/mynixos-linux.nix
    ../my/users/users/mynixos-linux.nix
    ../my/users/graphical/mynixos-linux.nix
    ../my/users/graphical/media/mynixos-linux.nix
    ../my/users/terminal/mynixos-linux.nix
    ../my/users/apps/xdg/linux.nix
  ]

  # -----------------------------------------------------------------------
  # Implementations: top-level features
  # -----------------------------------------------------------------------
  ++ [
    ../my/ai
    ../my/ai/claude-code-proxy
    ../my/ai/openclaw
    ../my/audio
    ../my/dev/development
    ../my/environment
    ../my/presets
    ../my/performance
    ../my/streaming
    ../my/video/virtual

    # Graphical
    ../my/graphical
    ../my/graphical/login
    ../my/graphical/hyprland

    # Behavior (modes, kanata) handled by vogix.nixosModules.default

    # Security
    ../my/security

    # System
    ../my/system/core
    ../my/system/kernel
    ../my/system/systemd
    # A duplicate uid or gid makes two accounts one principal, and neither
    # NixOS nor `getent` objects. Fleet-wide because it is a property of any
    # machine with accounts, not of anything radicle-specific.
    ../my/system/unique-ids

    # Theming
    ../my/theming
  ]

  # -----------------------------------------------------------------------
  # Hardware
  # -----------------------------------------------------------------------
  ++ [
    ../my/hardware/bluetooth/realtek

    # Authentication devices — device wiring (pcscd, udev, PAM), the same shape
    # as bluetooth/realtek.
    ../my/hardware/security-keys/yubico

    ../my/hardware/boot/uefi

    ../my/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb

    ../my/hardware/cpu/amd
    ../my/hardware/cpu/intel

    ../my/hardware/gpu/amd
    ../my/hardware/gpu/nvidia

    ../my/hardware/laptops/lenovo/legion-16irx8h

    ../my/hardware/memory/optimization

    ../my/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7

    ../my/hardware/peripherals/apple
    ../my/hardware/peripherals/elgato
    ../my/hardware/peripherals/keychron
    ../my/hardware/peripherals/sipeed

    ../my/hardware/storage/nvme
    ../my/hardware/storage/sata
    ../my/hardware/storage/ssd
    ../my/hardware/storage/usb

    ../my/hardware/usb/hid
    ../my/hardware/usb/thunderbolt
    ../my/hardware/usb/xhci
  ]

  # -----------------------------------------------------------------------
  # Network / infrastructure / storage
  # -----------------------------------------------------------------------
  ++ [
    ../my/network/openssh
    ../my/network/headscale
    ../my/network/tailscale
    ../my/network/tor
    ../my/network/monitoring
    ../my/network/ipv6
    ../my/network/unifi

    ../my/infra/github-runner
    ../my/infra/k3s
    ../my/infra/radicle
    # How a host runs OTHER MYNIXOS SYSTEMS inside itself. Linux-only by
    # construction: podman and virtualisation.oci-containers are.
    ../my/virtualisation/containers

    # `system.build.image`: this machine, taken as a container image. An OUTPUT
    # of a Linux configuration rather than a kind of configuration -- the same
    # relationship `system.build.vm` already has, declared the same way through
    # extendModules. Nothing here makes a machine a container; it makes one
    # available from it.
    ../my/system/oci-image

    # Remote nix builders, client half (nix.buildMachines). The darwin half
    # (accepting builds) is my/dev/remote-builders/darwin.nix.
    ../my/dev/remote-builders

    # impermanence: the implementation plus its two aggregation modules. The
    # aggregations emit only `my.*`, but tmpfs-root persistence has no macOS
    # counterpart, so they are Linux-only by MEANING, not just by mechanism.
    ../my/storage/impermanence/impermanence.nix
    ../my/storage/impermanence/aggregation.nix
    ../my/storage/impermanence/feature-aggregation.nix
  ]

  # -----------------------------------------------------------------------
  # Users. `my/users/users` builds a NixOS user (isNormalUser, extraGroups,
  # hashedPasswordFile, security.sudo); `my/users/webapps` emits the NixOS-only
  # programs._1password{,-gui}.
  # -----------------------------------------------------------------------
  ++ [
    ../my/users/users
    ../my/users/webapps
  ]

  # -----------------------------------------------------------------------
  # Per-user apps that are structurally portable (they emit only
  # `home-manager.users.*`) but are Linux-only in practice: Wayland/X11
  # packages, HM systemd.user services, or NixOS-only options.
  # -----------------------------------------------------------------------
  ++ [
    ../my/users/apps/media/pipewire-tools # PipeWire
    ../my/users/apps/browsers/brave/linux.nix
    ../my/users/apps/terminals/wezterm/linux.nix
    ../my/users/apps/file-managers/yazi/linux.nix
    ../my/users/apps/multiplexers/zellij/linux.nix
    ../my/users/apps/multiplexers/herdr/linux.nix
    # Discord: the nixpkgs derivation. macOS gets a Homebrew cask instead,
    # because nixpkgs breaks the bundle's code signature -- the darwin half of
    # this app explains why at length
    ../my/users/apps/communication/discord
    ../my/secrets/linux.nix
    ../my/users/apps/art/krita
    ../my/users/apps/art/gimp
    ../my/users/apps/media/kdenlive
    ../my/users/apps/art/mypaint
    ../my/users/apps/media/audacious
    ../my/users/apps/media/audio-utils
    ../my/users/apps/media/qobine # alsa-lib; packages/qobine is Linux-only
    ../my/users/apps/dev/radicle/options-linux.nix # its option: HM-only, Linux-only
    ../my/users/apps/dev/radicle/linux.nix # user radicle-node: HM systemd.user service
    ../my/users/apps/security/1password # programs._1password{,-gui}
    ../my/users/apps/viewers/feh # X11
    ../my/users/apps/visualizers/bespec # packages/bespec: platforms = [ "x86_64-linux" ]
  ];
}
