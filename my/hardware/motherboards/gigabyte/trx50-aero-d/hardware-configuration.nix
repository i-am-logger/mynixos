# Hardware configuration for Gigabyte TRX50 AERO D (sTR5, AMD TRX50 chipset).
#
# A Threadripper workstation board: no integrated GPU, three onboard network
# controllers, and two Thunderbolt 4 controllers. The kernel-module work is done
# by the component modules the profile turns on (my/hardware/storage/*,
# my/hardware/usb/*, my/hardware/cpu/amd, my/hardware/gpu/amd), so what is left
# here is what is true of THIS BOARD and nothing else.
{ config
, lib
, modulesPath
, ...
}:

let
  cfg = config.my.hardware.motherboards.gigabyte.trx50-aero-d;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Everything below is gated on the board being the one in the machine. A
  # module's `imports` cannot be conditional, so this file is evaluated on every
  # host that has the motherboard set in scope — ungated, its firmware default
  # would land on hardware that is not this board.
  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ ];

    # All three onboard network controllers are in-tree, so none needs an
    # out-of-tree package — but the Qualcomm WCN785x loads its firmware from
    # linux-firmware, which is redistributable-but-unfree. Without this the radio
    # is simply absent, with nothing in the module list to say why.
    #   eno1      Aquantia AQC113C 10GbE     atlantic
    #   enp101s0  Realtek RTL8125 2.5GbE     r8169
    #   wlp100s0  Qualcomm WCN785x Wi-Fi 7   ath12k_pci
    hardware.enableRedistributableFirmware = lib.mkDefault true;

    # No `boot.kernelParams`. The X870E profile has several and every one is
    # specific to that machine's iGPU or to an Elgato capture card on its
    # HDMI-A-1 — a forced EDID blob, static_hdmi_pcm, video=HDMI-A-1:e. None of
    # that is a property of this board, and an unconditional `video=` line on a
    # workstation with DisplayPort outputs is actively wrong.
  };
}
