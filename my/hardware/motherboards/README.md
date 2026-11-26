# Machines

Hardware-specific configurations organized by exact hardware model.

## Philosophy

Machines contain **pure hardware configuration** - everything needed to make the physical hardware work, independent of what system/workload runs on it.

## Structure

```
motherboards/
├── options.nix                            # my.hardware.motherboards.*
└── gigabyte/
    ├── x870e-aorus-elite-wifi7/
    │   ├── default.nix                    # Profile: component options, firmware, networking
    │   ├── drivers/
    │   │   ├── amd-integrated-gpu.nix     # Raphael iGPU quirks
    │   │   └── uefi-boot.nix              # Boot configuration
    │   └── scripts/
    └── trx50-aero-d/
        ├── default.nix                    # Profile: component options, networking
        └── hardware-configuration.nix     # Board facts: linux-firmware for the WCN785x
```

Laptops live under `my/hardware/laptops/<vendor>/<model>/` with the same shape
(e.g. `lenovo/legion-16irx8h/drivers/`).

Firmware is a profile fact: each profile sets
`hardware.enableRedistributableFirmware` inside its own `enable`, instead of
importing nixpkgs' `installer/scan/not-detected.nix`, which (being an import)
would apply to every Linux host whether or not the board is in it.

## What Goes in Machines?

### ✅ Include:
- Hardware scan results (`boot.initrd.availableKernelModules`)
- Kernel modules for hardware (`amdgpu`, `kvm-intel`)
- Hardware-specific kernel parameters
- Driver configuration (GPU, audio, network)
- CPU microcode updates
- Firmware updates
- Hardware quirks/fixes (e.g., speaker unmute)
- Power management for specific hardware

### ❌ Exclude:
- Application software
- User preferences
- Stack/service configuration
- Hostname
- Timezone
- Locale settings
- User accounts

## Component Modules

Each machine has a `drivers/` directory containing hardware-specific modules:

- **{hardware-component}.nix** - Named after actual hardware (e.g., `amd-integrated-gpu.nix`, `intel-13900hx-cpu.nix`)
- Drivers configure kernel modules, firmware, and hardware-specific settings
- Hardware fixes (e.g., speaker unmute) belong here
- No applications or tools - just driver configuration

## Usage

Machines are referenced by Systems:

```nix
# Systems/yoga/configuration.nix
{
  imports = [
    ../../Machines/gigabyte-x870e-aorus-elite-wifi7
  ];
  
  # System config here (stacks, hostname, etc.)
}
```

## Benefits

1. **Hardware independence**: Same hardware config works for any system
2. **Reusability**: Multiple systems can use same hardware profile
3. **Maintainability**: Hardware changes isolated from system config
4. **Clarity**: Clear separation of "what is hardware" vs "what is software"
5. **Portability**: Easy to migrate system configs between hardware

## Examples

### Same Hardware, Different Systems
```
workstation-system → gigabyte-x870e-aorus-elite-wifi7
gaming-system     → gigabyte-x870e-aorus-elite-wifi7
```

### Same System, Different Hardware
```
laptop-system → lenovo-legion-16irx8h
laptop-system → framework-laptop-13
```
