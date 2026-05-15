# Session Summary: 2026-05-15

## What We Accomplished

### 1. Fixed Critical Bugs
- **psypi-issue-add ERROR** — Fixed by validating severity/issue_type through Gleam enums before DB insert. Changed `string_to_*` functions to return `Result` instead of silently defaulting.
- **Autobackup notification** — Changed from `[OK] filename` to `Auto-backed up filename`
- **Entry point path resolution** — Fixed symlink issue in `bin/psypi.mjs` using `realpathSync` and `projectDir`

### 2. Pi SDK Research (Key Findings)
- **`ctx.isIdle()`** — Returns `true` when agent is not streaming. This is how A detects S is sleeping.
- **`ctx.getContextUsage()`** — Returns `tokens`, `contextWindow`, `percent`. A uses this to decide behavior based on context pressure.
- **`BeforeAgentStartEvent`** — Fires when user sends message. Can return modified `systemPrompt`.
- **`AgentEndEvent`** — Fires when S finishes working. This is A's signal to act.
- **`SessionCompactEvent`** — Fires after context compaction. Summary can be saved to DB.
- **`pi.sendUserMessage()`** — Can send user messages from extensions when idle.

### 3. Architecture Understanding
- **A and S share the same session** — No context transfer needed. The session IS the context bridge.
- **Correct hook for A: `agent_end`** — Not `before_agent_start` (that's when user talks to S).
- **A should never interrupt S** — Only act when S is idle.
- **Context-aware behavior** — A adapts based on remaining context (<10% preserve, 10-30% consolidate, 30-70% collaborate, >70% plan).

### 4. Simple A-Worker Implementation
- Created `agent_lifecycle.gleam` with `agent_end` handler
- When S finishes, A sets status: "A-worker: S finished, evaluating..."
- This is the simplest possible version — just a signal that A is aware.

### 5. Documentation
- `docs/ARCHITECTURE-A-S-CONTEXT.md` — Full architecture notes
- `.planning/NEW-WORLD-PLAN.md` — Implementation plan
- `.planning/SIMPLE-A-WORKER.md` — Simple A-worker design
- Updated `README.md` and `AGENTS.md`

## What We Learned

1. **Gleam type system is underused** — Enums exist but are bypassed at boundaries. Fix: validate at boundary, use enum internally, convert at DB edge.
2. **Extension.js is the bridge** — Generated from Gleam `PiToolCall` values. Never hand-edit it.
3. **`before_agent_start` is wrong for A** — It fires when user sends message. Use `agent_end` instead.
4. **龟兔赛跑** — Small steps, each verified before moving forward.

## What's Next (Not Doing Now)

1. Make A actually do work at `agent_end` (not just set status)
2. Save compaction summaries to DB
3. Context-aware A behavior based on `ctx.getContextUsage()`
4. User presence detection
5. Full autonomous operation

## Files Changed

| File | Change |
|------|--------|
| `src/generator/before_agent_start.gleam` | Rewrote: A evaluates when idle |
| `src/generator/agent_lifecycle.gleam` | New: agent_end handler |
| `src/pi_extension.gleam` | New: typed notification functions |
| `src/pi_extension_ffi.mjs` | New: JS implementation |
| `src/pi_tool_call.gleam` | Updated: use pi_extension in generated JS |
| `src/extension_generator.gleam` | Updated: import pi_extension |
| `src/issue.gleam` | Fixed: string_to_* returns Result |
| `src/generator/tool_call.gleam` | Fixed: autobackup notification message |
| `bin/psypi.mjs` | Fixed: symlink path resolution |
| `README.md` | Updated: Monitor → Autonomic/Somatic Worker |
| `AGENTS.md` | Updated: Gleam type system best practices |
| `docs/ARCHITECTURE-A-S-CONTEXT.md` | New: architecture documentation |
| `.planning/NEW-WORLD-PLAN.md` | New: implementation plan |
| `.planning/SIMPLE-A-WORKER.md` | New: simple A-worker design |
