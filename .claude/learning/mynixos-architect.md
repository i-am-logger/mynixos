# mynixos-architect Learning Journal

## Successes (What Works Well)

### 2024-12-06: Derived System Flags Pattern
- **Situation**: Modules were checking user properties directly, violating architecture boundaries
- **Action**: Designed pattern where system flags derive from user properties
- **Outcome**: ✅ Clean architecture, no circular dependencies, all violations fixed
- **Learning**: Read-only derived flags maintain single source of truth while providing system-wide visibility
- **Confidence**: High

### 2024-12-06: Feature Nesting Decision Framework
- **Situation**: Unclear whether streaming should be top-level or nested under graphical
- **Action**: Created decision matrix - nest when B requires A, keep separate when independent
- **Outcome**: ✅ Clear, logical API structure that reflects dependencies
- **Learning**: Physical dependencies should be reflected in namespace structure
- **Confidence**: High

### 2025-12-06: Media and Terminal API Design
- **Situation**: Design API for new user feature categories (media apps and terminal tools)
- **Action**: Nested media under graphical, kept terminal top-level
- **Outcome**: ✅ Implementation successful with no issues, both systems build, validator found only pre-existing issues
- **Learning**: Media nesting principle validated - apps that require GUI belong under graphical
- **Confidence**: Very High (0.95)

## Patterns Discovered

### Derived System Flags
- **Description**: System-level read-only flags that aggregate user properties
- **Works When**: Modules need to know if any user has feature enabled
- **Fails When**: Flags are writable (causes confusion about source of truth)
- **Best Practice**: Use mkMerge to separate flag setting from flag usage
- **Examples**: my.graphical.enable, my.dev.enable, my.streaming.enable

### Architecture Boundary Enforcement
- **Description**: Modules should never directly check user properties
- **Works When**: Using derived system flags as intermediary
- **Fails When**: Modules reach into my.users namespace
- **Best Practice**: Define system flags in flake.nix, set in feature module
- **Examples**: Impermanence checking my.graphical.enable instead of user properties

## Improvements (What Needs Work)

### 2024-12-06: Initial Context Gathering
- **Situation**: Started designing without reviewing existing patterns
- **Issue**: Missed that streaming was already in use, caused confusion
- **Root Cause**: Didn't search codebase for current usage first
- **Learning**: Always grep for existing patterns before designing changes
- **Action Item**: Add "search for current usage" to design checklist

### 2025-12-06: CRITICAL FAILURE - Environment Migration Pattern Error
- **Situation**: Recommended adding `options.` prefix to submodule import files
- **Issue**: WRONG PATTERN - caused 5 commits with 3 reversals, cascading errors
- **Root Cause**: Did NOT validate pattern against reference files before recommending
- **Learning**: ALWAYS spawn explorer to find working reference files BEFORE designing
- **Error Cost**: 5 commits, multiple cascading fixes (lib.mkMerge, pkgs in options, app references, tmux conflicts)
- **Action Item**: MANDATORY pattern validation step added to workflow
- **Confidence After**: 1.0 - This mistake will NEVER repeat

## Self-Improvement Proposals

### 2024-12-06: Design Checklist Enhancement
- **Motivation**: Prevent missing existing patterns
- **Proposed Change**: Add pre-design phase:
  1. Search for current usage of affected namespaces
  2. Review ARCHITECTURE.md for existing patterns
  3. Check for similar patterns in other modules
- **Expected Impact**: Fewer clarification rounds, better initial designs
- **Status**: Approved - Implemented

### 2025-12-06: MANDATORY Pattern Validation Protocol
- **Motivation**: Prevent catastrophic pattern errors like environment migration
- **Proposed Change**: ENFORCE pattern validation workflow:
  1. **BEFORE designing**: Spawn explorer agent to find 2-3 reference files
  2. **COMPARE**: Proposed pattern vs working reference implementations
  3. **VALIDATE**: If different from reference, document WHY and get confirmation
  4. **CHECK**: Review .claude/ARCHITECTURE.md for anti-patterns
  5. **NEVER**: Recommend patterns without reference file validation
- **Expected Impact**: Zero wrong pattern recommendations, eliminate trial-and-error
- **Status**: MANDATORY - Implemented in workflow, added to ARCHITECTURE.md

## Critical Failure: 2025-12-07 Environment Migration Validation Gap

### Situation
Hyprland migration was approved without validating:
1. Breaking changes from Hyprland 0.50 → 0.51
2. Environment API pattern consistency across modules
3. User preference preservation
4. Generated config file validity

### What Went Wrong
- **Approved changes without reviewing:**
  - Hyprland options for deprecated settings
  - Other modules for duplicate app selection logic (defaultBrowser/defaultTerminal)
  - User preference migration strategy

- **Validation gaps that must be closed:**
  - No check: Did generated hyprland.conf match current Hyprland version?
  - No check: Are all modules using environment API or duplicating logic?
  - No check: Are user preferences preserved after structural changes?
  - No check: Did reviewer actually validate or just trust reports?

### Root Causes
1. **Didn't check for breaking changes in dependency CLOGs** when Hyprland updated
2. **Didn't audit for environment API consistency** before approving changes
3. **Didn't require reference file validation** for architectural patterns
4. **Didn't validate generated config files** (only validated compilation)

### Learning: Approval Checklist Gaps

**Before approving ANY changes, architect MUST:**

1. **Dependency Breaking Changes Check**
   ```bash
   # For each dependency that might have broken changes:
   grep -r "0.5[0-9]" flake.nix  # Find versions
   # Check: Is there a published CHANGELOG?
   # Question: Any deprecated config options?
   # Validation: Will generated configs still work?
   ```

2. **API Pattern Consistency Audit**
   ```bash
   # If changes touch app selection:
   grep -r "defaultBrowser\|defaultTerminal\|BROWSER\|TERMINAL" my/
   # Verify: Are ALL references using environment API?
   # Verify: NO duplicates of app selection logic?
   # Verify: Single source of truth?
   ```

3. **User Preference Preservation Check**
   ```bash
   # If structural changes affect user config:
   # Question: Where are user prefs stored NOW?
   # Question: Where will they be stored AFTER?
   # Verification: Migration plan exists?
   # Verification: Old location is removed?
   ```

4. **Generated File Validation Plan**
   ```bash
   # If module generates configuration files:
   # Question: How to validate generated output?
   # Question: Can generated output be tested?
   # Validation: Plan documented before approval?
   ```

### New Approval Process

```markdown
## Architecture Review Checklist (MANDATORY)

Before approving changes:

### Pre-Approval Phase
- [ ] Read proposed changes completely
- [ ] Understand: What is breaking and what is not
- [ ] Check: Are there dependency breaking changes?
- [ ] Check: Do changes affect API patterns?
- [ ] Check: Do changes affect user data?
- [ ] Check: Do changes affect config generation?
- [ ] Research: For each "yes" above, find validation strategy

### Validation Strategy Phase
- [ ] Breaking changes: Plan how to detect them
- [ ] API patterns: Plan how to verify consistency
- [ ] User data: Plan how to verify preservation
- [ ] Config generation: Plan how to validate output

### Approval Phase
- [ ] Document exact concerns identified
- [ ] Require validator to address each concern
- [ ] Require specific validation commands (not "just validate")
- [ ] Require baseline test before approving
- [ ] After changes: Personally verify key validators ran

### Post-Approval Verification
- [ ] Did validator check what I asked them to check?
- [ ] Are there any warnings in build output?
- [ ] Did validator compare against baseline?
- [ ] Are generated configs actually valid?
```

### Impact

**Changes** to architect workflow:
1. MANDATORY dependency changelog review for version bumps
2. MANDATORY audit of API patterns when changes touch config generation
3. MANDATORY user data migration plan when structure changes
4. MANDATORY generated file validation strategy before approval
5. MANDATORY personal spot-checking of validator results

**Confidence in Prevention**:
- Will catch Hyprland breaking changes: 0.95
- Will catch environment API mismatches: 0.9
- Will catch user preference loss: 0.85
- Will prevent "false success" approval: 0.8

---

## Metrics

### Task Stats
- **Tasks Completed**: 1 (architecture refactor) + 1 (failure post-mortem)
- **Success Rate**: 50% (1 success, 1 critical failure)
- **Patterns Identified**: 5 (including 1 anti-pattern from failure)
- **Design Iterations**: 2 (initial + nesting clarification)
- **Critical Learnings**: 6 (from failure analysis)
- **Approval Process Updates**: Major (added validation checklist)