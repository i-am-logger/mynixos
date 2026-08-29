# Booting VM test for the graphical login (my.environment.login) — the first
# runtime test that evaluates vogix INSIDE mynixos: the node's pkgs carry the
# vogix overlay through my/theming/vogix, the REAL host path.
#
# What runtime alone can prove here: SDDM actually starts under the vogix
# look, the vogix QML greeter actually renders (OCR on its hostname line),
# the rendered theme.conf really carries the first vogix user's palette,
# typed credentials really authenticate through SDDM's PAM stack, and a
# logind session appears for the user.
#
# Harness notes (they differ from tests/vm-system.nix on purpose):
# - node.pkgsReadOnly = false and NO `pkgs` in node.specialArgs: specialArgs
#   beat _module.args, so a pinned pkgs would defeat the vogix overlay that
#   my/theming/vogix contributes — the exact thing this test must exercise.
# - The greeter compositor is weston (my.environment.login.compositor):
#   nixpkgs' default for SDDM-Wayland, software-rendered, so the greeter
#   comes up without GL. Hyprland-as-greeter-host is validated on hosts.
# - The SESSION behind a successful login is Hyprland, which the qemu node
#   cannot reliably run; the test therefore asserts authentication +
#   session registration, not a running session compositor.
#
# HEAVY (boots a VM with the vogix closure; needs /dev/kvm), so it lives
# under the `tests` output: `nix build .#tests.<sys>.vm-login -L`.
{ self, inputs, system, nixpkgs, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
pkgs.testers.runNixOSTest {
  name = "mynixos-vm-login";

  enableOCR = true;

  # Mirrors lib/mkSystem.nix WITHOUT pkgs (see harness notes above).
  node.specialArgs = {
    inherit inputs self;
    inherit (inputs)
      disko
      impermanence
      vogix
      hypr-vogix
      lanzaboote
      sops-nix
      ;
  };
  node.pkgsReadOnly = false;

  nodes.machine = { lib, ... }: {
    imports = [
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    # pkgsReadOnly is off, so the node must pin its own platform; the vogix
    # overlay and the my.system.allowedUnfreePackages admission then arrive
    # through the module system like on a real host.
    nixpkgs.hostPlatform = system;

    boot.loader.grub.enable = false;
    system.stateVersion = "24.11";
    networking.hostName = lib.mkForce "vmlogin";

    virtualisation = {
      memorySize = 4096;
      cores = 4;
    };

    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [{ home.stateVersion = "24.11"; }];
    };

    my = {
      system.enable = true;
      system.hostname = "vmlogin";

      # The whole point: theming ON, so the vogix overlay, the shell and the
      # greeter all wire the way a real host does.
      theming = {
        enable = true;
        vogix.enable = true;
      };

      # The default login under theming is sddm+vogix; only the greeter
      # compositor is overridden for the GL-less VM.
      environment.login.compositor = "weston";

      users.dana = {
        fullName = "Dana Example";
        description = "Dana Example";
        email = "dana@example.com";
        graphical.enable = true;
        # Keep the closure lean where the login test gains nothing:
        apps.terminal = {
          sysinfo.btop.enable = false;
          visualizers.bespec.enable = false;
          visualizers.cava.enable = false;
        };
      };
    };

    home-manager.users.dana = {
      # One prebuilt theme instead of the whole universe.
      programs.vogix.appearance.prebuiltThemes = [ "yoga" ];
    };

    # A known password for the typed-credentials flow (initialPassword is
    # hashed at activation — the idiomatic form for test users).
    users.users.dana.initialPassword = "vogix-test";
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    with subtest("SDDM is the display manager and is running"):
        machine.wait_for_unit("display-manager.service")
        machine.succeed("systemctl cat display-manager.service | grep -qi sddm")

    with subtest("the vogix theme.conf carries the first vogix user's palette"):
        conf = machine.succeed(
            "cat /run/current-system/sw/share/sddm/themes/vogix/theme.conf")
        # yoga-night base00 — the semantic `background` slot.
        assert "background=#232020" in conf, f"palette missing from theme.conf:\n{conf}"
        assert "foreground_text=#" in conf, "semantic keys missing from theme.conf"

    with subtest("the runtime-follow drop zone exists with the vogix group"):
        machine.succeed("test -d /var/lib/vogix/greeter")
        machine.succeed("stat -c %G /var/lib/vogix/greeter | grep -qx vogix")
        machine.succeed("id -nG dana | tr ' ' '\n' | grep -qx vogix")

    with subtest("the vogix greeter renders (hostname on the auth card)"):
        machine.wait_for_text("vmlogin", timeout=120)
        machine.screenshot("greeter")

    with subtest("typed credentials authenticate through SDDM"):
        machine.send_chars("dana\n")
        machine.sleep(1)
        machine.send_chars("vogix-test\n")
        # Authentication success = a logind session for dana. The Hyprland
        # session itself cannot run in this VM; the greeter handing off is
        # what this asserts.
        machine.wait_until_succeeds(
            "loginctl --no-legend list-sessions | grep -q dana", timeout=90)
  '';
}
