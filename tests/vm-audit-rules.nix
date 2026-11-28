# The locked audit rule set is in the kernel after boot, and a switch that
# changes the rules leaves it loaded and locked (S3).
#
# my.security.auditRules locks the set (-e 2), which can't be reloaded, so the
# loader runs once at boot and a switch never restarts or stops it. Before S3
# the loader was turned off entirely and the kernel held no rules at all.
#
# Heavy (boots a VM, needs /dev/kvm) => `tests` output:
#   nix build .#tests.<sys>.vm-audit-rules -L
{ self, inputs, system, nixpkgs, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
in
pkgs.testers.runNixOSTest {
  name = "vm-audit-rules";

  node.specialArgs = {
    inherit inputs self pkgs;
    inherit (inputs)
      disko
      impermanence
      vogix
      hypr-vogix
      lanzaboote
      sops-nix
      ;
  };

  nodes.machine = { lib, ... }: {
    imports = [
      self.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    boot.loader.grub.enable = false;
    system.stateVersion = "24.11";
    networking.hostName = lib.mkForce "machine";

    home-manager = {
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [{ home.stateVersion = "24.11"; }];
    };

    my = {
      system.enable = true;
      system.hostname = "machine";
      theming.enable = false;
      security = {
        enable = true;
        auditRules.enable = true;
      };
    };

    # A switch whose rule set differs from the booted one.
    specialisation.changed.configuration.security.audit.rules = [ "-w /var/empty -p wa -k vm_test_changed" ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("audit-rules-nixos.service")

    machine.succeed("auditctl -s | grep -q '^enabled 2'")
    machine.succeed("auditctl -l | grep -q 'key=root_commands'")
    machine.succeed("auditctl -l | grep -q -- '-k boot$'")

    machine.succeed("/run/current-system/specialisation/changed/bin/switch-to-configuration test")

    machine.succeed("systemctl is-active audit-rules-nixos.service")
    machine.succeed("auditctl -s | grep -q '^enabled 2'")
    machine.succeed("auditctl -l | grep -q 'key=root_commands'")
    machine.fail("auditctl -l | grep -q vm_test_changed")
  '';
}
