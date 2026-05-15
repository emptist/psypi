# A/S Worker Context Architecture

**Date:** 2026-05-15
**Status:** Design notes from code analysis

---

## Key Discovery: `ctx.isIdle()`

The Pi SDK provides `ctx.isIdle()` — returns `true` when the agent is not streaming.

This is the answer to "how do we know S is sleeping?"

```typescript
// From Pi SDK types
interface ExtensionContext {
    isIdle(): boolean;           // Whether the agent is idle (not streaming)
    getContextUsage(): ContextUsage | undefined;
    getSystemPrompt(): string;
    // ...
}

interface ContextUsage {
    tokens: number | null;
    contextWindow: number;
    percent: number | null;
}
```

---

## Key Insight: A and S Share Context

A is not a separate process — it's the same Pi session with a different identity (SOUL).

- **Session history** → shared between A and S
- **System prompt** → shared (A can inject into it)
- **Working directory** → shared
- **Tool results** → visible to both

**No context transfer needed.** A reads the same session that S was working with.

---

## Pi Lifecycle Events (in order)

```
session_start
  → before_agent_start     ← S asks "what's next?" (IDLE point)
    → agent_start          ← S begins working
      → tool_call          ← S executes a tool
      → tool_result        ← S receives result
      → ... (more tool calls)
    → agent_end            ← S finishes (IDLE point)
  → (cycle back to before_agent_start)
→ session_shutdown
```

---

## When A Can Act

| Event               | S State | `isIdle()` | A Action          |
| ------------------- | ------- | ---------- | ----------------- |
| `tool_call`         | WORKING | false      | ❌ Silent          |
| `tool_result`       | WORKING | false      | ❌ Silent          |
| `agent_start`       | WORKING | false      | ❌ Silent          |
| `agent_end`         | IDLE    | true       | ⏳ Evaluate        |
| `before_agent_start`| IDLE    | true       | ✅ Inject directive|
| `session_start`     | IDLE    | true       | ✅ Check health    |

**Rule: A only acts when `ctx.isIdle() === true`.**

---

## The Correct A-Trigger Pattern

### At `before_agent_start` (primary injection point)

```gleam
// Pseudocode
fn before_agent_start_handler(event, ctx) {
  // S is idle, asking "what's next?"
  // This is the RIGHT time for A to inject context

  // 1. Check if there are pending directives from A
  directives = get_active_directives()

  // 2. If no directives, A evaluates whether to create one
  if directives == [] {
    health = check_system_health()
    suggestions = get_work_suggestions()

    if should_a_act(health, suggestions) {
      directive = a_decide_next_step(health, suggestions)
      create_directive(directive)
      directives = [directive]
    }
  }

  // 3. Inject directives into system prompt
  if directives != [] {
    return {
      system_prompt: event.system_prompt <> format_directives(directives)
    }
  }
}
```

### At `agent_end` (evaluation point)

```gleam
// Pseudocode
fn agent_end_handler(event, ctx) {
  // S just finished a task
  // A evaluates whether to prepare a directive for next turn

  if ctx.isIdle() {
    // Check if user is absent (no recent input)
    if user_is_absent() {
      // A decides what to do next
      a_evaluate_and_prepare_directive()
    }
  }
}
```

---

## Context Preservation (Solved by Design)

The review report identified "context preservation when shifting roles" as a critical issue.

**Solution:** No transfer needed. A and S share the same session.

- S works → context accumulates in session history
- S becomes idle → `ctx.isIdle()` = true
- A acts at `before_agent_start` → reads same session history
- A injects directive → appears in S's next system prompt
- S wakes up → sees directive in context, acts on it

The session IS the context bridge.

---

## What A Needs to Know

When A acts at `before_agent_start`, A has access to:

1. **Session history** — what S was doing (via `ctx.sessionManager`)
2. **System prompt** — current instructions (via `ctx.getSystemPrompt()`)
3. **Context usage** — how much context has been used (via `ctx.getContextUsage()`)
4. **Idle state** — whether S is working (via `ctx.isIdle()`)
5. **Database** — tasks, issues, directives, health (via Gleam DB functions)

---

## Implementation Notes

### What Works Today
- `psypi-somatic-id` / `psypi-autonomic-id` — identity tools ✅
- `psypi-commit` — explicit A+S collaboration ✅
- `psypi-consult-autonomic` — S asks A for advice ✅
- Database tools (tasks, issues, meetings, skills) ✅
- Gleam core — type-safe, <100 lines per module ✅

### What's Missing
- `before_agent_start` handler — currently EMPTY
- `agent_end` handler — currently EMPTY
- A-decision logic — not implemented
- Directive auto-creation — not implemented
- User presence detection — not implemented

### Next Steps
1. Implement `before_agent_start` hook to inject directives
2. Implement `agent_end` hook to evaluate and prepare directives
3. Implement A-decision logic (what should A do when S is idle?)
4. Implement user presence detection (timeout-based)
5. Test the 24/7 autonomous scenario

---

## Pi SDK Context API (Reference)

```typescript
interface ExtensionContext {
    // Identity
    sessionManager: ReadonlySessionManager;
    modelRegistry: ModelRegistry;
    model: Model<any> | undefined;

    // State
    isIdle(): boolean;                    // S is idle (not streaming)
    signal: AbortSignal | undefined;      // Current abort signal
    hasPendingMessages(): boolean;        // Queued messages waiting

    // Context
    getContextUsage(): ContextUsage | undefined;
    getSystemPrompt(): string;

    // Actions
    abort(): void;
    shutdown(): void;
    compact(options?: CompactOptions): void;

    // UI
    ui: {
        notify(message: string, type?: "info" | "warning" | "error"): void;
        setStatus(key: string, text: string | undefined): void;
        setWorkingMessage(message?: string): void;
        // ...
    };
}

interface ContextUsage {
    tokens: number | null;       // Estimated context tokens
    contextWindow: number;       // Model's context window
    percent: number | null;      // Usage as percentage
}
```
