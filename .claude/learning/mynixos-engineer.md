# mynixos-engineer Learning Journal

## CRITICAL Failures (Never Repeat)

### 2025-12-06: Environment Migration - Implemented Wrong Pattern 3 Times
- **Situation**: Architect recommended adding `options.` prefix to submodule imports
- **Action**: Implemented blindly without checking reference files first
- **Outcome**: ❌ FAILED - Added/removed options wrapper 3 times, 5 commits with reversals
- **Root Cause**: Trusted architect recommendation without independent verification
- **Learning**: ALWAYS find and check reference files BEFORE implementing architectural patterns
- **Error Cost**: 5 commits, multiple cascading fixes (lib.mkMerge, pkgs in options, app references, tmux)
- **Prevention**: Added MANDATORY reference file verification step to workflow
- **Action Item**: Check .claude/ARCHITECTURE.md anti-patterns before implementing
- **Confidence**: 1.0 - Will NEVER implement without validation again

### 2025-12-06: Multiple Pattern Changes Batched Together
- **Situation**: Changed options. prefix + pkgs defaults + app references in same batch
- **Action**: Made multiple unrelated changes simultaneously
- **Outcome**: ❌ FAILED - Cascading errors, hard to identify root cause
- **Root Cause**: Didn't follow incremental change discipline
- **Learning**: ONE architectural change at a time, validate after each
- **Prevention**: Incremental validation checkpoint added to workflow
- **Confidence**: 0.95

## Successes (What Works Well)

### 2024-12-06: Implementing Derived Flags Pattern
- **Situation**: Need to add system-level flags without breaking existing code
- **Action**: Used mkMerge to cleanly separate flag setting from usage
- **Outcome**: ✅ Clean implementation, no circular dependencies
- **Learning**: mkMerge is perfect for separating concerns in config blocks
- **Confidence**: High

### 2024-12-06: Comprehensive Migration
- **Situation**: API change affected multiple files across two repos
- **Action**: Systematic search with grep, update all references in one pass
- **Outcome**: ✅ No missed references, both systems built successfully
- **Learning**: grep/rg is essential for finding all usage before changing APIs
- **Confidence**: High

### 2025-12-06: Media and Terminal Feature Modules Implementation
- **Situation**: Implement two new user-level feature categories based on architect spec
- **Action**: Created media.nix (graphical nesting) and terminal.nix (top-level), followed opinionated defaults pattern
- **Outcome**: ✅ Both modules built correctly, no validation issues
- **Learning**: Nesting design validated - media (gui) naturally belongs under graphical
- **Confidence**: Very High (0.95)

## Patterns Discovered

### mkMerge for Separation of Concerns
- **Description**: Use mkMerge to separate flag computation from flag usage
- **Works When**: Need to set a value and use it in same module
- **Fails When**: Trying to do both in same config block (causes recursion)
- **Best Practice**: First block sets flags, second block uses them
- **Examples**: Setting my.feature.enable then using it in mkIf

### Comprehensive Search Before API Changes
- **Description**: Always search for all usages before changing an API
- **Works When**: Using grep/rg with proper patterns
- **Fails When**: Assuming you know all usage locations
- **Best Practice**: `rg "pattern" --type nix` across entire codebase
- **Examples**: Found all my.users.<name>.streaming references

## Improvements (What Needs Work)

### 2024-12-06: Initial Misunderstanding of Requirements
- **Situation**: Thought "nest streaming" meant file structure
- **Issue**: Started moving files instead of changing namespace
- **Root Cause**: Didn't distinguish between namespace and file organization
- **Learning**: Clarify data structure vs file structure before implementing
- **Action Item**: Ask for examples when requirements are ambiguous

## Feedback Received

### 2024-12-06: From Meta-Learner
- **Context**: Architecture refactor implementation
- **Feedback**: Good use of mkMerge pattern, systematic search approach was correct
- **Action Taken**: Documented pattern for future use
- **Outcome**: Pattern now available for similar refactors

## Self-Improvement Proposals

### 2024-12-06: Pre-Implementation Checklist
- **Motivation**: Avoid misunderstanding requirements
- **Proposed Change**: Before implementing:
  1. Clarify namespace vs file structure changes
  2. Search for existing usage
  3. Identify all affected files
  4. Plan migration order
- **Expected Impact**: Fewer false starts, cleaner implementations
- **Status**: Approved - Implemented

### 2025-12-06: MANDATORY Pattern Verification Protocol
- **Motivation**: Prevent implementing wrong architectural patterns
- **Proposed Change**: ENFORCE verification before implementation:
  1. **BEFORE coding**: Read .claude/ARCHITECTURE.md anti-patterns section
  2. **FIND references**: Locate 2-3 working files with similar pattern
  3. **COMPARE**: Does architect's spec match reference implementations?
  4. **IF DIFFERENT**: Ask architect to clarify/justify deviation
  5. **VALIDATE**: Run incremental check after EACH file change
  6. **ONE CHANGE**: Only one architectural pattern change per commit
- **Expected Impact**: Zero wrong pattern implementations, faster completion
- **Status**: MANDATORY - Implemented in workflow

## Metrics

### Task Stats
- **Tasks Completed**: 1 (refactor implementation)
- **Success Rate**: 100%
- **Files Modified**: 8
- **Patterns Applied**: 2 (mkMerge, comprehensive search)
- **Build Validations**: 2 (yoga, skyspy-dev)