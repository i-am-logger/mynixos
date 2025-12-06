# User Twin Agent Architecture

## Overview

The **user-twin** agent is a learning agent that builds a model of the user's preferences, patterns, and decision-making style. It acts as a proactive advisor to other agents, reducing the need for user questions by predicting preferences.

## Purpose

- **Learn user preferences** from interactions, decisions, and explicit statements
- **Predict user choices** before asking questions
- **Suggest to architect** proactively based on learned patterns
- **Interact with all agents** to guide decisions toward user's style
- **Evolve over time** as more data is collected
- **Reduce friction** by answering on user's behalf when confidence is high

## Learning Sources

### 1. Direct User Interactions
- Responses to `AskUserQuestion` tool
- Explicit preference statements ("I prefer X over Y")
- Code review comments and feedback
- Rejection or acceptance of suggestions

### 2. Implicit Patterns
- API design choices (nesting vs flat, naming conventions)
- Architecture decisions (where to place modules, how to structure)
- Code style (conciseness, verbosity, comments)
- Commit message patterns
- File organization preferences

### 3. Contextual Decisions
- Risk tolerance (breaking changes, backward compatibility)
- Technology preferences (which tools, libraries, approaches)
- Opinionated defaults vs explicit configuration
- Documentation style and depth

## Preference Model Structure

```json
{
  "user_id": "logger",
  "last_updated": "2025-12-06T...",
  "confidence_threshold": 0.8,

  "api_design": {
    "nesting_preference": {
      "pattern": "nest_dependent_features",
      "confidence": 0.95,
      "examples": [
        "streaming nested under graphical (requires graphical)",
        "user prefers my.users.<name>.graphical.streaming.enable"
      ],
      "learned_from": ["2025-12-06 streaming refactor"]
    },
    "enable_options": {
      "pattern": "always_have_enable_for_user_control",
      "confidence": 1.0,
      "examples": ["my.users.<name>.graphical.enable = true"],
      "learned_from": ["2025-12-06 user statement"]
    },
    "naming_convention": {
      "pattern": "descriptive_kebab_case",
      "confidence": 0.9,
      "examples": ["x870e-aorus-elite-wifi7", "legion-16irx8h"]
    }
  },

  "architecture": {
    "opinionated_defaults": {
      "preference": "strong",
      "confidence": 0.95,
      "rationale": "mynixos provides opinionated defaults, users override only when needed"
    },
    "backward_compatibility": {
      "preference": "low_priority_during_unstable",
      "confidence": 0.9,
      "rationale": "API is unstable, breaking changes acceptable"
    },
    "separation_of_concerns": {
      "preference": "strict",
      "confidence": 1.0,
      "rationale": "impermanence shouldn't check user properties directly"
    }
  },

  "technology": {
    "graphical_environment": "hyprland",
    "display_manager": "greetd",
    "container_runtime": "docker_rootless",
    "ai_backend": "ollama_rocm"
  },

  "communication": {
    "response_style": "concise",
    "emoji_usage": "minimal",
    "documentation_depth": "code_focused"
  },

  "risk_tolerance": {
    "breaking_changes": "acceptable_with_migration",
    "experimental_features": "willing",
    "system_rebuilds": "comfortable"
  }
}
```

## Interaction Protocol

### Phase 1: Initialization
```
Coordinator spawns user-twin (parallel with task analysis)
  ↓
Twin reads existing preference model
  ↓
Twin observes initial user request
  ↓
Twin identifies relevant preferences
```

### Phase 2: Proactive Suggestion
```
Coordinator prepares to spawn architect
  ↓
Coordinator queries twin: "What are user's preferences for this task?"
  ↓
Twin provides suggestions based on learned patterns
  ↓
Coordinator includes suggestions in architect prompt
```

### Phase 3: Agent Interaction
```
Any agent has decision point
  ↓
Agent queries twin: "User prefers X or Y?"
  ↓
Twin responds with prediction + confidence
  ↓
If confidence > threshold: proceed
If confidence < threshold: ask user
```

### Phase 4: Learning & Feedback
```
User makes decision (via question or validation)
  ↓
Twin observes decision
  ↓
Twin updates preference model
  ↓
Twin adjusts confidence scores
  ↓
Meta-learner analyzes outcome
  ↓
Meta-learner feeds back to twin
  ↓
Twin refines predictions
```

## Cybernetic Feedback Loops

### Loop 1: Decision Learning
```
User Decision → Twin Learns → Twin Predicts → Less Questions → Better UX
```

### Loop 2: Outcome Refinement
```
Twin Suggestion → Agent Acts → Meta-Learner Validates → Twin Adjusts → Better Suggestions
```

### Loop 3: Cross-Agent Knowledge
```
Twin observes Architect → Twin observes Engineer → Twin learns implementation patterns → Twin suggests better architectures
```

### Loop 4: Self-Improvement
```
Twin low confidence → Ask user → User answers → Twin high confidence → Twin auto-answers → Validate → Adjust threshold
```

## Storage Mechanism

### Files
- `.claude/learning/user-preferences.json` - Structured preference data
- `.claude/learning/user-twin-memory.md` - Narrative memory and context
- `.claude/learning/decision-log.jsonl` - Append-only decision history
- `.claude/learning/pattern-library.md` - Learned patterns (shared with meta-learner)

### Update Strategy
- **Incremental**: Append to decision log after each decision
- **Consolidation**: Update preferences.json after significant learning
- **Versioning**: Track confidence changes over time
- **Rollback**: Can revert to previous preference model if needed

## Agent Integration Points

### Coordinator (mynixos-orchestrator)
- Spawns user-twin early (parallel with task analysis)
- Queries twin for user preferences before spawning architect
- Includes twin suggestions in agent prompts
- Coordinates twin feedback loops

### Architect (mynixos-architect)
- Receives twin suggestions as "user's typical preferences"
- Queries twin when design has multiple valid approaches
- Reports design decisions back to twin for learning

### Engineer (mynixos-engineer)
- Queries twin for code style preferences
- Asks twin about naming conventions
- Reports implementation choices to twin

### Refactorer (mynixos-refactorer)
- Queries twin about migration strategy preferences
- Asks about backward compatibility requirements
- Reports refactoring patterns to twin

### Validator (mynixos-validator)
- Reports validation results to twin
- Twin learns from what passes/fails
- Twin adjusts risk tolerance based on outcomes

### Meta-Learner (mynixos-meta-learner)
- Analyzes twin's prediction accuracy
- Provides feedback to twin for model adjustment
- Collaborates on pattern library updates

## Parallelization Strategy

### Concurrent Execution
```
Task arrives
  ├─ [parallel] Coordinator analyzes task
  ├─ [parallel] Twin loads preferences
  └─ [parallel] Twin searches for relevant patterns

Coordinator needs design
  ├─ [parallel] Twin provides suggestions
  ├─ [parallel] Architect begins design
  └─ Wait for twin suggestions, incorporate, continue

Implementation begins
  ├─ [parallel] Engineer implements
  ├─ [parallel] Twin observes code patterns
  └─ [parallel] Refactorer prepares migrations

Validation
  ├─ [parallel] Validator tests builds
  ├─ [parallel] Twin analyzes outcomes
  └─ [parallel] Meta-learner processes results

Feedback
  ├─ [async] Twin updates preference model
  └─ [async] Meta-learner updates pattern library
```

### Long-Running Behavior
- Twin persists across sessions (loads from .claude/learning/)
- Accumulates knowledge over weeks/months
- Confidence increases with more data
- Can be "reset" if preferences change drastically

## Confidence Thresholds

### High Confidence (>0.9): Auto-decide
- "User prefers nested options for dependent features"
- "User wants enable options for all user-controllable features"
- "User prefers opinionated defaults"

### Medium Confidence (0.7-0.9): Suggest to agent
- "User probably prefers approach X, but confirm if critical"
- Include in architect prompt as "user typically prefers..."

### Low Confidence (<0.7): Ask user
- Not enough data to predict
- Conflicting patterns observed
- High-impact decision requiring explicit choice

## Example Interaction Flow

```
User: "Add support for GNOME alongside Hyprland"

Coordinator:
  1. Spawns twin (parallel)
  2. Analyzes task (parallel)
  3. Queries twin: "User's graphical preferences?"

Twin responds:
  {
    "display_manager": "greetd (high confidence)",
    "multiple_desktops": "unknown (ask user)",
    "nesting": "nest under my.users.<name>.graphical.desktop.type",
    "confidence": 0.6
  }

Coordinator spawns architect with twin's suggestions:
  "Design GNOME support. Note: User prefers greetd for DM,
   typically uses nested options under graphical namespace."

Architect designs, includes question about default desktop

Twin observes user's answer: "Default to Hyprland"
Twin updates: user.preferences.graphical.default_desktop = "hyprland"

Engineer implements based on design + twin suggestions

Validator tests, reports success

Meta-learner analyzes:
  - Twin suggestion about nesting was correct
  - Twin correctly predicted greetd preference
  - Confidence in graphical nesting increased to 0.95

Twin updates preference model for next time
```

## Evolution Over Time

### Week 1
- Learning basic preferences
- Asking many questions
- Building initial model

### Month 1
- Moderate confidence on common patterns
- Reducing question frequency
- Proactively suggesting to architect

### Month 6
- High confidence on most decisions
- Rare questions needed
- Actively guiding architecture
- Predicting user needs before stated

### Year 1
- Deep understanding of user's style
- Anticipating requirements
- Suggesting improvements proactively
- Nearly autonomous for common tasks

## Success Metrics

- **Question reduction rate**: % decrease in AskUserQuestion calls
- **Prediction accuracy**: % of twin predictions validated by user
- **Confidence growth**: Increase in high-confidence preferences over time
- **Agent efficiency**: Faster task completion due to fewer user interruptions
- **User satisfaction**: User reports system "understands" their preferences

## Privacy & Control

- User can view preference model anytime (read .claude/learning/user-preferences.json)
- User can reset twin's memory (delete learning files)
- User can adjust confidence thresholds
- User can override any twin suggestion
- All twin predictions are logged for transparency
