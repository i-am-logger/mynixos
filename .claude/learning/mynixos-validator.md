# mynixos-validator Learning Journal

## Session: 2025-12-07 Critical Failure Post-Mortem

### Lesson 1: Breaking Changes Require Config Validation

**Situation**: NixOS 25.11 → 26.05 upgrade brought Hyprland 0.50 → 0.51 breaking changes.

**What Was Done**:
- Validator reported "clean build"
- Used `nix build .#nixosConfigurations.yoga.config.system.build.toplevel`
- Checked exit code: 0
- Declared success

**What Actually Happened**:
- Generated hyprland.conf had deprecated options (`blur` at top level, removed in 0.51)
- Hyprland daemon would reject config on boot
- System unbootable
- User required swift rollback

**Outcome**: ❌ Complete validation failure

**Learning**:
- Build success != System functionality success
- For modules that generate config files (Hyprland, home-manager, etc.), must validate generated output
- Need command: `hyprctl -c <generated-config> validate`

**Confidence Before**: 0.8 (thought nix build was sufficient)
**Confidence After**: 0.05 (lost faith in old validation approach)

**New Practice**: For Hyprland changes, always validate generated hyprland.conf
```bash
# After building, extract and validate:
nix build .#nixosConfigurations.yoga.config.home-manager.users.logger.configFile
hyprctl -c "$result/activate.sh" validate 2>&1 | grep -E "error:|warning:"
```

---

### Lesson 2: nix build vs nixos-rebuild build Are Different

**Situation**: Both "passed" validation but system was broken

**Discovery**:
- `nix build .#nixosConfigurations.yoga.config.system.build.toplevel` - PASSED
- `nixos-rebuild build --flake .#yoga` - WOULD HAVE FAILED

**Difference**:
- `nix build` evaluates lazily, may skip cross-module conflict detection
- `nixos-rebuild build` does full system evaluation including home-manager
- Tmux conflict (terminal.nix sets multiplexer to zellij, tmux.nix sets enable to true) only caught during nixos-rebuild

**Outcome**: ❌ Used inadequate validation command

**Learning**:
- ALWAYS validate with commands the user will actually run
- For NixOS systems: `nixos-rebuild build` is authoritative
- Never use nix build as sole validation
- Both commands must pass

**New Mandatory Practice**:
```bash
# ALWAYS validate with BOTH:
nixos-rebuild build --flake .#yoga 2>&1 | tee /tmp/yoga.log
RESULT=$?

if [ $RESULT -ne 0 ]; then
  echo "VALIDATION FAILED"
  grep -E "error:" /tmp/yoga.log
  exit 1
fi

# And verify semantically
if grep -q "error\|undefined variable" /tmp/yoga.log; then
  echo "Build warnings indicate errors"
  exit 1
fi
```

---

### Lesson 3: User Preferences Must Survive Migration

**Situation**: After changes, user's Hyprland preferences were lost

**Discovery**:
- User's `leftHanded = true` was in `/etc/nixos/home/input.nix` (old location)
- New structure uses `/etc/nixos/users/logger/default.nix`
- Old file wasn't migrated, wasn't even checked in validation
- User had to manually reconfigure after switch

**Outcome**: ❌ Data loss during structural change

**Learning**: When architecture changes, user data is at risk

**New Practice**: For changes involving user config structure:
```bash
# 1. Identify affected preferences
grep -r "leftHanded\|sensitivity\|BROWSER\|TERMINAL" /etc/nixos/

# 2. After changes, verify new locations have values:
nix eval '.#nixosConfigurations.yoga.config.my.users.logger.graphical.windowManager.hyprland' \
  | grep -E "leftHanded|sensitivity"

# 3. Test that preferences apply after build:
# (Would need actual boot to verify, but check configuration)
```

---

### Lesson 4: Environment API Pattern Consistency

**Situation**: Hyprland module wasn't using environment API for app selection

**Discovery**:
- Hyprland had: `defaultBrowser = pkgs.firefox` (hardcoded)
- But my.users.<name>.environment.BROWSER should be source of truth
- User's preferred BROWSER preference was ignored

**Outcome**: ❌ API pattern mismatch

**Learning**: When APIs evolve, all implementations must be audited

**New Practice**: Check for duplicate logic
```bash
# Find modules that define app defaults:
grep -r "defaultBrowser\|defaultTerminal\|defaultEditor" my/ options/

# Should only appear in:
# - comments/documentation
# - options file with "# TODO: migrate to environment API"
# - Never in implementation modules

# All implementations should use:
browser = userCfg.environment.BROWSER or pkgs.firefox;
```

---

## Validation Protocol v2.0 (After Learnings)

### Pre-Change Baseline (MANDATORY)

```bash
echo "=== BASELINE VALIDATION ==="
for system in yoga skyspy-dev; do
  echo "Testing $system..."
  if ! nixos-rebuild build --flake .#$system 2>/tmp/$system.baseline.log; then
    echo "WARNING: System $system already has build issues"
    grep -E "error:" /tmp/$system.baseline.log | head -5
  fi
done
```

### Post-Change Validation (MANDATORY)

```bash
echo "=== CHANGE VALIDATION ==="
for system in yoga skyspy-dev; do
  echo "Testing $system..."

  # Full build test
  if ! nixos-rebuild build --flake .#$system 2>/tmp/$system.test.log; then
    echo "FAILURE: $system build failed"
    grep -E "error:" /tmp/$system.test.log
    exit 1
  fi

  # Check for new errors
  if diff /tmp/$system.baseline.log /tmp/$system.test.log | grep "^<.*error"; then
    echo "FAILURE: New errors in $system"
    exit 1
  fi

  # For Hyprland changes, validate config
  # (This would need extraction of generated config path)
done

echo "SUCCESS: All systems build and no new errors"
```

### Success Criteria (MUST ALL PASS)

```
VALIDATION SUCCESS requires:
1. nixos-rebuild build exits 0 for ALL systems
2. No NEW errors introduced (diff against baseline)
3. No critical warnings that block boot
4. Generated config files are valid (hyprland.conf validates)
5. User preferences preserved (if applicable)
6. API patterns consistent (no duplicate defaults)

Report format:
- System: <name>
- Build Status: PASS/FAIL (exit code: X)
- New Errors: <count> (list first 3)
- New Warnings: <count> (list first 3)
- Config Validation: PASS/FAIL (for applicable modules)
- Patterns: CONSISTENT/ISSUES (list any found)
```

---

## Confidence Calculation

**Previous Method** (WRONG):
- Build succeeded → confidence 0.8
- No visible errors → confidence 0.9
- Result: Overconfident false positives

**New Method** (CORRECT):
```
Base score: 0.0

+0.25 if nixos-rebuild build passes
+0.15 if no new errors vs baseline
+0.10 if no new warnings
+0.15 if config files validate (if applicable)
+0.10 if user preferences preserved (if applicable)
+0.15 if pattern consistency verified
+0.10 if personally spot-checked output

Maximum achievable: 1.0
Maximum without full validation: 0.6
```

**Minimum Acceptable**: 0.7 to report "ready for switch"

---

## Files to Review for Validation Quality

1. **CRITICAL_FAILURE_ANALYSIS** in /etc/nixos/.claude/learning/
   - Detailed breakdown of what validation missed

2. **mynixos-architect.md** (this repo)
   - Design changes that require architectural validation

3. **pattern-validation-checklist.md** (this repo)
   - Architectural pattern review before approval

---

## Next Validation Task Checklist

Before validating ANY changes:

- [ ] Read CRITICAL_FAILURE_ANALYSIS to understand what we missed
- [ ] Understand: Does this change involve Hyprland? (Need config validation)
- [ ] Understand: Does this change involve user data? (Need migration audit)
- [ ] Understand: Does this change add/modify API? (Need pattern consistency check)
- [ ] Have plan for validating each concern
- [ ] Document exact commands being used
- [ ] Run baseline test BEFORE making changes
- [ ] Run full test suite AFTER changes
- [ ] Compare baseline and post-change logs
- [ ] Validate generated config files (if applicable)
- [ ] Report with exact metrics, not just "it works"

---

## Sessions Completed

- 2025-12-07: Critical failure post-mortem (6 major learnings captured)

## Patterns Discovered

### Pattern: Breaking Changes Need Multi-Level Validation
- Level 1: Build succeeds (nix/nixos-rebuild)
- Level 2: Config files are valid (hyprland, home-manager, etc.)
- Level 3: User data preserved (preferences, settings)
- Level 4: Patterns consistent (no duplicates, single source of truth)

All four levels must pass. Missing any one causes failure.
