{ config, lib, ... }:

{
  # AMD Radeon *integrated* graphics quirks for this machine's Raphael
  # (gfx10.3.6, RDNA2) iGPU.
  #
  # The generic amdgpu driver + Mesa/VA-API are provided by my/hardware/gpu/amd
  # (activated by `my.hardware.gpu = "amd"`, which this motherboard sets). This
  # file adds ONLY what is specific to this iGPU / its display.

  boot.kernelParams = [
    # Disable GFXOFF (PP_GFXOFF_MASK, bit 0x8000).
    #
    # RDNA2 integrated GPUs have a buggy graphics-engine power-off/-on
    # transition that throws `GCVM_L2_PROTECTION_FAULT` (an SQC shader hits
    # unmapped memory) -> `ring gfx timeout` -> full GPU reset. Hyprland has no
    # GPU-reset recovery — it deliberately RASSERT-aborts in
    # CHyprOpenGLImpl::begin ("Cannot continue until proper GPU reset handling
    # is implemented", hyprwm/Hyprland#9746) — so a reset takes down the whole
    # session. The same fault + this exact fix are confirmed on the Steam Deck
    # RDNA2 iGPU (https://discourse.nixos.org/t/yet-another-gcvm-l2-protection-fault-status-problem/65420)
    # and documented on the Arch wiki AMDGPU page.
    #
    # Value = this GPU's *default* ppfeaturemask (0xfff7bfff) with ONLY the
    # GFXOFF bit cleared: 0xfff7bfff & ~0x8000 = 0xfff73fff. Every other
    # PowerPlay feature is left at its default (unlike the blunt 0xf7fff some
    # guides suggest). Trade-off: marginally higher idle GPU power.
    "amdgpu.ppfeaturemask=0xfff73fff"

    # 10-bit / deep colour for the OLED display (preserved from the prior config).
    "amdgpu.deep_color=1"
  ];

  # CPU microcode updates (AMD).
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
