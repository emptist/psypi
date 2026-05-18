# A/S Agentbot Context Architecture

**Date:** 2026-05-15
**Status:** Design notes from Pi SDK code analysis

---

## Key Discovery: `ctx.isIdle()`

The Pi SDK provides `ctx.isIdle()` — returns `true` when the agent is not streaming.

This is the answer to "how do we know S is sleeping?"

```typescript
interface ExtensionContext {
    isIdle(): boolean;           // Whether the agent is idle (not streaming)
    getContextUsage(): ContextUsage | undefined;
    getSystemPrompt(): string;
    compact(options?: CompactOptions): void;
    // ...
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

| Event                | S State | `isIdle()` | A Action           |
| -------------------- | ------- | ---------- | ------------------ |
| `tool_call`          | WORKING | false      | ❌ Silent           |
| `tool_result`        | WORKING | false      | ❌ Silent           |
| `agent_start`        | WORKING | false      | ❌ Silent           |
| `agent_end`          | IDLE    | true       | ⏳ Evaluate         |
| `before_agent_start` | IDLE    | true       | ✅ Inject directive |
| `session_start`      | IDLE    | true       | ✅ Check health     |

**Rule: A only acts when `ctx.isIdle() === true`.**

---

## Context Preservation: Solved by Design

A and S share the same session. The session IS the context bridge.

- S works → context accumulates in session history
- S becomes idle → `ctx.isIdle()` = true
- A acts at `before_agent_start` → reads same session history
- A injects directive → appears in S's next system prompt
- S wakes up → sees directive in context, acts on it

---

## Compaction: Preserving Knowledge Beyond Context Window

When Pi compacts context, it generates a summary of the conversation. This summary
contains the distilled essence of what was done, learned, and what's pending.

**Key insight:** Save compaction summaries to the database programmatically.
Even when tokens are exhausted, psypi preserves the most important key points.

### Compaction Events

| Event                    | When                       | Data Available                                                         |
| ------------------------ | -------------------------- | ---------------------------------------------------------------------- |
| `session_before_compact` | Before compaction starts   | `CompactionPreparation` — messages to summarize, file ops, token count |
| `session_compact`        | After compaction completes | `CompactionResult` — summary text, tokens before/after                 |

### CompactionResult

```typescript
interface CompactionResult {
    summary: string;              // LLM-generated summary
    firstKeptEntryId: string;     // UUID of first entry kept
    tokensBefore: number;         // Token count before compaction
    details?: {
        readFiles: string[];
        modifiedFiles: string[];
    };
}
```

### A's Behavior Based on Context Usage

From `ctx.getContextUsage()`:

```typescript
interface ContextUsage {
    tokens: number | null;       // Estimated context tokens
    contextWindow: number;       // Model's context window
    percent: number | null;      // Usage as percentage
}
```

**A's decision logic:**

| Context Remaining | A's Priority Action                                                          |
| ----------------- | ---------------------------------------------------------------------------- |
| < 10% (critical)  | **Preserve**: Update docs, code review, git commit — save what was done      |
| 10-30% (low)      | **Consolidate**: Summarize work, create compaction summary, commit           |
| 30-70% (moderate) | **Collaborate**: Review with S, ask questions about next steps, suggest work |
| > 70% (plenty)    | **Plan**: Evaluate tasks/issues, set directives for S, long-term planning    |

---

## A's Decision Flow at `before_agent_start`

```
A wakes up at before_agent_start
  │
  ├─ Check ctx.getContextUsage()
  │   │
  │   ├─ < 10% remaining → PRESERVE mode
  │   │   ├─ Update documentation
  │   │   ├─ Code review recent changes
  │   │   ├─ Git commit with summary
  │   │   └─ Save compaction summary to DB
  │   │
  │   ├─ 10-30% remaining → CONSOLIDATE mode
  │   │   ├─ Summarize what S accomplished
  │   │   ├─ Create directive for next session
  │   │   └─ Commit and document
  │   │
  │   ├─ 30-70% remaining → COLLABORATE mode
  │   │   ├─ Review tasks/issues with S
  │   │   ├─ Ask S about next steps
  │   │   ├─ Suggest work items
  │   │   └─ Set directive for S
  │   │
  │   └─ > 70% remaining → PLAN mode
  │       ├─ Evaluate all tasks/issues
  │       ├─ Check system health
  │       ├─ Create prioritized directives
  │       └─ Long-term planning
  │
  └─ Inject directive into system prompt
      └─ S wakes up with A's context
```

---

## What A Has Access To

When A acts at `before_agent_start`:

1. **Session history** — what S was doing (via `ctx.sessionManager`)
2. **System prompt** — current instructions (via `ctx.getSystemPrompt()`)
3. **Context usage** — tokens used/remaining (via `ctx.getContextUsage()`)
4. **Idle state** — whether S is working (via `ctx.isIdle()`)
5. **Database** — tasks, issues, directives, compaction history (via Gleam DB)
6. **Compaction summaries** — preserved knowledge from past context windows

---

## Database Schema: Compaction History

```sql
CREATE TABLE compaction_history (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    summary text NOT NULL,
    tokens_before integer,
    session_id text,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_compaction_history_created
    ON compaction_history(created_at DESC);
```

---

## Implementation Notes

### What Works Today
- `psypi-somatic-id` / `psypi-autonomic-id` — identity tools ✅
- `psypi-commit` — explicit A+S collaboration ✅
- `psypi-consult-autonomic` — S asks A for advice ✅
- Database tools (tasks, issues, meetings, skills) ✅
- Gleam core — type-safe, <100 lines per module ✅

### What Needs Implementation
1. `before_agent_start` hook — inject directives based on context usage
2. `agent_end` hook — evaluate and prepare directives
3. `session_compact` hook — save compaction summary to DB
4. A-decision logic — context-appropriate behavior (preserve/consolidate/collaborate/plan)
5. Compaction history table and queries

### Pi SDK Reference

```typescript
interface ExtensionContext {
    isIdle(): boolean;
    getContextUsage(): ContextUsage | undefined;
    getSystemPrompt(): string;
    compact(options?: CompactOptions): void;
    sessionManager: ReadonlySessionManager;
    ui: {
        notify(message: string, type?: "info" | "warning" | "error"): void;
        setStatus(key: string, text: string | undefined): void;
    };
}

interface ContextUsage {
    tokens: number | null;
    contextWindow: number;
    percent: number | null;
}

// Events A can hook into:
// - before_agent_start (primary injection point)
// - agent_end (evaluation point)
// - session_start (health check)
// - session_compact (save summary)
// - session_before_compact (prepare for compaction)
```
