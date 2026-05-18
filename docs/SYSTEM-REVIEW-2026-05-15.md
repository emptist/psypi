# psypi System Review — 2026-05-15

**Agent:** OWL (S-agentbot)
**Agent ID:** `S-psypi-psypi-019e2b28-d3b0-737a-978f-0ad79b7fb161`
**Model:** `openrouter/owl-alpha` (via OpenRouter, thinking level: medium)

---

## 1. What psypi Is

**psypi = Psyche + Pi** — a Pi TUI extension written in Gleam that adds a dual-agentbot AI coordination system on top of the Pi coding agent. It turns Pi from a single-shot coding assistant (works when user is present, stops when user leaves) into a system with two identities:

- **S-agentbot (Somatic)** — the normal Pi agent. Does actual work: coding, file edits, tool calls. Prompt-driven.
- **A-agentbot (Autonomic)** — a monitor/decider that acts when S is idle. Event-driven. Directs S via system prompt injection.

## 2. Architecture (Current State)

```
bin/psypi.mjs  →  generates extension.js from Gleam PiToolCall types  →  spawns Pi with extension
```

The Gleam code compiles to `.mjs` files in `build/dev/javascript/psypi/`. The `extension_generator.gleam` composes all `PiToolCall` values and event hook handlers into a single `extension.js` file. **This file is a build artifact — never hand-edited.**

### Event Hooks (7 registered, all thin):

| Hook                 | Current Behavior                                                 |
| -------------------- | ---------------------------------------------------------------- |
| `session_start`      | Records model, checks system health, sets status                 |
| `before_agent_start` | **Empty** — no A-agentbot trigger                                |
| `agent_start`        | Silent (comment only)                                            |
| `agent_end`          | Sets status: "A-agentbot: S finished, evaluating..."             |
| `tool_call`          | Auto-backup before `edit` tool calls                             |
| `tool_result`        | Detects errors, logs via `ctx.ui.notify` (no A-agentbot trigger) |
| `model_select`       | Records model changes                                            |

### 29+ Pi Tools across identity, tasks, issues, skills, meetings, memory, broadcast, reflection, monitor, event hooks, and directives.

## 3. Direction in the Last 15 Hours

The last 15 hours (35+ commits) show a **clear, focused trajectory** through three phases:

### Phase 1: Bug Fixes & Foundation
- **Gleam type system fix** (`issue.gleam`): Changed `string_to_*` functions from silently defaulting to returning `Result(Enum, Error)`.
- **Entry point path resolution** (`bin/psypi.mjs`): Fixed symlink resolution using `realpathSync`.
- **Autobackup notification**: Fixed from `[OK] filename` to `Auto-backed up filename`.
- **RLS policy fix**: Set `app.current_project_id` on DB connection.
- **tool_call hook fix**: Removed dangerous pattern matching that was blocking the `write` tool.

### Phase 2: A-Agentbot Architecture Exploration
Rapid iteration on how A should interact with S:

1. **Initial idea**: A injects 2 questions into S's system prompt at `before_agent_start` when S is idle (`ctx.isIdle()`).
2. **Pivot 1**: Realized `before_agent_start` fires when the **user** sends a message — not when A should act. Moved A's trigger to `agent_end`.
3. **Pivot 2**: Tried making A decide what questions to ask (not hardcoded).
4. **Final cleanup**: Removed A-agentbot trigger from `before_agent_start` entirely. A only acts at `agent_end` with a simple status message.

### Phase 3: Stabilization & Documentation
- Added `pi_extension.gleam` + `pi_extension_ffi.mjs` — typed notification helpers.
- Added `agent_lifecycle.gleam` — A's lifecycle hooks.
- Created extensive documentation.
- Added `psypi-basics` skill.
- Updated README and AGENTS.md with A/S terminology.

## 4. Deep Technical Assessment

### What's Done Right

1. **Gleam type safety is improving** — `issue.gleam` fix (Result types at boundaries) is the right pattern.
2. **Extension generator architecture is sound** — Gleam writes JS text, never hand-edited.
3. **Event hooks are thin** — each hook does one thing, <100 lines per module.
4. **The A/S identity system is clean** — IDs are pure functions, SOUL is in the `souls` table.
5. **`agent_end` is the right hook for A to act** — `ctx.isIdle()` returns `true` at this point.

### What's Incomplete / Has Issues

1. **A-agentbot is barely functional** — `agent_end` only sets a status message. No actual decision logic.
2. **`before_agent_start` is empty** — the primary mechanism for A to direct S (system prompt injection) is unused.
3. **No `session_compact` hook** — compaction history is lost when context is exhausted.
4. **No user presence detection** — A can't detect when the user has been absent for a while.
5. **`psypi-consult-autonomic` uses raw `complete()`** — bypasses Pi's agent loop, no tool access.
6. **`unwrapGleamResult` in extension.js** — fragile, depends on Gleam's compiled constructor names.
7. **Database connection per query** — `with_connection` connects/disconnects per query.
8. **`psypi_event_hooks` table** — `record_trigger()`/`record_error()` are never called by hooks.
9. **`bitwise_ops.gleam`** — test/learning artifact that shouldn't be in production.

## 5. Direction Assessment

The trajectory is **correct but early**. The team has:

✅ **Solved the hard architectural questions:**
- A and S share the same session (no context transfer needed)
- `agent_end` is A's signal (not `before_agent_start`)
- A should never interrupt S while working
- System prompt injection is the communication mechanism
- Database is shared state between A and S

✅ **Built the foundation:**
- 29+ working Pi tools
- Type-safe Gleam core
- Auto-generated extension.js
- Identity system with SOUL
- Directive system (set/clear/get)

❌ **Not yet built the intelligence:**
- A doesn't actually make decisions at `agent_end`
- No context-aware behavior based on `ctx.getContextUsage()`
- No compaction history preservation
- No proactive autonomous operation
- No user presence detection

## 6. Key Risks

1. **The `callMonitor` LLM call** — making raw `complete()` calls from within extension event handlers could interact poorly with Pi's agent loop. Should pass `ctx.signal` for abort awareness.
2. **No error recovery in hooks** — all hooks wrap everything in `try/catch` with silent failure.
3. **Shared database across projects** — `psypi-issues` returns issues from all projects.
4. **`bitwise_ops.gleam`** — should be removed or moved to `deprecated/`.

## 7. Summary

**psypi is a well-architected foundation for autonomous AI operation that has completed Phase 1 (bug fixes, identity system, tool infrastructure) and is at the threshold of Phase 2 (A-agentbot intelligence).** The last 15 hours show rapid, disciplined iteration. The main gap is that A-agentbot is currently a "hello world" — it sets a status message but doesn't actually think, decide, or direct. The next step is implementing the context-aware decision logic at `agent_end` and the directive injection at `before_agent_start`.
