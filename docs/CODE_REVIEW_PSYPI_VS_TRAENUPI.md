# psypi Code Review Report

**Date:** 2026-05-15
**Reviewer:** Code Assistant (after deep analysis with user guidance)

---

## Executive Summary

**psypi = Pi补完计划 = 让AI能7×24小时自主工作**

This review analyzes psypi using three approaches:
1. **Document/Code/Logic comparison** — Architecture docs vs actual code
2. **Git log analysis** — Development trajectory and concept evolution
3. **Understanding the core insight** — Why psypi exists

**Key Finding:** Pi implements one half of a circle (execution), psypi implements the other half (autonomous continuation). The A-agentbot/S-agentbot architecture is not over-engineering — it's the core mechanism for achieving 24/7 autonomous AI operation.

---

## 1. The Core Insight: Why psypi Exists

### Pi's Limitation

```
Pi: Half a circle
┌─────────────────┐
│                 │
│   Pi (S-)       │
│   Execute       │
│   User Commands │
│                 │
└────────┬────────┘
         │
         │ User present = works
         │ User absent = stops
         ▼
    [Stops waiting for user]
```

Pi is a coding agent that **requires continuous user input**. When the user is present, it works. When the user leaves, it stops.

### psypi Completes the Circle

```
                    ┌─────────────────┐
                    │                 │
        User ──────►│   Pi (S-)       │◄──── User active
        Present     │   Execute       │
                    └────────┬────────┘
                             │
                    User ────┼─── Idle
                    absent   │
                             │
                    ┌────────▼────────┐
                    │                 │
                    │  psypi (A-)     │
                    │  Decide Next    │◄──── Autonomous
                    │  Keep Working   │      24/7
                    └─────────────────┘
```

**A-agentbot's role:** When the user is absent, A-agentbot takes over the responsibility of "deciding what to do next", allowing the AI to continue working autonomously.

---

## 2. A/S Architecture: The Key Distinction

### Not "Over-engineering" — It's the Core Mechanism

The A/S architecture is not unnecessary complexity. It's the mechanism that enables:

1. **Separation of concerns** — S executes, A decides
2. **Context isolation** — A's decisions don't interrupt S mid-task
3. **Identity tracking** — Who did what, when, and why

### A vs S: Roles and Timing

| Agentbot           | Identity      | Role                  | Timing       |
| ------------------ | ------------- | --------------------- | ------------ |
| **S-** (Somatic)   | Task executor | Execute user commands | User present |
| **A-** (Autonomic) | Task decider  | Decide next steps     | User absent  |

### The Critical Rule: When A Can Speak

```
S is WORKING ════════════════════════════════════════
    │                     │
    │ ← A CANNOT speak   │ (would interrupt)
    │
    │
S is IDLE ══════════════════════════════════════════
    │
    │ ← A CAN speak
    │   (inject directives, suggest next step)
    ▼
A decides what to do next
```

**The original bug:** A inserting into S's context while S was working — this was "夺权" (seizing power), not "补位" (taking over when empty).

**The correct pattern:** A only acts when S is idle, not when S is working.

---

## 3. Why the Simplification Happened

### What Was Removed

| Hook                 | Original Behavior             | Problem                  |
| -------------------- | ----------------------------- | ------------------------ |
| `session_start`      | Check health → notify         | A speaking unprompted    |
| `agent_end`          | Wake up S with message        | A interrupting S's flow  |
| `tool_result`        | Auto-create directive + issue | A being too noisy        |
| `before_agent_start` | Inject directives             | A inserting mid-workflow |

### Why It Was Wrong

```
S-agentbot: "I'm working on this bug fix..."
    │
    │ ← A detects an error
    │ ← A creates directive
    │ ← A injects into S's system prompt
    │
    │ A just interrupted S! ❌
```

**This was "夺权" (seizing power)**, not "补位" (filling an empty slot).

### What Should Happen

```
S-agentbot: "Done! What should I do next?"
    │
    │ ← S is now IDLE
    │
    │ A checks tasks, issues, system health
    │ A decides: "Work on issue #42"
    │
    ✓ A's directive is welcome here
```

**A only acts when S is idle, not when S is working.**

---

## 4. Current State vs Design Intent

### Current Code (HEAD: 0808de6)

| Component             | Status        | Notes                   |
| --------------------- | ------------- | ----------------------- |
| S-/A- Identity System | ✅ Implemented | Computed, not cached    |
| Directive System      | ✅ Defined     | But not auto-triggered  |
| A-agentbot triggers   | ❌ Removed     | Was causing "夺权"      |
| Auto injection        | ❌ Disabled    | Only for explicit calls |

### What Works

- `psypi-somatic-id` / `psypi-autonomic-id` — Identity tools
- `psypi-commit` — Explicit inter-review (A+S collaboration)
- `psypi-consult-autonomic` — S asks A for advice
- Tasks, Issues, Meetings, Skills, Memory — Database tools
- Gleam core — Type-safe, <100 lines per module

### What's Not Working

- A-agentbot autonomous takeover — **The core feature is not implemented**
- Automatic decision injection when user is absent
- 24/7 autonomous operation

---

## 5. The Technical Problems and Solutions

Now that the concept is clear, these are the **technical problems and solutions**:

### Problem 1: Detecting "User Absent" vs "S Working"

How does A know when to act?

```
Indicators S is IDLE:
- agent_end just fired (S completed a task)
- session_start (new session beginning)
- before_agent_start (S is asking "what's next")

Indicators S is WORKING:
- tool_call / tool_result (S is executing)
- agent_start (S has already started)
```

#### Solution: State Machine in extension.js

```javascript
// State machine to track S's status
let sState = {
  isWorking: false,
  userPresent: true,
  lastActivity: Date.now()
};

// Track user presence via TUI input
let userActivityTimer = null;
pi.on('user_input', async (_event, ctx) => {
  sState.userPresent = true;
  sState.lastActivity = Date.now();
  clearTimeout(userActivityTimer);
  // User considered absent after 5 minutes of no input
  userActivityTimer = setTimeout(() => {
    sState.userPresent = false;
  }, 5 * 60 * 1000);
});

// Track S's working status
pi.on('agent_start', async (_event, ctx) => {
  sState.isWorking = true;
});

pi.on('agent_end', async (_event, ctx) => {
  sState.isWorking = false;
});

pi.on('tool_call', async (_event, ctx) => {
  sState.isWorking = true;
});

pi.on('tool_result', async (_event, ctx) => {
  // S just completed a tool, might become idle soon
  setTimeout(() => {
    if (!sState.isWorking) {
      // S is now idle, check if A should act
      checkIfAAct(sState);
    }
  }, 1000); // Give S time to decide next step
});
```

---

### Problem 2: A's Trigger Mechanism

When S is idle, how does A decide to act?

#### Solution: A acts only when S is IDLE AND User is ABSENT

```javascript
// In extension.js

async function checkIfAAct(sState) {
  // A should only act when:
  // 1. S is IDLE (not working)
  // 2. User is ABSENT (not providing input)
  if (sState.isWorking || sState.userPresent) {
    return; // Not the right time
  }

  // A acts!
  await aAgentbotTakesOver();
}

async function aAgentbotTakesOver() {
  // 1. Get A's identity
  const { get_autonomic_identity } = await import('./build/dev/javascript/psypi/agent_identity.mjs');
  const aId = await get_autonomic_identity();

  // 2. Check system state (tasks, issues, health)
  const { check_system_health } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');
  const health = await check_system_health();

  // 3. A decides what to do
  if (health.open_issues > 0) {
    // Set directive for S
    const { set_directive } = await import('./build/dev/javascript/psypi/directive.mjs');
    await set_directive(
      `Review ${health.open_issues} open issues and prioritize fixes.`,
      'medium'
    );
  }

  // 4. Notify via ctx (will appear when S next asks)
  ctx.ui.notify('[Autonomic] System has pending work. Check tasks when ready.', 'info');
}
```

---

### Problem 3: Directive Injection Without Interruption

How does A inject directives without breaking S's context?

#### Solution: Only inject at IDLE points, never during work

```javascript
// CORRECT: before_agent_start - S is ASKING what to do next
pi.on('before_agent_start', async (event, ctx) => {
  // S is idle, asking "what's next?"
  // This is the RIGHT time to inject

  const { get_active_directives } = await import('./build/dev/javascript/psypi/directive.mjs');
  const { get_autonomic_identity } = await import('./build/dev/javascript/psypi/agent_identity.mjs');

  const aId = await get_autonomic_identity();
  const directives = await get_active_directives(aId);

  if (directives.length > 0) {
    // Format with [Autonomic] prefix
    const directiveText = directives.map((d, i) =>
      `${i + 1}. [Autonomic] ${d}`
    ).join('\n');

    // Inject into system prompt (S is idle, won't interrupt)
    return {
      systemPrompt: event.systemPrompt + '\n\n[DIRECTIVES]\n' + directiveText + '\n[/DIRECTIVES]\n'
    };
  }
});

// WRONG: tool_result - S is processing result
pi.on('tool_result', async (event, ctx) => {
  // DON'T inject here - S is working!
  // Original bug: created directives here → interrupted S
});
```

---

### Problem 4: A's Autonomy Level

How much can A do autonomously?

#### Solution: Configurable autonomy levels

```javascript
// In monitor_ai.gleam

pub type AutonomyLevel {
  SuggestOnly      // Level 1: A suggests, S decides
  DirectiveOnly    // Level 2: A sets directives, S executes
  AutoLowRisk      // Level 3: A auto-executes low-risk tasks
  FullAutonomy     // Level 4: A has full control
}

pub fn should_auto_act(level: AutonomyLevel, action: Action) -> Bool {
  case level {
    SuggestOnly -> False  // A never auto-acts
    DirectiveOnly -> action.type == Directive  // Only set directives
    AutoLowRisk -> action.risk < RiskLevel(3) && action.type != Write
    FullAutonomy -> True
  }
}

// Usage in checkIfAAct:
async function aAgentbotTakesOver(sState, autonomyLevel) {
  const actions = await aPlanNextSteps();

  for (const action of actions) {
    if (!should_auto_act(autonomyLevel, action)) {
      continue; // Skip this action at this autonomy level
    }

    switch (action.type) {
      case 'directive':
        await set_directive(action.content, action.priority);
        break;
      case 'execute':
        if (action.risk < 3) {
          await execute_action(action); // Only low-risk
        }
        break;
    }
  }
}
```

---

### Problem 5: The Complete A-Trigger Flow

Putting it all together:

```javascript
// extension.js - Complete A-trigger mechanism

let sState = {
  isWorking: false,
  userPresent: true,
  directives: []
};

// ============================================
// S-State Tracking
// ============================================

pi.on('agent_start', async (_event, ctx) => {
  sState.isWorking = true;
});

pi.on('agent_end', async (_event, ctx) => {
  sState.isWorking = false;
  // S just became IDLE - check if A should act
  scheduleACheck();
});

pi.on('tool_call', async (_event, ctx) => {
  sState.isWorking = true;
});

// ============================================
// User Presence Detection
// ============================================

let userTimeout = null;
pi.on('user_input', async (_event, ctx) => {
  sState.userPresent = true;
  clearTimeout(userTimeout);
  // User absent after 5 min of silence
  userTimeout = setTimeout(() => {
    sState.userPresent = false;
  }, 5 * 60 * 1000);
});

// ============================================
// A-Agentbot Decision Point
// ============================================

function scheduleACheck() {
  // Wait for S to ask "what's next?" (before_agent_start)
  // Don't act immediately - let S finish current thought
}

pi.on('before_agent_start', async (event, ctx) => {
  // S is asking "what's next?" - IDLE point!

  if (!sState.isWorking && !sState.userPresent) {
    // User absent + S idle = A can act
    const directives = await aDecideNextSteps();

    if (directives.length > 0) {
      const text = directives.map((d, i) =>
        `${i + 1}. [Autonomic] ${d}`
      ).join('\n');

      return {
        systemPrompt: event.systemPrompt + '\n\n[DIRECTIVES]\n' + text + '\n[/DIRECTIVES]\n'
      };
    }
  }

  // User present or S working - just inject any pending directives
  if (sState.directives.length > 0) {
    const text = sState.directives.map((d, i) =>
      `${i + 1}. ${d}`
    ).join('\n');
    return {
      systemPrompt: event.systemPrompt + '\n\n[NOTES]\n' + text + '\n[/NOTES]\n'
    };
  }
});

// ============================================
// A-Agentbot Logic
// ============================================

async function aDecideNextSteps() {
  const { check_system_health } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');
  const { get_work_suggestions } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');

  const health = await check_system_health();
  const suggestions = await get_work_suggestions();

  const directives = [];

  // Critical issues → high priority directive
  if (health.critical_issues > 0) {
    directives.push(`URGENT: ${health.critical_issues} critical issues need attention.`);
  }

  // Open tasks → suggest next work
  if (suggestions.length > 0) {
    directives.push(suggestions[0].description);
  }

  // Store for potential injection
  sState.directives = directives;

  return directives;
}
```

---

### Summary: The Correct A-Trigger Pattern

| Hook                 | S State | User    | A Action         |
| -------------------- | ------- | ------- | ---------------- |
| `tool_call`          | WORKING | ?       | ❌ Silent         |
| `tool_result`        | WORKING | ?       | ❌ Silent         |
| `agent_start`        | WORKING | ?       | ❌ Silent         |
| `agent_end`          | IDLE    | ?       | ⏳ Schedule check |
| `before_agent_start` | IDLE    | PRESENT | ⚠️ Suggest only   |
| `before_agent_start` | IDLE    | ABSENT  | ✅ A decides      |
| `session_start`      | IDLE    | ?       | ⚠️ Check status   |

---

## 6. Easy vs Hard: Problem Categorization

### Easy Problems (Tool Functionality Gaps)

These are **standalone improvements** that don't require A-trigger mechanism:

| Gap                            | Impact                  | Solution                                  | Effort |
| ------------------------------ | ----------------------- | ----------------------------------------- | ------ |
| Short ID resolution for issues | Must use full UUID      | Add `resolve_short_id()` function         | Low    |
| Knowledge categories           | Can't organize learning | Add `category` param to `learn_save_tool` | Low    |
| Missing `stats-show` details   | Incomplete stats        | Add more metrics                          | Low    |
| Issue short ID in responses    | Useless UUIDs shown     | Map to short IDs in UI                    | Low    |

#### Example: Short ID Resolution

```javascript
// In issue.gleam - Add short ID support

pub fn resolve_short_id(short_id: String) -> Result(String, IssueError) {
  case short_id {
    "latest" -> get_latest_issue_id()
    _ -> find_by_short_prefix(short_id)
  }
}

// Usage:
// /psypi-issue-show latest
// /psypi-issue-show bug-001
```

#### Example 1: Short ID Resolution

**Problem:** Users must use full UUIDs like `a1b2c3d4-e5f6-...` instead of short IDs like `bug-001`

**Solution:** Add short ID mapping with prefix and auto-increment

```gleam
// In issue.gleam

pub type ShortIdMapping {
  ShortIdMapping(short_id: String, full_id: String, created_at: String)
}

fn short_id_decoder() -> decode.Decoder(ShortIdMapping) {
  use short_id <- decode.field("short_id", decode.string)
  use full_id <- decode.field("full_id", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(ShortIdMapping(short_id:, full_id:, created_at:))
}

pub fn resolve_short_id(short_id: String) -> promise.Promise(Result(String, IssueError)) {
  db.with_connection(fn(conn) {
    case short_id {
      "latest" -> {
        // Get most recently created issue
        let sql = "SELECT id FROM issues ORDER BY created_at DESC LIMIT 1"
        promise.map(db.query(conn, sql, []), fn(result) {
          case result {
            Ok(rows) -> {
              case rows {
                [row, ..] -> {
                  case decode.run(row, decode.field("id", decode.string)) {
                    Ok(id) -> Ok(id)
                    Error(_) -> Error(DecodeError("Failed to decode id"))
                  }
                }
                _ -> Error(NotFound("No issues found"))
              }
            }
            Error(e) -> Error(QueryError(e.message))
          }
        })
      }
      _ -> {
        // Find by short_id prefix
        let sql = "SELECT full_id FROM issue_short_ids WHERE short_id LIKE $1 || '%' LIMIT 1"
        let params = [dynamic.string(short_id)]
        promise.map(db.query(conn, sql, params), fn(result) {
          case result {
            Ok(rows) -> {
              case rows {
                [row, ..] -> {
                  case decode.run(row, decode.field("full_id", decode.string)) {
                    Ok(id) -> Ok(id)
                    Error(_) -> Error(DecodeError("Failed to decode full_id"))
                  }
                }
                _ -> Error(NotFound("Short ID not found: " <> short_id))
              }
            }
            Error(e) -> Error(QueryError(e.message))
          }
        })
      }
    }
  }, fn(e) { QueryError(e.message) })
}

// Generate short ID when creating issue
pub fn generate_short_id(issue_type: IssueType) -> String {
  let prefix = case issue_type {
    Bug -> "bug"
    Inconsistency -> "inc"
    Feature -> "feat"
    Improvement -> "imp"
    Question -> "q"
    Debt -> "debt"
  }
  let random_suffix = generate_random_hex(3)
  prefix <> "-" <> random_suffix
}
```

**Usage:**
```
/psypi-issue-show latest        → Shows most recent issue
/psypi-issue-show bug-a1b       → Resolves to full UUID
/psypi-issue-add "Title" bug    → Creates issue-abc123
```

---

#### Example 2: Knowledge Categories

**Problem:** `learn_save_tool` saves learning but can't categorize it

**Solution:** Add optional category parameter

```gleam
// In learning.gleam

pub type LearningCategory {
  Architecture
  Pattern
  Bug
  Optimization
  Documentation
  Experiment
  Unknown
}

pub fn string_to_category(s: String) -> Result(LearningCategory, String) {
  case s {
    "architecture" -> Ok(Architecture)
    "pattern" -> Ok(Pattern)
    "bug" -> Ok(Bug)
    "optimization" -> Ok(Optimization)
    "documentation" -> Ok(Documentation)
    "experiment" -> Ok(Experiment)
    _ -> Ok(Unknown)
  }
}

pub fn category_to_string(c: LearningCategory) -> String {
  case c {
    Architecture -> "architecture"
    Pattern -> "pattern"
    Bug -> "bug"
    Optimization -> "optimization"
    Documentation -> "documentation"
    Experiment -> "experiment"
    Unknown -> "unknown"
  }
}

// Update learn_save to accept category
pub fn learn_save(
  category: String,
  content: String,
  agent_id: String,
) -> promise.Promise(Result(String, LearningError)) {
  case string_to_category(category) {
    Error(e) -> promise.resolve(Error(ValidationError(e)))
    Ok(cat) -> save_with_category(cat, content, agent_id)
  }
}

fn save_with_category(
  category: LearningCategory,
  content: String,
  agent_id: String,
) -> promise.Promise(Result(String, LearningError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO learnings (id, category, content, agent_id, created_at)
      VALUES (gen_random_uuid(), $1, $2, $3, NOW())
      RETURNING id
    "
    let params = [
      dynamic.string(category_to_string(category)),
      dynamic.string(content),
      dynamic.string(agent_id),
    ]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(rows) -> {
          case rows {
            [row, ..] -> Ok("Learned: [" <> category_to_string(category) <> "] " <> content)
            _ -> Error(QueryError("No id returned"))
          }
        }
        Error(e) -> Error(QueryError(e.message))
      }
    })
  }, fn(e) { QueryError(e.message) })
}

// Add search by category
pub fn search_by_category(
  category: String,
  limit: Int,
) -> promise.Promise(Result(List(Learning), LearningError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT * FROM learnings
      WHERE category = $1
      ORDER BY created_at DESC
      LIMIT $2
    "
    let params = [dynamic.string(category), dynamic.int(limit)]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(rows) -> {
          let learnings = rows
            |> list.map(fn(row) {
              case decode.run(row, learning_decoder()) {
                Ok(l) -> [l]
                Error(_) -> []
              }
            })
            |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
          Ok(learnings)
        }
        Error(e) -> Error(QueryError(e.message))
      }
    })
  }, fn(e) { QueryError(e.message) })
}
```

**Usage:**
```
/psypi-learn-save architecture "Use dependency injection for testability"
/psypi-learn-save bug "NullPointerException when config missing"
/psypi-learn-search --category architecture --limit 10
```

---

### Hard Problems (A-Trigger Mechanism)

These require **careful redesign** of the A/S interaction:

| Problem                                  | Complexity | Risk      |
| ---------------------------------------- | ---------- | --------- |
| User presence detection                  | Medium     | Low       |
| A-trigger timing (idle vs working)       | High       | Medium    |
| Directive injection without interruption | High       | High      |
| A's autonomy level control               | Medium     | High      |
| 24/7 autonomous operation                | Very High  | Very High |

**Recommendation:** Solve Easy problems first, then tackle Hard problems with clear understanding of the concepts.

---

## 7. Document vs Code Comparison

### Architecture Document (dated 2026-05-12)

Describes Phase 1 as complete:
- ✅ System prompt injection implemented
- ✅ Auto-file issues on error
- ✅ Monitor feedback loop working

### Actual Code

- `before_agent_start` — EMPTY handler
- `tool_result` — Just logs, doesn't create issues
- `session_start` — Just records model
- `agent_end` — EMPTY handler

**The document describes the DESIGN, not the current implementation.**

### Git Log Shows Why

```
1447fc1 fix: remove A-agentbot trigger from before_agent_start
d1a631d fix: simplify tool_result hook — log errors only
a2ee529 fix: simplify agent_end and session_start hooks
```

**The "simplification" was actually fixing the "夺权" bug.**

---

## 7. Recommendations

### For Development

1. **Redesign A-trigger mechanism**
   - Only act when S is IDLE (agent_end, before_agent_start, session_start)
   - Never act during tool_call, tool_result, agent_start

2. **Re-implement directive injection**
   - Currently disabled
   - Need to enable for when S is idle, not mid-workflow

3. **Add user presence detection**
   - A needs to know if user is active
   - If user active, A should be silent

4. **Test the 24/7 scenario**
   - Start psypi
   - Leave for 1 hour
   - Does it keep working?

### For Documentation

1. **Update ARCHITECTURE.md**
   - Clarify A/S roles and timing
   - Explain why original implementation was wrong

2. **Document the "half circle" insight**
   - Why psypi exists
   - What problem it solves

3. **Remove NEXT-PHASES.md or update it**
   - Currently describes removed features

---

## 8. True Value of psypi

### What psypi Actually Provides

| Value                 | Description                               |
| --------------------- | ----------------------------------------- |
| **24/7 Autonomy**     | AI continues working without user         |
| **Self-reflection**   | A reviews S's work, suggests improvements |
| **Identity Tracking** | Who did what, for future learning         |
| **Gleam Core**        | Type-safe, maintainable                   |
| **Pi Extension**      | Runs inside Pi TUI                        |

### What psypi is NOT

- Not just a tool collection
- Not just an extension framework
- Not over-engineered

### What psypi IS

**The missing half of Pi — the part that makes AI autonomous.**

---

## 9. Report Limitations

This review is based on:
- ✅ Reading architecture documentation
- ✅ Reading source code
- ✅ Git log analysis
- ✅ Understanding the core insight (with user guidance)
- ❌ Not runtime tested
- ❌ Not verified Gleam build
- ❌ Not tested 24/7 scenario

---

## Appendix: Key Insight

**The question that unlocked understanding:**

> "If Pi is complete, why does psypi exist?"

**Answer:**

Pi implements execution (S-), psypi implements autonomous continuation (A-). Together they form a complete circle:

```
Pi = Half (user-driven)
psypi = Other half (autonomous)
Complete = 24/7 AI operation
```

**A-agentbot's role is not to interrupt S, but to keep the system running when the user is absent.**
