# mynixos Architecture Patterns

## Critical Patterns (Learn From Mistakes)

### ❌ ANTI-PATTERN: options. wrapper in submodule imports

**WRONG:**
```nix
# options/users/environment.nix (WRONG!)
{ lib, ... }:
{
  options.environment = lib.mkOption {  # ← WRONG! Don't add options. prefix
    type = lib.types.submodule { ... };
  };
}
```

**CORRECT:**
```nix
# options/users/environment.nix (CORRECT!)
{ lib, ... }:
{
  environment = lib.mkOption {  # ← CORRECT! No options. prefix
    type = lib.types.submodule { ... };
  };
}
```

**Why:** Files imported in a submodule's `imports` array are already in the submodule's option definition context. The `options.` prefix is ONLY needed at the top level.

**Reference:** See `/home/logger/Code/github/logger/mynixos/options/users/graphical.nix` for correct pattern.

**Import Context:**
```nix
# options/users.nix - Top-level user submodule
{
  users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      imports = [
        ./users/environment.nix  # ← Files here are in submodule context
        ./users/graphical.nix
        ./users/terminal.nix
        # ...
      ];
    }));
  };
}

# flake.nix - Top-level options need prefix
{
  imports = [
    ({ ... }: { options.my = import ./options/users.nix { inherit lib; }; })
    #           ^^^^^^^^^^^ This is the TOP LEVEL - needs options. prefix
  ];
}
```

### ❌ ANTI-PATTERN: pkgs in option defaults

**WRONG:**
```nix
# options/users/environment.nix (WRONG!)
{ lib, pkgs, ... }:
{
  environment = lib.mkOption {
    type = lib.types.submodule {
      options = {
        BROWSER = lib.mkOption {
          type = lib.types.package;
          default = pkgs.brave;  # ← WRONG! Causes infinite recursion
        };
      };
    };
  };
}
```

**CORRECT:**
```nix
# options/users/environment.nix (CORRECT!)
{ lib, ... }:  # ← Don't take pkgs in options files
{
  environment = lib.mkOption {
    type = lib.types.submodule {
      options = {
        BROWSER = lib.mkOption {
          type = lib.types.nullOr packageType;
          default = null;  # ← CORRECT! Use null, set defaults elsewhere
          description = "Web browser. Opinionated default: brave (set in environment-defaults.nix)";
        };
      };
    };
  };
}

# my/users/environment-defaults.nix (Separate defaults module)
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.my.users != {}) {
    my.users = lib.mapAttrs (name: userCfg: {
      environment = {
        BROWSER = lib.mkDefault pkgs.brave;  # ← Set opinionated defaults here
        TERMINAL = lib.mkDefault pkgs.wezterm;
        EDITOR = lib.mkDefault pkgs.helix;
      };
    }) config.my.users;
  };
}
```

**Why:** Option definitions cannot reference `pkgs` as it creates infinite recursion. Options define the schema; implementation modules set the values.

**Pattern:** Use null defaults in options, create separate `*-defaults.nix` module for opinionated defaults.

### ❌ ANTI-PATTERN: lib.mkMerge in top-level options declaration

**WRONG:**
```nix
# flake.nix (WRONG!)
{
  imports = lib.mkMerge [  # ← WRONG! Don't wrap imports in mkMerge
    ({ ... }: { options.my = import ./options/system.nix { inherit lib; }; })
    ({ ... }: { options.my = import ./options/users.nix { inherit lib; }; })
  ];
}
```

**CORRECT:**
```nix
# flake.nix (CORRECT!)
{
  imports = [  # ← CORRECT! imports is already a list merger
    ({ ... }: { options.my = import ./options/system.nix { inherit lib; }; })
    ({ ... }: { options.my = import ./options/users.nix { inherit lib; }; })
  ];
}
```

**Why:** The `imports` attribute already merges modules. Using `lib.mkMerge` here is redundant and confusing.

**When to use mkMerge:** Only use `lib.mkMerge` when conditionally merging config values, not for imports.

### ✅ PATTERN: mkDefault in app modules for user overrides

**CORRECT:**
```nix
# my/users/apps/browsers/brave.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.my.users != {}) {
    home-manager.users = lib.mapAttrs
      (name: userCfg:
        let
          browserCfg = userCfg.environment.BROWSER or null;
          isBrave = browserCfg != null && browserCfg.package == pkgs.brave;
        in
        lib.mkIf (userCfg.graphical.enable && isBrave) {
          programs.brave = lib.mkDefault {  # ← CORRECT! Use mkDefault
            enable = true;
          };
        }
      )
      config.my.users;
  };
}

# my/users/apps/multiplexers/tmux.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.my.users != {}) {
    home-manager.users = lib.mapAttrs
      (name: userCfg:
        let
          multiplexerCfg = userCfg.environment.multiplexer or null;
          isTmux = multiplexerCfg != null && multiplexerCfg.package == pkgs.tmux;
        in
        lib.mkIf isTmux {
          programs.tmux.enable = lib.mkDefault true;  # ← mkDefault allows user override
        }
      )
      config.my.users;
  };
}
```

**Why:** User preferences in `my.users.<name>.environment.*` must override app module settings. Priority system:
- `mkForce`: 50 (highest, overrides everything)
- Regular assignment: 100 (framework/app modules)
- `mkDefault`: 1000 (user can override)

**Pattern:** App modules should use `mkDefault` so user-level config (priority 100) takes precedence.

### ✅ PATTERN: Safe attribute access with `or null`

**CORRECT:**
```nix
# In app modules or validation modules
{ config, lib, ... }:
let
  # Safe access - returns null if attribute doesn't exist
  browserCfg = userCfg.environment.BROWSER or null;
  terminalCfg = userCfg.environment.TERMINAL or null;

  # Safe boolean checks
  hasBrowser = browserCfg != null;
  isBrave = browserCfg != null && browserCfg.package == pkgs.brave;
in
{
  # Use in assertions
  assertions = [
    {
      assertion = hasBrowser -> browserCfg.package != null;
      message = "Browser configuration must have a package";
    }
  ];
}
```

**Why:** Prevents evaluation errors when optional attributes don't exist. Always use `or null` when accessing user options that may not be set.

## Architecture Decision Framework

### When designing new namespaces:

1. **Check existing patterns FIRST**
   - Search for similar features: `grep -r "mkOption" options/`
   - Find reference files that work
   - Compare proposed pattern with working examples

2. **Validate pattern before implementing**
   - Spawn explorer agent to find reference implementations
   - Test pattern with small example
   - Run `nix flake check` after each change

3. **Separate concerns**
   - Options define schema (options/*.nix) - NO pkgs, NO defaults
   - Defaults set values (my/*/defaults.nix) - Uses pkgs, uses mkDefault
   - Implementation uses config (my/*/*.nix) - Actual module logic

4. **Use proper priorities**
   - Options: `default = null` (schema only)
   - Defaults modules: `mkDefault value` (user can override)
   - App modules: `mkDefault { ... }` (user can override)
   - User config: Regular assignment (overrides defaults)

5. **Incremental changes**
   - One architectural change at a time
   - Validate after each step
   - Don't batch unrelated changes

## File Organization Patterns

### Options Files (Schema Definition)

**Location:** `/home/logger/Code/github/logger/mynixos/options/`

**Purpose:** Define option schemas only, no implementation

**Pattern:**
```nix
# options/users/FEATURE.nix
{ lib, ... }:  # NO pkgs!
{
  FEATURE = lib.mkOption {
    description = "...";
    default = { };  # or null for optional features
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "...";
        };
        # More options...
      };
    };
  };
}
```

**Imported in:** Submodule's imports array (NO `options.` prefix)

### Implementation Modules

**Location:** `/home/logger/Code/github/logger/mynixos/my/FEATURE/`

**Purpose:** Implement functionality based on options

**Pattern:**
```nix
# my/FEATURE/feature.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.my.FEATURE;
in
{
  config = lib.mkIf cfg.enable {
    # Implementation here
  };
}
```

### Defaults Modules

**Location:** `/home/logger/Code/github/logger/mynixos/my/FEATURE/defaults.nix`

**Purpose:** Set opinionated defaults using mkDefault

**Pattern:**
```nix
# my/users/environment-defaults.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.my.users != {}) {
    my.users = lib.mapAttrs (name: userCfg: {
      environment = {
        BROWSER = lib.mkDefault pkgs.brave;
        EDITOR = lib.mkDefault pkgs.helix;
      };
    }) config.my.users;
  };
}
```

### App Modules

**Location:** `/home/logger/Code/github/logger/mynixos/my/users/apps/CATEGORY/APP.nix`

**Purpose:** Configure specific applications based on user environment choices

**Pattern:**
```nix
# my/users/apps/browsers/brave.nix
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.my.users != {}) {
    home-manager.users = lib.mapAttrs
      (name: userCfg:
        let
          browserCfg = userCfg.environment.BROWSER or null;
          isBrave = browserCfg != null && browserCfg.package == pkgs.brave;
        in
        lib.mkIf (userCfg.graphical.enable && isBrave) {
          programs.brave = lib.mkDefault {  # ← mkDefault for overridability
            enable = true;
            # App-specific config
          };
        }
      )
      config.my.users;
  };
}
```

## Validation Workflow

### Before Implementation:

1. ✅ Find 2-3 reference files with similar patterns
2. ✅ Compare proposed approach with working examples
3. ✅ Identify differences and understand why
4. ✅ Test pattern in small scope first
5. ✅ Run `nix flake check` after each change

### During Implementation:

1. ✅ One file at a time
2. ✅ Check syntax after each edit
3. ✅ Build test after each logical change
4. ✅ Don't batch unrelated changes

### After Implementation:

1. ✅ Build both systems (yoga and skyspy-dev)
2. ✅ Run `nix flake check`
3. ✅ Validate derived flags work correctly
4. ✅ Check for regressions

## Common Mistakes to Avoid

1. ❌ Adding `options.` prefix to submodule import files
2. ❌ Using `pkgs` in option defaults
3. ❌ Wrapping `imports` in `lib.mkMerge`
4. ❌ Using regular assignment in app modules (prevents user overrides)
5. ❌ Not using `or null` for safe attribute access
6. ❌ Batching multiple architectural changes together
7. ❌ Implementing without checking reference files first
8. ❌ Not validating after each incremental change

## Reference Files (Known Good Patterns)

### Submodule Option Definition:
- `/home/logger/Code/github/logger/mynixos/options/users/graphical.nix` ✅
- `/home/logger/Code/github/logger/mynixos/options/users/environment.nix` ✅
- `/home/logger/Code/github/logger/mynixos/options/users/terminal.nix` ✅

### App Module Pattern:
- `/home/logger/Code/github/logger/mynixos/my/users/apps/browsers/brave.nix` ✅
- `/home/logger/Code/github/logger/mynixos/my/users/apps/multiplexers/tmux.nix` ✅
- `/home/logger/Code/github/logger/mynixos/my/users/apps/terminals/wezterm.nix` ✅

### Defaults Module Pattern:
- `/home/logger/Code/github/logger/mynixos/my/users/environment-defaults.nix` ✅

## Decision Making

When uncertain about a pattern:

1. **Search for existing usage** - `grep -r "pattern" .`
2. **Find reference implementations** - Spawn explorer agent
3. **Ask with examples** - Present both approaches to user
4. **Document decision** - Add to decision-log.jsonl
5. **Test before full implementation** - Validate pattern works

## Error Cost Awareness

Every wrong pattern decision has costs:
- Development time (multiple reversals)
- Cascading errors (one wrong pattern breaks multiple things)
- User frustration ("this was messy")
- Lost confidence in system

**Prevention > Correction:** Always validate patterns BEFORE implementing.
