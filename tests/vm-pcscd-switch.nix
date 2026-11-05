# A switch that only changes the system packages leaves pcscd running.
#
# pcscd requires polkit, and nixpkgs restarts polkit whenever the system packages
# change, so the stop reaches a service whose own unit never changed. A card loses
# its verified PIN when that happens. The package added here carries a polkit action, because
# seeing new actions is why polkit is told about these changes at all.
#
# Heavy (boots a VM, needs /dev/kvm) => `tests` output:
#   nix build .#tests.<sys>.vm-pcscd-switch -L
{ self, inputs, system, nixpkgs, ... }:

let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  actionId = "test.pcscd.switch";
  actionPackage = pkgs.writeTextDir "share/polkit-1/actions/${actionId}.policy" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
      "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
    <policyconfig>
      <action id="${actionId}">
        <description>test</description>
        <message>test</message>
        <defaults>
          <allow_any>no</allow_any>
          <allow_inactive>no</allow_inactive>
          <allow_active>no</allow_active>
        </defaults>
      </action>
    </policyconfig>
  '';
in
pkgs.testers.runNixOSTest {
  name = "vm-pcscd-switch";

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
      hardware.securityKeys.yubico.enable = true;
    };

    environment.systemPackages = [ pkgs.socat ];
    specialisation.changed.configuration.environment.systemPackages = [ actionPackage ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # A connected client stops pcscd exiting on its idle timer during the test.
    machine.succeed(
        "systemd-run --unit=pcsc-client ${pkgs.bash}/bin/sh -c "
        "'${pkgs.coreutils}/bin/sleep 600 | ${pkgs.socat}/bin/socat - UNIX-CONNECT:/run/pcscd/pcscd.comm'"
    )
    machine.wait_until_succeeds("systemctl is-active pcscd.service polkit.service")

    pid = lambda unit: machine.succeed(f"systemctl show -p MainPID --value {unit}").strip()
    pcscd, polkit = pid("pcscd.service"), pid("polkit.service")
    assert pcscd != "0" and polkit != "0"
    machine.fail("pkaction --action-id ${actionId}")

    machine.succeed("/run/current-system/specialisation/changed/bin/switch-to-configuration test")

    assert pid("pcscd.service") == pcscd, "the switch restarted pcscd"
    assert pid("polkit.service") == polkit, "the switch restarted polkit"
    machine.wait_until_succeeds("pkaction --action-id ${actionId}", timeout=30)
  '';
}
