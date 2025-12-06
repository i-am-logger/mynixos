# mynixos Pattern Library

## Architectural Patterns

### Derived System Flags Pattern

**Intent**: Aggregate user-level feature enablement into system-level flags without violating architecture boundaries.

**Problem**: Modules need to know if features are enabled system-wide, but checking user properties directly creates tight coupling and violates architectural boundaries.

**Solution Structure**:

```nix
# 1. In flake.nix - Define read-only system flag
my.feature.enable = mkOption {
  type = types.bool;
  default = false;
  readOnly = true;  # Critical: prevent manual override
  description = "Whether any user has feature enabled";
};

# 2. In feature module - Set and use derived flag
config = mkMerge [
  # Block 1: Derive flag from user properties
  {
    my.feature.enable = lib.any (u: u.feature.enable or false)
                        (attrValues config.my.users);
  }

  # Block 2: Use the derived flag
  (mkIf config.my.feature.enable {
    # Feature implementation
  })
];

# 3. In other modules - Check system flag only
mkIf config.my.feature.enable {
  # Related configuration
}
```

**Benefits**:
- Single source of truth (user properties)
- Clean architecture boundaries
- No circular dependencies
- Automatic propagation

**Known Uses**:
- my.graphical.enable
- my.dev.enable
- my.streaming.enable

**Anti-pattern to Avoid**:
```nix
# BAD - Direct user property checking
mkIf (lib.any (u: u.streaming) (attrValues config.my.users))

# GOOD - Use derived flag
mkIf config.my.streaming.enable
```

---

### Feature Nesting Pattern

**Intent**: Organize user options hierarchically based on dependencies and relationships.

**Problem**: Flat namespace doesn't express dependencies between features.

**Solution**: Nest dependent features under their requirements.

**Decision Matrix**:

| Nest B under A when: | Keep B top-level when: |
|---------------------|----------------------|
| B requires A to function | B works independently |
| B is a specialization of A | B and A serve different purposes |
| Disabling A should disable B | Users might want B without A |
| A and B share configuration scope | Different combinations needed |

**Examples**:

```nix
# NESTED - Streaming requires graphical environment
my.users.logger.graphical.streaming.enable = true;

# TOP-LEVEL - Development doesn't require graphical
my.users.logger.dev.enable = true;

# NESTED - Wallpaper is part of graphical setup
my.users.logger.graphical.wallpaper = "/path/to/image";

# TOP-LEVEL - AI can run headless
my.users.logger.ai.enable = true;
```

---

### mkMerge Separation Pattern

**Intent**: Separate value computation from value usage in the same module.

**Problem**: Setting and using a value in the same config block causes infinite recursion.

**Solution**: Use mkMerge with separate blocks.

```nix
config = mkMerge [
  # Block 1: Compute/set values
  {
    my.computed.value = someComputation;
  }

  # Block 2: Use computed values
  (mkIf config.my.computed.value {
    # Configuration that depends on computed value
  })
];
```

**Why It Works**: mkMerge evaluates blocks independently, avoiding recursion.

---

## Migration Patterns

### Comprehensive API Migration Pattern

**Intent**: Change an API across entire codebase without missing references.

**Problem**: API changes can leave orphaned references causing build failures.

**Solution Process**:

1. **Discovery Phase**:
```bash
# Find all current usage
rg "old.api.path" --type nix

# Find pattern variations
rg "old\.api\.\w+" --type nix

# Check both repos if split architecture
rg "old.api" /home/logger/Code/github/logger/mynixos
rg "old.api" /etc/nixos
```

2. **Planning Phase**:
- List all files needing changes
- Determine update order (dependencies first)
- Plan validation strategy

3. **Implementation Phase**:
- Update mynixos first (if split architecture)
- Update consumer configs second
- Use single commit per repository

4. **Validation Phase**:
```bash
# Build all affected systems
sudo nixos-rebuild build --flake .#system1
sudo nixos-rebuild build --flake .#system2

# Final verification
rg "old.api" --type nix  # Should return nothing
```

---

## Testing Patterns

### Multi-System Validation Pattern

**Intent**: Ensure changes work across all system configurations.

**Problem**: Changes might work on one system but break another.

**Solution**: Always validate all systems.

```bash
# Build without switching (safe)
sudo nixos-rebuild build --flake .#yoga
sudo nixos-rebuild build --flake .#skyspy-dev

# Test without bootloader changes (safer)
sudo nixos-rebuild test --flake .#yoga
sudo nixos-rebuild test --flake .#skyspy-dev

# Only switch after all systems validate
sudo nixos-rebuild switch --flake .#
```

---

## Search Patterns

### Architecture Violation Detection Pattern

**Intent**: Find modules that violate architectural boundaries.

**Common Violations to Search**:

```bash
# User property direct access
rg "any \(u: u\." modules/ --type nix

# Reaching into user namespace
rg "attrValues config\.my\.users" modules/ --type nix

# Checking specific users
rg "config\.my\.users\.\w+\." modules/ --type nix

# Manual feature detection
rg "mkIf.*any.*users" modules/ --type nix
```

---

## Documentation Patterns

### Pattern Documentation Template

When documenting a new pattern:

```markdown
### [Pattern Name]

**Intent**: [One sentence goal]

**Problem**: [What problem does this solve?]

**Solution**: [High-level approach]

**Structure**:
[Code example showing the pattern]

**Benefits**:
- [Benefit 1]
- [Benefit 2]

**Trade-offs**:
- [Trade-off 1]
- [Trade-off 2]

**Known Uses**:
- [Example 1]
- [Example 2]

**Related Patterns**:
- [Pattern 1]
- [Pattern 2]
```

---

## Meta Patterns

### Multi-Agent Coordination Pattern

**Intent**: Leverage specialized agents for complex refactors.

**Agent Roles**:
- **Architect**: Design patterns and architecture
- **Engineer**: Implement specific changes
- **Validator**: Verify correctness and completeness
- **Refactorer**: Handle migrations and updates

**Coordination Flow**:
1. Architect designs solution
2. Engineer implements design
3. Refactorer migrates existing code
4. Validator confirms success

**Success Factors**:
- Clear role boundaries
- Specific deliverables
- Incremental validation
- No scope creep

---

## Anti-Patterns to Avoid

### Direct User Property Access
**Don't**: Check user properties from system modules
**Do**: Use derived system flags

### Mutable System Flags
**Don't**: Allow manual override of derived flags
**Do**: Make derived flags readOnly

### Big Bang Refactors
**Don't**: Change everything at once
**Do**: Incremental migration with validation

### Assumption-Based Changes
**Don't**: Assume you know all usage
**Do**: Search comprehensively first

---

## Pattern Application Checklist

Before applying any pattern:

- [ ] Search for existing usage
- [ ] Review related patterns
- [ ] Check architecture guidelines
- [ ] Plan validation strategy
- [ ] Document decision rationale
- [ ] Update pattern library if new insight