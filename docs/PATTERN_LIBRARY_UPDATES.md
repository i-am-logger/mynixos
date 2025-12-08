# Proposed Pattern Library Updates

Based on the flake.nix migration analysis, these patterns should be added to `.claude/learning/pattern-library.md`:

## 1. Monolith Extraction Pattern

**Context:** Single file grown too large (>1000 lines) and becoming unmaintainable

**Problem:**
- Hard to navigate and find specific sections
- Merge conflicts frequent
- Multiple concerns mixed together
- Difficult for new contributors

**Solution:**
1. **Audit Phase:** Document current structure and identify logical boundaries
2. **Plan Phase:** Create migration plan with clear phases
3. **Fix First:** Address architectural issues before extraction
4. **Extract by Namespace:** Use namespace boundaries as file boundaries
5. **Compose Cleanly:** Use imports and lib.mkMerge for composition
6. **Validate Often:** Test after each extraction phase

**Example:**
```nix
# Before: flake.nix (2,018 lines)
options.my = {
  system = { ... };
  security = { ... };
  hardware = { ... };
  # ... hundreds more
};

# After: flake.nix (259 lines)
options.my = lib.mkMerge [
  (import ./options/system.nix { inherit lib pkgs; })
  (import ./options/security.nix { inherit lib; })
  (import ./options/hardware.nix { inherit lib; })
];
```

**When to Use:** File > 1000 lines OR > 10 distinct namespaces OR frequent merge conflicts

**Benefits:**
- 87% size reduction in main file
- Clear separation of concerns
- Parallel development without conflicts
- Easy to find and modify options

---

## 2. Namespace-to-File Mapping Pattern

**Context:** Organizing extracted configuration options

**Problem:**
- Unclear where to place new options
- Inconsistent file organization
- Deep nesting in single files

**Solution:**
```
options/
├── <namespace>.nix         # Top-level namespaces
├── users/                   # Nested namespace directory
│   ├── <sub-namespace>.nix # Sub-namespace files
│   └── apps.nix
└── lib/                     # Shared libraries
    └── app-options.nix
```

**Rules:**
1. One file per top-level namespace (my.system → system.nix)
2. Nested namespaces get subdirectories (my.users.* → users/*.nix)
3. File returns the namespace it defines
4. Shared patterns go in lib/

**Example:**
```nix
# options/system.nix defines my.system.*
{ lib, pkgs, ... }:
{
  system = lib.mkOption {
    type = lib.types.submodule {
      options = {
        hostname = lib.mkOption { ... };
        kernel = lib.mkOption { ... };
      };
    };
  };
}
```

**Benefits:**
- Predictable file locations
- Clear ownership boundaries
- Easy to add new namespaces
- Natural organization emerges

---

## 3. Breaking Change Management Pattern

**Context:** Making breaking API changes during unstable development

**Problem:**
- Users need to update configs
- Changes must be communicated clearly
- Migration path required

**Solution:**

1. **Use Conventional Commits:**
```bash
git commit -m "refactor!: Remove my.apps.* namespace

BREAKING CHANGE: my.apps.* has been removed
Migration: Use my.users.<name>.apps.* instead"
```

2. **Update CHANGELOG.md Immediately:**
```markdown
### Removed (BREAKING CHANGE)
- **Removed `my.apps.*` namespace** - Use `my.users.<name>.apps.*` instead
  - Migration: Change `my.apps.browsers.brave` to `my.users.<name>.apps.browsers.brave`
```

3. **Fix Dependent Code:** Update all modules in same commit

4. **Document Rationale:** Explain why the break improves the system

**When to Use:** API improvements that require user action

**Benefits:**
- Clear communication
- Easy migration path
- Traceable decisions
- Reduced user friction

---

## 4. Option Library Pattern

**Context:** Repeated option definition patterns

**Problem:**
- Boilerplate code duplication
- Inconsistent option definitions
- Maintenance overhead

**Solution:**

```nix
# lib/app-options.nix
{ lib }:
{
  mkAppOption = { name, default ? false, description }:
    lib.mkOption {
      type = lib.types.bool;
      inherit default;
      description = "${description}${
        if default then " (opinionated default: enabled)" else ""
      }";
    };

  mkAppEnableOption = description:
    lib.mkEnableOption description;
}

# Usage in options/users/apps.nix
let
  appLib = import ../../lib/app-options.nix { inherit lib; };
in
{
  browsers.brave = appLib.mkAppOption {
    name = "Brave";
    default = true;
    description = "Brave browser";
  };
}
```

**When to Use:**
- Same pattern appears 3+ times
- Consistent behavior needed
- Reducing boilerplate

**Benefits:**
- DRY principle
- Consistent behavior
- Easy to update all instances
- Self-documenting patterns

---

## 5. Submodule Import Composition Pattern

**Context:** Composing options from multiple files

**Problem:**
- How to merge options from multiple sources
- Maintaining clean import structure
- Avoiding infinite recursion

**Solution:**

```nix
# Main file using lib.mkMerge
options.my = lib.mkMerge [
  (import ./options/system.nix { inherit lib pkgs; })
  (import ./options/security.nix { inherit lib; })
  # ... more imports
];

# For nested submodules
options.my.users = lib.mkOption {
  type = lib.types.attrsOf (lib.types.submodule {
    imports = [
      ./options/users/base.nix
      ./options/users/apps.nix
      # ... submodule imports
    ];
  });
};
```

**Key Points:**
- Use lib.mkMerge for top-level composition
- Use imports array for submodule composition
- Pass only required arguments (lib, pkgs)
- Each file is self-contained

**Benefits:**
- Clean separation
- No circular dependencies
- Easy to add/remove components
- Clear data flow

---

## 6. Migration Workflow Pattern

**Context:** Large-scale refactoring projects

**Problem:**
- Complex changes need structure
- Risk of breaking systems
- Need for feedback loops

**Solution:**

```markdown
## Phase Workflow
1. [ ] Create migration plan with clear phases
2. [ ] Get architect approval on approach
3. [ ] Execute phase
4. [ ] Validate with tests
5. [ ] Architect review of structure
6. [ ] Meta-learner synthesis
7. [ ] Incorporate feedback
8. [ ] Proceed to next phase

## Validation Checklist
- [ ] nix flake check passes
- [ ] All systems build
- [ ] Tests pass
- [ ] No regressions
- [ ] Documentation updated
```

**Key Elements:**
- Phases with clear boundaries
- Validation between phases
- Feedback loops
- Rollback points

**Benefits:**
- Controlled risk
- Continuous learning
- Quality gates
- Clear progress

---

## Pattern Detection Heuristics

Based on this migration, patterns emerge when:

1. **Repetition Threshold:** Same code structure appears 3+ times
2. **Complexity Threshold:** Single file > 500 lines of similar options
3. **Maintenance Pain:** Frequent conflicts or confusion
4. **Architectural Smell:** Unclear ownership or boundaries

## Meta-Pattern: Pattern Extraction

The migration itself demonstrates pattern extraction:
1. Identify repetition during implementation
2. Document pattern informally first
3. Extract to library when pattern stabilizes
4. Apply retroactively for consistency
5. Document in pattern library for reuse

---

**Note:** These patterns should be integrated into the existing pattern library with proper formatting and cross-references.