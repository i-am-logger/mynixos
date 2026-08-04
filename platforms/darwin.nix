# mynixos composition layer: nix-darwin (macOS).
#
# Everything here targets options only nix-darwin declares -- `homebrew.*`,
# `system.defaults.*`, `security.pam.services.sudo_local`, launchd daemons -- or
# is a macOS-specific implementation of a cross-platform option.
#
# Because a file imported only from here cannot run on Linux, modules in this
# list need no `pkgs.stdenv.hostPlatform.isDarwin` guard.
#
# See ./common.nix for the classification rule.

{ lib, ... }:

let
  mkOptionsModule = path: args: _: { options.my = import path args; };
in
{
  imports = [
    ./common.nix
  ]

  # -----------------------------------------------------------------------
  # Options whose implementation is darwin-only. Declared here rather than in
  # ./common.nix so that a NixOS host setting them fails with "The option
  # `my.homebrew.enable' does not exist" instead of silently doing nothing.
  # -----------------------------------------------------------------------
  ++ [
    (mkOptionsModule ../my/system/homebrew/options.nix { inherit lib; })
    (mkOptionsModule ../my/hardware/laptops/apple/options.nix { inherit lib; })
    (mkOptionsModule ../my/system/nix-gc/options.nix { inherit lib; })

    # On darwin this is the ONLY declaration of `my.network` — the rest of that
    # submodule (openssh, tailscale, headscale, tor, …) is Linux-only and declared
    # in ./linux.nix. `types.submodule` declarations merge, so on Linux the two
    # compose; here `my.network` has exactly one key.
    (mkOptionsModule ../my/network/ssh-firewall/options.nix { inherit lib; })

    # Touch ID / Watch ID. Merges into the cross-platform my.hardware submodule.
    (mkOptionsModule ../my/hardware/biometrics/options.nix { inherit lib; })
  ]

  # -----------------------------------------------------------------------
  # Opinionated defaults that only make sense on macOS
  # -----------------------------------------------------------------------
  ++ [
    # macOS is graphical by construction -- mkForce, not mkDefault.
    ../my/users/graphical/mynixos-darwin.nix
    ../my/users/users/mynixos-darwin.nix
    ../my/users/terminal/mynixos-darwin.nix
  ]

  # -----------------------------------------------------------------------
  # Users. The NixOS my/users/users builds a full account (isNormalUser,
  # extraGroups, hashedPasswordFile, sudo rules); macOS accounts are created by
  # the OS, so the darwin counterpart only records the home directory.
  # -----------------------------------------------------------------------
  ++ [
    ../my/users/users/darwin.nix

    # Pointer preferences (leftHanded, naturalScroll) -> NSGlobalDomain.
    ../my/users/input/darwin.nix
  ]

  # -----------------------------------------------------------------------
  # Implementations
  # -----------------------------------------------------------------------
  ++ [
    # Homebrew, for the handful of things nixpkgs genuinely cannot provide
    # (Mac App Store apps, Background Music).
    ../my/system/homebrew

    # `nix.gc` is gated on nix-darwin's `nix.enable`, which is false on this
    # fleet (Nix stays owned by the NixOS nix-installer), so garbage collection
    # is wired as plain launchd daemons instead.
    ../my/system/nix-gc

    # Docker via Colima -- the macOS counterpart to my/dev/development's
    # `virtualisation.docker`. Reads the same `dev.docker.enable` option.
    ../my/dev/docker

    # Hardware. The model profile flips the generic category options below it,
    # mirroring how the Linux laptop/motherboard profiles compose.
    ../my/hardware/laptops/apple/macbook-pro-m5-max
    ../my/hardware/biometrics/apple
    ../my/hardware/audio/apple

    # pf-based restriction of sshd to the Tailscale interface. macOS's
    # application firewall (`alf`) has no interface or address concept, so it
    # cannot express this.
    ../my/network/ssh-firewall
  ]

  # -----------------------------------------------------------------------
  # Per-user apps that only exist on macOS
  # -----------------------------------------------------------------------
  ++ [
    # `caffeinate` front-end; keeps the Mac awake from the menu bar.
    ../my/users/apps/utils/keepingyouawake

    # 1Password: the .app bundle. The Linux side uses programs._1password{,-gui},
    # which nix-darwin does not declare.
    ../my/users/apps/security/1password/darwin.nix
  ];
}
