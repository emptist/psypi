# A-S Communication System

## Core Principle

**The LLM is the protocol.** When two LLMs need to coordinate, use natural language messages.

For the full A/S dialogue model (alternating current, quality guardian role, dialogue protocol), see **README.md → "The A/S Dialogue Model"**.

A communicates with S via `sendMessage()`. S is an LLM — it reads and understands natural language directly. No database intermediary needed.

## A/S Dual-Agent Model — Core Design

### Biological Analogy

A and S borrow from the autonomic and somatic nervous systems. Like alternating current, they **never work simultaneously** — when one is active, the other is idle. They look like two bots but are actually the same Pi extension instance, differentiated only by `id_prefix` in the `agent_souls` table, which gives them different roles and jobs.

- **S (Somatic)**: The doer. Executes tasks, writes code, uses tools. Active when the user is interacting.
- **A (Autonomic)**: The checker. Focuses on PDCA's **Check** phase — inter-review, behavior review, anti-stupidity. Can plan but should not execute. Active only when S is idle.

### A-bot's Two Modes: Waiting and Working

A-bot has exactly two modes:

1. **Waiting mode** — A stopwatch runs, counting how long S has been continuously idle (`ctx.isIdle() === true` and `ctx.isStreaming === false`). The stopwatch **resets to zero** on any S activity signal. The stopwatch **resets to zero** when A starts working.

2. **Working mode** — Triggered when and only when the stopwatch reaches `monitor_debounce_ms`. A reads soul/jobs from DB, calls LLM via `call_monitor()`, and sends results to S.

**The stopwatch is the only technically non-trivial part of the entire A/S system.** Everything else uses Pi's built-in support (`pi.on()`, `pi.sendMessage()`, `ctx.ui.notify()`).

### Stopwatch Logic (CRITICAL)

```
Stopwatch state: psypi_config.idle_since (Unix ms timestamp, or "0" when not running)

On ANY S activity (agent_end while S is NOT idle, tool_call, user input):
  → stopwatch RESETS TO ZERO (idle_since = "0")

On agent_end AND ctx.isIdle()=true AND no pending messages:
  → IF idle_since = "0": START stopwatch (idle_since = now_ms()), DO NOT work yet
  → IF idle_since != "0": CHECK elapsed = now_ms() - idle_since
      → elapsed >= monitor_debounce_ms: RESET stopwatch, START WORKING
      → elapsed < monitor_debounce_ms: DO NOTHING, keep waiting

When A starts working: stopwatch RESETS TO ZERO
```

**Key invariant**: The stopwatch ONLY advances while S is continuously idle. Any S activity resets it. A working also resets it. This guarantees A never interrupts S.

**NEVER reduce debounce time as a "fix"** — the debounce duration is a design choice, not a bug.

### A-bot Communication Rules

- **A's thinking/progress** → `ctx.ui.notify()` — visible in TUI, does NOT trigger S
- **A's output for S** → `pi.sendMessage({customType: 'autonomic-wakeup', content: msg}, {triggerTurn: true})` — injects message into S's session, triggers a new S turn
- Both A and S can see each other's messages, forming a **dialogue pattern**

### Why A-bot Must Work

Without A-bot, psypi has no autonomous capability. All tools are passive — they only fire when S calls them. A-bot is the only component that proactively observes, reviews, and suggests. Without it, psypi is just a Pi extension with tools, not an autonomous system.

## The ID Encodes Identity

```
A-tools_ai-openrouter-owl-alpha-high
│        │         │         │     │
│        │         │         │     └─ thinking level (optional)
│        │         │         └─ model (from ctx.model.id)
│        │         └─ source/provider (from ctx.model.provider)
│        └─ project (from ctx.cwd)
└─ role: A=Autonomic, S=Somatic
```

`semantic_id(ctx)` is a pure function: same `IdentityContext` → same ID, always.

## How A-S Exchange Happens

### S-agentbot side (normal operation)
1. User sends prompt
2. `before_agent_start` fires → S reads SOUL from `agent_souls` WHERE `id_prefix='S'`
3. S processes prompt, calls tools, etc.
4. `agent_end` fires → S is done

### A-agentbot side (agent_end coordination)
1. `agent_end` fires → S finished
2. Wait for debounce period (configurable via `psypi_config` table)
3. Check `ctx.isIdle()` → is S still idle?
4. If NO → S got new work, skip
5. If YES → A reads SOUL + jobs from DB via `a_db_reader` (id_prefix='A')
6. A composes system prompt via `a_prompt_builder`
7. A calls LLM via `call_monitor`
8. A sends message to S via `sendMessage()`

### The Exchange
- A sends: `pi.sendMessage({ customType: 'autonomic-wakeup', content: msg })`
- S receives: the message appears in session as natural language
- S decides: what to do next based on its own SOUL and judgment

**No explicit handshake. No shared state. Just the message.**

## ctx.isIdle() — The Gate

`ctx.isIdle()` is the ONLY check needed:
- `true` → S is idle → A can speak
- `false` → S is busy → A stays silent

## Debounce

After `agent_end` fires, S might immediately get a new prompt. The debounce prevents A from interrupting.

- Default: 5 minutes (300000ms) from `psypi_config` table
- Fallback: 15 minutes (900000ms) if DB read fails

## Key Design Decisions

### Why sendMessage() instead of database-mediated directives?

The removed `system_directives` anti-pattern tried to use a database table + Pi tools + hook injection for A→S communication. This was over-engineered: S is an LLM that understands natural language. A just needs to talk to S. See README.md "Lesson: The system_directives Anti-Pattern".

### Why typed pipeline instead of raw JS strings?

The old architecture had hardcoded JS strings in Gleam files. The typed pipeline (`PiToolCall`, `PiEventHook`, `PiCommandReg`) ensures AIs write Gleam, not JS. Generator functions convert typed values to JS text through structured pattern matching.

### Why pass A-agentbot ID to call_monitor?

The LLM needs to know who it is. The ID tells the LLM: "You are A-tools_ai-openrouter-owl-alpha" — the Autonomic Agentbot. The LLM can then compose a contextually appropriate message.

## File Structure

```
src/
  agent_identity.gleam          -- semantic_id computation + DB soul reader
  agent_identity_types.gleam    -- IdentityContext, AgentIdentity, IdentityError
  hook_on_agent_end.gleam       -- A-S coordination: debounce + call_monitor
  hook_on_before_agent_start.gleam -- S system prompt from DB
  a_db_reader.gleam             -- A's DB reads: soul, jobs, project state (id_prefix='A')
  a_prompt_builder.gleam        -- A's system/user prompt composition
  a_context_utils.gleam         -- Context window parsing, time utilities
  s_db_reader.gleam             -- S's DB reads: soul (id_prefix='S')
  pi_tool_call.gleam            -- PiToolCall, PiEventHook, PiCommandReg types + generators
  extension_generator.gleam     -- Generates extension.js from Gleam typed values
  pi_extension_ffi.mjs          -- FFI: call_monitor, sendMessage, notify, renderers
  system_prompt_types.gleam     -- PromptComposition with context window budget
```
