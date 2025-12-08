# Pattern Validation Checklist

## Critical Lesson Learned

**Session**: Environment migration (browsers → BROWSER)
**Failure**: Wrong pattern recommended, implemented 3 times, 5 commits with reversals
**Cost**: Multiple cascading errors, user frustration ("this was messy")
**Prevention**: This checklist

---

## For Architects: BEFORE Designing

### 1. Load Context
- [ ] Read `.claude/ARCHITECTURE.md` anti-patterns section
- [ ] Review decision log for related patterns: `grep -i "pattern" .claude/learning/decision-log.jsonl`
- [ ] Check if similar design exists in codebase

### 2. Find Reference Implementations
- [ ] **MANDATORY**: Spawn explorer OR manually find 2-3 working reference files
- [ ] For option files: Check existing files in `options/` directory
- [ ] For submodule imports: Find files already imported in similar contexts
- [ ] For app modules: Check `my/users/apps/` for proven patterns

### 3. Compare Pattern
- [ ] Does proposed pattern match reference files EXACTLY?
- [ ] If different: Document WHY deviation is necessary
- [ ] If using new pattern: Validate with small test first

### 4. Anti-Pattern Check
- [ ] NOT adding `options.` to submodule import files?
- [ ] NOT using `pkgs` in option defaults?
- [ ] NOT wrapping `imports` in `lib.mkMerge`?
- [ ] NOT using regular assignment in app modules (use mkDefault)?
- [ ] Using `or null` for safe attribute access?

### 5. Document Design
- [ ] Specify exact file patterns to use
- [ ] Include reference file examples
- [ ] Note any deviations from references with justification
- [ ] Define migration steps if breaking change

### Example Reference Files to Check

**Submodule option files (NO options. prefix):**
- `options/users/graphical.nix` ✅
- `options/users/environment.nix` ✅
- `options/users/terminal.nix` ✅

**App modules (use mkDefault):**
- `my/users/apps/browsers/brave.nix` ✅
- `my/users/apps/multiplexers/tmux.nix` ✅

**Defaults modules:**
- `my/users/environment-defaults.nix` ✅

---

## For Engineers: BEFORE Implementing

### 1. Validate Specification
- [ ] Read `.claude/ARCHITECTURE.md` anti-patterns section FIRST
- [ ] Check architect's spec includes reference file examples
- [ ] If no references provided: Find them yourself OR ask architect

### 2. Find Reference Files
- [ ] Locate 2-3 files with similar structure
- [ ] Compare architect's pattern with reference implementations
- [ ] If patterns differ: Ask architect to clarify/justify

### 3. Pattern Confirmation
- [ ] Pattern matches reference files? ✅ Proceed
- [ ] Pattern differs from references? ⚠️ STOP - Ask architect
- [ ] Uncertain about pattern? ⚠️ STOP - Find more references

### 4. Implementation Plan
- [ ] List ALL files to modify
- [ ] Plan order (dependencies first)
- [ ] ONE architectural change per implementation
- [ ] NOT batching unrelated changes

### 5. Incremental Validation
- [ ] Modify ONE file
- [ ] Check syntax: `nix-instantiate --parse file.nix`
- [ ] Run `nix flake check` (if fast enough)
- [ ] Commit if check passes
- [ ] Move to next file

### 6. Anti-Pattern Prevention
- [ ] NOT adding `options.` wrapper to submodule import files?
- [ ] NOT using `pkgs` in option defaults?
- [ ] Using `mkDefault` in app modules?
- [ ] Using `or null` for safe access?

---

## For Validators: BEFORE Approving

### 1. Pattern Review
- [ ] Compare implementation with reference files
- [ ] Check for anti-patterns from ARCHITECTURE.md
- [ ] Verify incremental commits (not one big batch)

### 2. Build Validation
- [ ] Both systems build: yoga and skyspy-dev
- [ ] `nix flake check` passes
- [ ] No new warnings

### 3. Regression Check
- [ ] Derived flags work correctly
- [ ] User overrides still function
- [ ] No performance degradation

---

## For Orchestrators: Task Planning

### 1. Identify Task Type
- [ ] Is this an architectural change? → Add pattern validation step
- [ ] Is this a new pattern? → Spawn explorer FIRST
- [ ] Is this proven pattern? → Proceed with standard workflow

### 2. Pattern Validation Step
If architectural change:
- [ ] Spawn explorer to find reference files
- [ ] Have architect compare proposed vs reference
- [ ] Document pattern validation in task plan
- [ ] ONLY THEN spawn engineer

### 3. Prevent Batching
- [ ] One architectural change per task
- [ ] Separate concerns into different tasks
- [ ] Incremental validation between tasks

---

## Red Flags (STOP and Validate)

### For Architects:
🚩 Recommending pattern without checking reference files
🚩 Proposing pattern different from existing code without justification
🚩 Not specifying exact file structure/syntax
🚩 Skipping anti-pattern check

### For Engineers:
🚩 Implementing without finding reference files
🚩 Pattern differs from references but proceeding anyway
🚩 Batching multiple unrelated changes
🚩 Skipping incremental validation

### For Validators:
🚩 Implementation doesn't match any reference files
🚩 Multiple architectural changes in one commit
🚩 Anti-patterns present in code
🚩 Build errors or warnings

---

## Success Criteria

Pattern validation is working when:
- ✅ Architect ALWAYS finds reference files before designing
- ✅ Engineer ALWAYS verifies pattern before implementing
- ✅ Zero wrong pattern implementations
- ✅ No trial-and-error approach
- ✅ First implementation is correct
- ✅ User sees clean, professional execution

---

## Metrics to Track

After each architectural change:
- **Reference files found**: How many? (Minimum: 2)
- **Pattern validated**: Yes/No
- **Deviations from reference**: How many? Why?
- **Implementation attempts**: Should be 1 (not 3!)
- **Commits needed**: Fewer commits = better planning
- **User feedback**: "Clean" vs "Messy"

---

## Remember

**The environment migration failure cost:**
- 5 commits with multiple reversals
- Cascading errors (lib.mkMerge, pkgs, apps, tmux)
- User frustration
- Lost trust in system

**Prevention is cheaper than correction.**
**Validation takes 5 minutes.**
**Trial-and-error takes hours.**

**ALWAYS validate patterns BEFORE implementing.**
