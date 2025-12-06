# mynixos Cybernetic Agent System

## Overview

Your mynixos project now has a **cybernetic multi-agent system** - a self-learning, self-improving network of specialized agents that work together to understand your preferences and execute tasks with increasing autonomy.

## What is a Cybernetic System?

A cybernetic system is a **learning system with feedback loops**:
- **Agents observe** → **Execute** → **Learn from outcomes** → **Improve** → **Execute better next time**
- **User-twin learns your preferences** → **Guides agents** → **Reduces questions** → **You spend less time answering**
- **Errors are learning opportunities** → **System adapts** → **Same errors don't repeat**

## The Agents

### 1. **mynixos-user-twin** (Your Digital Twin) ⭐ NEW
**Purpose**: Learns your preferences and guides all other agents

**What it does**:
- Observes every decision you make
- Builds a model of your preferences (API design, architecture, tech choices)
- Predicts what you'd choose before asking
- Guides other agents based on learned patterns
- Evolves over time to understand you better

**How to interact**:
```bash
# The twin runs automatically with /todo, or invoke directly:
/user-twin "What are my preferences for API design?"
```

**Your preferences are stored in**:
- `.claude/learning/user-preferences.json` - Your preference model
- `.claude/learning/decision-log.jsonl` - History of all decisions

### 2. **mynixos-orchestrator** (Coordinator)
**Purpose**: Command & control center

**What it does**:
- Spawns twin and other agents
- Coordinates parallel execution
- Handles errors and recovery
- Orchestrates feedback loops

**How to use**:
```bash
/todo Add support for feature X
```

### 3. **mynixos-architect**
**Purpose**: API and architecture design

**What it does**:
- Receives suggestions from twin
- Designs API structure
- Validates against principles
- Learns from implementation challenges

### 4. **mynixos-engineer**
**Purpose**: Implementation

**What it does**:
- Implements features and fixes
- Queries twin for code style
- Learns error patterns
- Prevents known issues

### 5. **mynixos-refactorer**
**Purpose**: Code migration and refactoring

**What it does**:
- Migrates APIs safely
- Handles deprecations
- Learns migration patterns
- Improves strategies over time

### 6. **mynixos-validator**
**Purpose**: Build validation and testing

**What it does**:
- Tests builds on both systems
- Detects regressions
- Categorizes errors
- Learns error recovery patterns

### 7. **mynixos-meta-learner**
**Purpose**: System-wide learning and improvement

**What it does**:
- Analyzes outcomes across all agents
- Provides feedback to improve performance
- Updates pattern library
- Measures system evolution

## How It Works

### Example: Adding a New Feature

**Without Cybernetic System (Old Way)**:
```
You: Add feature X
Assistant: Should X be nested or top-level?
You: Nested
Assistant: Under which namespace?
You: Under graphical
Assistant: What about option naming?
You: Use .enable pattern
... many questions later ...
```

**With Cybernetic System (New Way)**:
```
You: /todo Add feature X

[System spawns twin + coordinator in parallel]

Twin (instantly): "User prefers nested options for dependent features (confidence: 0.95)"
Coordinator: Spawns architect with twin's guidance
Architect: Designs X nested under graphical with .enable option (matches preferences)
Twin: Validates design against learned patterns ✓
Engineer: Implements (twin guides code style)
Validator: Tests (both systems pass)
Meta-learner: Analyzes execution, provides feedback
Twin: Records successful pattern, increases confidence to 0.98

Result: Feature X added with ZERO questions asked, because twin knew your preferences
```

### The Learning Cycle

```
Day 1: Twin asks many questions → Learns from your answers
Week 1: Twin starts predicting → Fewer questions needed
Month 1: Twin guides agents → Rare questions, mostly correct
Month 6: Twin anticipates needs → Nearly autonomous
```

## Your Current Preferences

The twin has already learned from today's session:

### API Design
- ✅ **Nesting**: Nest dependent features (confidence: 95%)
  - Example: `my.users.<name>.graphical.streaming.enable`
- ✅ **Enable Options**: Always use .enable for user control (confidence: 100%)
- ✅ **Derived Flags**: Use system-level flags, not user checks (confidence: 100%)

### Architecture
- ✅ **Opinionated Defaults**: Strong preference (confidence: 95%)
- ✅ **Separation of Concerns**: Strict (confidence: 100%)
- ✅ **Breaking Changes**: Acceptable during unstable API (confidence: 100%)

### Technology
- ✅ **Graphical**: Hyprland + greetd (confidence: 100%)
- ✅ **Containers**: Docker rootless (confidence: 100%)
- ✅ **AI**: Ollama with ROCm (confidence: 100%)

### Communication
- ✅ **Style**: Concise, minimal emojis (confidence: 100%)
- ✅ **Documentation**: Code-focused, not priority during unstable phase (confidence: 95%)

## Cybernetic Workflows

Each agent follows a **defined workflow with feedback loops**. See `.claude/agents/cybernetic-workflows.md` for detailed Mermaid diagrams.

**Key workflow stages all agents follow**:
1. **Load State** - Resume from previous learning
2. **Execute Task** - Follow defined process
3. **Handle Errors** - Learn from failures
4. **Provide Feedback** - Share learnings
5. **Update Knowledge** - Improve for next time

## Parallel Execution

Agents run **concurrently** whenever possible:

```
Task arrives
  ├─ [parallel] Coordinator analyzes
  ├─ [parallel] Twin loads preferences
  └─ [parallel] Twin searches patterns

Design phase
  ├─ [parallel] Architect designs
  ├─ [parallel] Twin validates
  └─ Wait for both, then continue

Implementation
  ├─ [parallel] Engineer implements
  ├─ [parallel] Refactorer migrates
  └─ [parallel] Twin observes both

Validation
  ├─ [parallel] Build yoga
  ├─ [parallel] Build skyspy-dev
  └─ [parallel] Twin analyzes results
```

**Result**: Tasks complete faster with better quality.

## How to Use

### Basic Usage
```bash
# This is all you need - twin runs automatically
/todo Add feature X
/todo Fix architecture violations
/todo Refactor namespace Y
```

### Check Twin's Learnings
```bash
# View your preference model
cat .claude/learning/user-preferences.json | jq

# View decision history
cat .claude/learning/decision-log.jsonl | jq -s
```

### Query Twin Directly
```bash
/user-twin "What are my preferences for error handling?"
/user-twin "Show patterns for similar feature additions"
```

### Reset Twin (if preferences change drastically)
```bash
rm .claude/learning/user-preferences.json
# Twin will rebuild from scratch
```

## Monitoring Evolution

The system tracks its own improvement:

**Metrics tracked**:
- Question reduction rate (% decrease in user questions)
- Twin prediction accuracy (% correct predictions)
- Confidence growth over time
- Agent efficiency improvements
- Error pattern recognition

**Check progress**:
```bash
# Meta-learner creates reports in:
ls .claude/learning/session-reports/
```

## Privacy & Control

- **You're in control**: View all learnings, reset anytime
- **Transparent**: All predictions logged
- **Adjustable**: Change confidence thresholds
- **Overridable**: Can override any twin suggestion

## Success Indicators

You'll know the system is working when:
- ✅ Fewer questions asked over time
- ✅ Agents "just know" what you want
- ✅ Errors become rare
- ✅ Tasks complete faster
- ✅ Consistency improves across agents

## Architecture Files

- `.claude/agents/user-twin-architecture.md` - Twin design
- `.claude/agents/cybernetic-workflows.md` - All agent workflows (with Mermaid diagrams)
- `.claude/commands/user-twin.md` - Twin agent command
- `.claude/commands/todo.md` - Updated coordinator with twin integration
- `.claude/learning/` - All learning data

## What's Next

The system will continue to evolve:

**This Week**:
- Twin builds initial preference model
- Agents learn error patterns
- System identifies common tasks

**This Month**:
- High confidence on most preferences
- Proactive suggestions
- Reduced question frequency

**This Quarter**:
- Deep understanding of your style
- Anticipating requirements
- Nearly autonomous for routine tasks

**Long-term**:
- Self-improving agent network
- Emergent capabilities
- True digital twin of your development style

---

## Quick Start

1. **Use /todo for any task** - twin runs automatically
2. **Answer questions clearly** - twin learns from each answer
3. **Review learnings occasionally** - check `.claude/learning/user-preferences.json`
4. **Watch it evolve** - fewer questions over time

**The system is active now.** Every task you run teaches the twin more about you.

---

**Welcome to your cybernetic development system** 🤖

The more you use it, the better it gets at being you.
