# Machines

Hardware-specific configurations organized by exact hardware model.

## Philosophy

Machines contain **pure hardware configuration** - everything needed to make the physical hardware work, independent of what system/workload runs on it.

## Structure

```
Machines/
├── gigabyte-x870e-aorus-elite-wifi7/
│   ├── default.nix                        # Main hardware config + imports
│   └── drivers/
│       ├── amd-integrated-gpu.nix         # AMD Radeon graphics driver
│       ├── realtek-audio.nix              # Audio chipset driver
│       ├── network.nix                    # Network hardware (Ethernet + WiFi7)
│       └── uefi-boot.nix                  # Boot configuration
│
└── lenovo-legion-16irx8h/
    ├── default.nix                        # Main hardware config + nixos-hardware
    └── drivers/
        ├── intel-13900hx-cpu.nix          # Intel CPU driver
        ├── nvidia-rtx4070.nix             # NVIDIA GPU driver
        ├── realtek-audio.nix              # Audio chipset + speaker fix
        ├── network.nix                    # Network hardware (WiFi 6E)
        ├── uefi-boot.nix                  # Boot configuration
        └── windows-dual-boot.nix          # Dual-boot hardware setup
```

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
- nixos-hardware module imports

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
