# Contributing to mynixos

Contributions are welcome.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a branch for your changes

## Before Submitting
```bash
nix fmt
nix flake check
```

## Pull Requests

- Keep changes focused
- Test on your hardware if adding hardware profiles
- Update documentation if needed

## Module Structure

Each module lives in `my/category/item/` with:
```
├── options.nix    # Type definitions
├── default.nix    # Implementation
└── mynixos.nix    # Opinionated defaults (uses mkDefault)
```

When adding defaults, always use `mkDefault` so users can override.

## Hardware Profiles

If you're adding support for new hardware:

1. Create a profile in `my/hardware/`
2. Test it on actual hardware
3. Document any quirks

## Questions

Open an issue if you're unsure about anything.
