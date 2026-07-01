{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.system;
  ls = cfg.kernel.localSource;

  # Build a kernel package set from a local source tree by overriding a nixpkgs
  # mainline kernel. `argsOverride` is the ONLY channel that reaches buildLinux's
  # src/version/modDirVersion (mainline.nix computes those internally and merges
  # argsOverride last, so a top-level `.override { src = ...; version = ...; }` is
  # silently ignored). common-config.nix still regenerates the NixOS-required
  # config, parameterized by `version`, so no .config file is maintained by hand.
  kernelFromSource =
    let
      base = if ls.base != null then ls.base else pkgs.linux_latest;
      kernel = base.override {
        argsOverride = {
          inherit (ls) src version;
          modDirVersion = if ls.modDirVersion != null then ls.modDirVersion else ls.version;
        };
      };
    in
    pkgs.linuxPackagesFor kernel;
in
{
  config = mkMerge [
    # Hostname configuration
    {
      networking.hostName = mkDefault (
        if cfg.hostname != null then cfg.hostname
        else throw "my.system.hostname must be set"
      );
    }

    # Kernel configuration.
    # Precedence: localSource (build from a local tree) > package override >
    # mynixos default (linuxPackages_latest). The localSource branch assigns at
    # normal priority so it beats hardware mkDefault overrides while remaining
    # host-mkForce-overridable. NixOS's boot.kernelPackages `apply` still appends
    # config.boot.kernelPatches on top of the source build (e.g. KUnit config).
    # Use mkIf (deferred), NOT a bare if/else on `ls`: branching the module's
    # config structure on a config value triggers infinite recursion.
    (mkIf (ls != null) {
      boot.kernelPackages = kernelFromSource;
    })
    (mkIf (ls == null) {
      # `package` (when set) at NORMAL priority so it overrides a hardware
      # module's mkDefault kernel (e.g. the Legion's mkDefault linuxPackages_latest
      # in legion-16irx8h/drivers/uefi-boot.nix); only the fallback is mkDefault,
      # so hardware may still pick a default. A host mkForce still wins over both.
      boot.kernelPackages =
        if cfg.kernel.package != null
        then cfg.kernel.package
        else mkDefault pkgs.linuxPackages_latest; # mynixos default
    })

    # Architecture configuration (auto-detected from hardware, can be overridden)
    (mkIf (cfg.architecture != null) {
      nixpkgs.hostPlatform = mkDefault cfg.architecture;
    })
  ];
}
