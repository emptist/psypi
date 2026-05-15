# Psypi Dream-Team Architecture

## Core Insight: One AI, Two SOULs, Alternating Current

Psypi is **one AI** operating in two modes, like **alternating current**:

```
A-worker ←→ S-worker
   ↓           ↓
Events      System Prompt
   ↓           ↓
DB writes   DB reads
   ↓           ↓
notify()    directives
   ↓           ↓
User msg    System msg
```

They **never run at the same time** — they alternate. Each one's output becomes the other's input.

## The Two Workers

| Worker | Identity | Trigger | Input | Output |
|--------|----------|---------|-------|--------|
| **Autonomic** | `A-psypi-psypi` | Events/hooks | DB events, tool results | `ctx.ui.notify()` (user msg) + directives in DB (system prompt) |
| **Somatic** | `S-psypi-psypi-<session>` | System prompt | Directives injected by `before_agent_start` | Tool calls, events |

**Same brain. Same tools. Same codebase. Different entry points → different behavior.**

## The SOUL Mechanism

Each identity has its own SOUL in the `souls` table:
- **Monitor SOUL**: `{"focus": "system-health", "speed": 6, "quality": 10, "autonomy": 9}`
- **Worker SOUL**: `{"focus": "task-completion", "speed": 9, "quality": 7, "autonomy": 5}`

The SOUL shapes **how the AI thinks about itself**, which changes **what it prioritizes**, which changes **what it does**.

## Communication: Two Channels

### Channel 1: Direct Messages (A→S)
A-worker uses `ctx.ui.notify()` → appears as **user message** on screen
```
[Autonomic] System check: 3 failed tasks, 5 open issues. Please investigate.
```

### Channel 2: System Prompt Directives (A→S)
A-worker writes to `system_directives` table → `before_agent_start` injects into S-worker's system prompt
```
[DIRECTIVES]
1. [Autonomic] Investigate 3 failed tasks and 5 open issues
[END DIRECTIVES]
```

### Channel 3: Consultation (S→A)
S-worker calls `psypi-consult-autonomic` tool → A-worker responds with `[Autonomic]` marked advice

## The Cycle

```
1. Session starts → session_start hook fires
2. A-worker checks health → displays [Autonomic] message if issues
3. S-worker receives directives in system prompt
4. S-worker acts → produces events/tool results
5. A-worker wakes up via hooks → thinks → sets directives / sends messages
6. Cycle repeats...
```

## Key Principles

1. **Hooks are THIN** — just record events, no blocking logic
2. **Intelligence is in the LLM** — not in JavaScript regex patterns
3. **Small modules** — each Gleam file < 100 lines
4. **DB is the bridge** — A-worker writes, S-worker reads
5. **Two prompt types** — system prompt (invisible) and user message (visible)

## Tool Naming

| Tool | Who uses it | Purpose |
|------|------------|---------|
| `psypi-somatic-id` | Anyone | Get S-worker identity |
| `psypi-autonomic-id` | Anyone | Get A-worker identity |
| `psypi-direct-worker` | A-worker only | Set directives for S-worker |
| `psypi-clear-directives` | A-worker only | Clear active directives |
| `psypi-consult-autonomic` | S-worker only | Ask A-worker for advice |

## Anti-Infinite-Loop Safeguards
- Directives are **consumed** after injection (only once)
- Directives **expire** after 1 hour
- Max **3 active directives** at a time
- Deduplication via UNIQUE constraint

## File Structure

```
src/
├── extension_generator.gleam — Composes modules, generates extension.js
├── generator/
│   ├── tool_call.gleam — Thin hook (auto-backup only)
│   ├── before_agent_start.gleam — Read directives, inject into prompt
│   ├── session_start.gleam — Health check, display [Autonomic] message
│   ├── model_select.gleam — Record model changes
│   ├── tool_result.gleam — Detect errors, create directives
│   └── agent_lifecycle.gleam — Agent start/end logging
├── directive.gleam — Directive CRUD functions
├── agent_identity.gleam — Identity computation (pure function)
└── ... (other modules, each < 100 lines)
```

## Status (2026-05-14)

- [x] Small modules created (all < 40 lines)
- [x] Dangerous pattern matching removed from hooks
- [x] `[Autonomic]` prefix on A-worker messages
- [x] `psypi-direct-worker` tool (A→S communication)
- [x] `psypi-consult-autonomic` tool (S→A communication)
- [x] Directive system with SOUL context
- [x] Build and regeneration successful
- [ ] End-to-end cycle test (waiting for restart)
