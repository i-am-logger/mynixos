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

## Self-Improvement Proposals

### 2024-12-06: Design Checklist Enhancement
- **Motivation**: Prevent missing existing patterns
- **Proposed Change**: Add pre-design phase:
  1. Search for current usage of affected namespaces
  2. Review ARCHITECTURE.md for existing patterns
  3. Check for similar patterns in other modules
- **Expected Impact**: Fewer clarification rounds, better initial designs
- **Status**: Approved - Implementing

## Metrics

### Task Stats
- **Tasks Completed**: 1 (architecture refactor)
- **Success Rate**: 100%
- **Patterns Identified**: 2
- **Design Iterations**: 2 (initial + nesting clarification)