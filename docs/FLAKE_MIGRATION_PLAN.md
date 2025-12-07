# flake.nix Migration Plan

## Problem Statement

The current `flake.nix` has grown to **2018 lines** with the following issues:

1. **Size & Complexity:** Single file with 200+ option definitions
2. **Duplication:** `my.apps.*` and `my.users.<name>.apps.*` repeat similar structures
3. **Unclear Semantics:** Confusion about which namespace to use (system vs. per-user)
4. **Maintainability:** Hard to navigate, prone to merge conflicts
5. **Scalability:** Adding new options requires editing massive file

## Goals

1. **Reduce flake.nix to < 300 lines** (core structure only)
2. **Extract option definitions** to separate, organized files
3. **Eliminate or clarify** `my.apps.*` vs `my.users.<name>.apps.*` confusion
4. **Improve maintainability** with clear file organization
5. **Preserve compatibility** during migration (breaking changes acceptable per user preference)

## Proposed Structure

```
flake.nix                   # Core structure (~200-300 lines)
├── options/
│   ├── system.nix          # my.system.* options
│   ├── security.nix        # my.security.* options
│   ├── environment.nix     # my.environment.* options
│   ├── hardware.nix        # my.hardware.* options
│   ├── storage.nix         # my.storage.* options
│   ├── boot.nix            # my.boot.* options
│   ├── graphical.nix       # my.graphical.* options
│   ├── dev.nix             # my.dev.* options
│   ├── ai.nix              # my.ai.* options
│   ├── streaming.nix       # my.streaming.* options
│   ├── video.nix           # my.video.* options
│   ├── infra.nix           # my.infra.* options
│   ├── performance.nix     # my.performance.* options
│   ├── motd.nix            # my.motd.* options
│   ├── themes.nix          # my.themes.* options
│   ├── presets.nix         # my.presets.* options
│   └── users/
│       ├── base.nix        # Basic user properties (name, email, shell, etc.)
│       ├── graphical.nix   # my.users.<name>.graphical.* options
│       ├── dev.nix         # my.users.<name>.dev.* options
│       ├── ai.nix          # my.users.<name>.ai.* options
│       ├── terminal.nix    # my.users.<name>.terminal.* options
│       ├── hyprland.nix    # my.users.<name>.hyprland.* options
│       └── apps.nix        # my.users.<name>.apps.* options (if kept)
└── lib/
    └── app-option.nix      # Reusable function for app options
```

## Migration Strategy

### Phase 1: Clarify Apps Namespace (HIGH PRIORITY)

**Decision Required:** Choose one of these approaches:

#### Option A: Deprecate `my.apps.*` Entirely (RECOMMENDED)
- **Rationale:** Apps are inherently per-user preferences
- **Implementation:**
  1. Remove `my.apps.*` namespace from flake.nix
  2. Keep only `my.users.<name>.apps.*` for per-user configuration
  3. Update all app modules to check `userCfg.apps.*` only
  4. Document migration in CHANGELOG

**Pros:**
- Simplifies API (one way to configure apps)
- Eliminates duplication
- Clear semantics (apps are user preferences)

**Cons:**
- Breaking change (acceptable per user)
- Requires updating any configs using `my.apps.*`

#### Option B: Make `my.apps.*` System-Wide Defaults
- **Rationale:** System defaults + per-user overrides pattern
- **Implementation:**
  1. Document `my.apps.*` as system-wide defaults
  2. Have `my.users.<name>.apps.*` inherit from `my.apps.*` with override capability
  3. Update app modules to merge system and user settings

**Pros:**
- Provides system-wide defaults
- Users can override per-user
- Familiar pattern from NixOS

**Cons:**
- More complex implementation
- Inheritance logic adds overhead
- Still have duplication in flake.nix

#### Option C: Keep Both, Document Clearly
- **Rationale:** Minimal breaking changes
- **Implementation:**
  1. Document that `my.apps.*` affects ALL users
  2. Document that `my.users.<name>.apps.*` is per-user
  3. Clarify in descriptions when to use each

**Pros:**
- No breaking changes
- Flexibility for different use cases

**Cons:**
- Confusion remains
- Duplication persists
- More complex to understand

**RECOMMENDATION:** Option A (Deprecate `my.apps.*`)
- Aligns with "API is unstable, breaking changes acceptable"
- Simplest and clearest semantics
- Eliminates primary source of duplication

### Phase 2: Extract Option Definitions (MEDIUM PRIORITY)

1. **Create `options/` directory structure**
   ```bash
   mkdir -p options/users
   ```

2. **Extract system-level options** (one namespace at a time):
   ```nix
   # options/system.nix
   { lib, ... }:
   {
     my.system = lib.mkOption {
       description = "System-level configuration";
       default = { };
       type = lib.types.submodule {
         options = {
           hostname = lib.mkOption { ... };
           architecture = lib.mkOption { ... };
           kernel = lib.mkOption { ... };
         };
       };
     };
   }
   ```

3. **Extract user-level options**:
   ```nix
   # options/users/graphical.nix
   { lib, ... }:
   {
     graphical = lib.mkOption {
       description = "Graphical environment configuration";
       default = { };
       type = lib.types.submodule {
         options = {
           enable = lib.mkOption { ... };
           streaming = lib.mkOption { ... };
           webapps = lib.mkOption { ... };
           media = lib.mkOption { ... };
         };
       };
     };
   }
   ```

4. **Import in flake.nix**:
   ```nix
   # flake.nix
   options.my = {
     imports = [
       ./options/system.nix
       ./options/security.nix
       ./options/environment.nix
       # ... etc
     ];
   };

   options.my.users = lib.mkOption {
     type = lib.types.attrsOf (lib.types.submodule {
       imports = [
         ./options/users/base.nix
         ./options/users/graphical.nix
         ./options/users/dev.nix
         # ... etc
       ];
     });
   };
   ```

### Phase 3: Create Reusable App Option Function (LOW PRIORITY)

To reduce duplication in app option definitions:

```nix
# lib/app-option.nix
{ lib }:

{
  # Simple boolean app option with opinionated default
  mkAppOption = { name, default ? false, description }:
    lib.mkOption {
      type = lib.types.bool;
      inherit default;
      description = "${description} (default: ${if default then "true" else "false"})";
    };

  # App category submodule
  mkAppCategory = { name, apps }:
    lib.mkOption {
      description = "${name} applications";
      default = { };
      type = lib.types.submodule {
        options = apps;
      };
    };
}
```

Usage:
```nix
# options/users/apps.nix (if apps namespace is kept)
{ lib, ... }:

let
  appLib = import ../../lib/app-option.nix { inherit lib; };
in
{
  apps = lib.mkOption {
    description = "User application preferences";
    default = { };
    type = lib.types.submodule {
      options = {
        browsers = appLib.mkAppCategory {
          name = "Browser";
          apps = {
            brave = appLib.mkAppOption {
              name = "Brave";
              default = true;
              description = "Brave browser";
            };
            firefox = appLib.mkAppOption {
              name = "Firefox";
              default = false;
              description = "Firefox browser";
            };
          };
        };
        # ... more categories
      };
    };
  };
}
```

## Implementation Steps

### Step 1: Fix Apps Namespace (1-2 hours)

1. **Decision:** Choose Option A, B, or C above
2. **If Option A (Recommended):**
   ```bash
   # Remove my.apps.* from flake.nix
   # (Search for "my.apps = lib.mkOption" and remove entire block)

   # Verify no app modules use config.my.apps.* (already fixed in audit)
   grep -r "config\.my\.apps\." my/users/apps/

   # Update /etc/nixos configs if using my.apps.*
   grep -r "my\.apps\." /etc/nixos/
   ```

3. **Document in CHANGELOG:**
   ```markdown
   ## Breaking Changes

   - Removed `my.apps.*` namespace (use `my.users.<name>.apps.*` instead)
   - All app configurations are now per-user
   ```

### Step 2: Extract System Options (4-6 hours)

1. **Create options directory:**
   ```bash
   mkdir -p options/users
   ```

2. **Extract one namespace at a time** (priority order):
   - `system.nix` (hostname, architecture, kernel)
   - `hardware.nix` (cpu, gpu, peripherals)
   - `security.nix` (secureBoot, yubikey, audit)
   - `storage.nix` (impermanence, disko)
   - `boot.nix` (uefi, dual-boot, grub)
   - `environment.nix` (locale, timezone, packages)
   - `graphical.nix` (display manager, window manager)
   - `dev.nix` (docker, binfmt, direnv)
   - `ai.nix` (ollama, rocm)
   - `streaming.nix` (obs, virtual camera)
   - `infra.nix` (k3s, github-runner)
   - `performance.nix` (zram, vmtouch)
   - `motd.nix`, `themes.nix`, `presets.nix`, `video.nix`

3. **For each namespace:**
   ```bash
   # 1. Create options file
   touch options/system.nix

   # 2. Copy option definition from flake.nix to options/system.nix
   # 3. Add imports at top: { lib, pkgs, ... }:
   # 4. Wrap in { my.system = lib.mkOption { ... }; }
   # 5. Test: nix flake check
   # 6. Remove from flake.nix, add to imports
   # 7. Test again: nix flake check
   ```

### Step 3: Extract User Options (3-5 hours)

1. **Extract user option categories:**
   - `options/users/base.nix` - name, email, shell, hashedPassword, packages, github, etc.
   - `options/users/graphical.nix` - graphical, streaming, webapps, media
   - `options/users/dev.nix` - dev, docker
   - `options/users/ai.nix` - ai options
   - `options/users/terminal.nix` - terminal, multiplexer, file managers
   - `options/users/hyprland.nix` - hyprland configuration
   - `options/users/apps.nix` - apps namespace (if kept)

2. **For each user namespace:**
   ```bash
   # 1. Create options file
   touch options/users/graphical.nix

   # 2. Copy user option definition from flake.nix
   # 3. Make it a submodule that will be imported into users.<name>
   # 4. Test: nix flake check
   ```

### Step 4: Create App Option Library (Optional, 2-3 hours)

1. **Create `lib/app-option.nix`** (see Phase 3 above)
2. **Refactor app options to use library functions**
3. **Document usage pattern**

### Step 5: Update flake.nix Structure (1 hour)

Final `flake.nix` structure:

```nix
{
  description = "mynixos - Typed functional DSL for NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = { ... };
    # ... other inputs
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Helper functions
      # ...
    in
    {
      nixosModules.default = { config, lib, pkgs, ... }: {
        imports = [
          # Module imports (unchanged)
          ./my/system/kernel.nix
          ./my/security/security.nix
          # ... ~90 module imports
        ];

        options.my = {
          # Import option definitions
          imports = [
            ./options/system.nix
            ./options/security.nix
            ./options/environment.nix
            ./options/hardware.nix
            ./options/storage.nix
            ./options/boot.nix
            ./options/graphical.nix
            ./options/dev.nix
            ./options/ai.nix
            ./options/streaming.nix
            ./options/video.nix
            ./options/infra.nix
            ./options/performance.nix
            ./options/motd.nix
            ./options/themes.nix
            ./options/presets.nix
          ];
        };

        options.my.users = lib.mkOption {
          description = "User configurations";
          default = { };
          type = lib.types.attrsOf (lib.types.submodule {
            imports = [
              ./options/users/base.nix
              ./options/users/graphical.nix
              ./options/users/dev.nix
              ./options/users/ai.nix
              ./options/users/terminal.nix
              ./options/users/hyprland.nix
              ./options/users/apps.nix  # if kept
            ];
          });
        };
      };

      lib = {
        mkSystem = { ... }: # Unchanged
      };

      # Hardware modules (unchanged)
      hardware = { ... };
    };
}
```

## Testing Strategy

1. **After each extraction:**
   ```bash
   nix flake check
   nixos-rebuild build --flake .#yoga
   nixos-rebuild build --flake .#skyspy-dev
   ```

2. **Regression testing:**
   - Verify all options still recognized
   - Check that builds produce same closure
   - Test user configs still work

3. **Validation checklist:**
   - [ ] `nix flake check` passes
   - [ ] yoga builds successfully
   - [ ] skyspy-dev builds successfully
   - [ ] No evaluation errors or warnings
   - [ ] Option documentation intact (`nix flake show`)
   - [ ] User overrides still work

## Timeline Estimate

| Phase | Task | Effort | Priority |
|-------|------|--------|----------|
| 1 | Clarify apps namespace | 1-2 hours | HIGH |
| 2 | Extract system options | 4-6 hours | MEDIUM |
| 3 | Extract user options | 3-5 hours | MEDIUM |
| 4 | Create app option library | 2-3 hours | LOW |
| 5 | Update flake.nix structure | 1 hour | HIGH |
| - | **TOTAL** | **11-17 hours** | - |

**Recommended approach:** Do Phase 1 + Phase 5 first (3-4 hours) for immediate impact, then incrementally extract options over time.

## Benefits After Migration

1. **Maintainability:**
   - Easy to find and edit specific options
   - Clear file organization
   - Reduced merge conflicts

2. **Clarity:**
   - One clear way to configure apps
   - Option definitions grouped logically
   - Easier to understand namespace structure

3. **Scalability:**
   - New options added to dedicated files
   - Reusable option patterns
   - Easier to contribute new features

4. **Documentation:**
   - Self-documenting file structure
   - Clear separation of concerns
   - Easier to generate API docs

## Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking user configs | Document changes in CHANGELOG, provide migration guide |
| Import ordering issues | Test thoroughly after each extraction |
| Increased file count | Clear naming and directory structure |
| Performance impact | Minimal - imports are evaluated once |

## Rollback Plan

If migration causes issues:

1. **Git revert** to before migration
2. **Keep extracted files** in branch for future attempt
3. **Document blockers** for next attempt
4. **Incremental approach** instead of all-at-once

## Next Steps

1. **Get user approval** on apps namespace decision (Option A/B/C)
2. **Create feature branch:** `git checkout -b refactor/flake-extraction`
3. **Start with Phase 1** (apps namespace clarification)
4. **Incremental commits** for each extracted namespace
5. **Test thoroughly** at each step
6. **Merge when stable**

---

**Status:** DRAFT - Awaiting user decision on apps namespace approach
**Author:** mynixos Architect Agent
**Date:** 2025-12-06
