# PsyPI Architecture — Identity and Coordination

## Core Principle

**ID is everything. Everything is ID.**

The ID encodes:
- Role (A/S) — from `ctx.isIdle()`
- Model — from `ctx.model.id`
- Source — from `ctx.model.provider`
- Thinking level — from `ctx.model.thinkingLevel`
- Project — from `ctx.cwd`

## Identity: Pure Function

`semantic_id(ctx)` is a **pure function**:
- Same `IdentityContext` → same ID, always
- No side effects, no DB access, no hidden state

## A/S Dual Workflow

Two agentbots share one Pi extension:
- **A (Autonomic)**: Wakes when S is idle. Reads SOUL + jobs from DB, composes system prompt, calls LLM via `call_monitor`, sends polite reminders to S via `sendMessage()`
- **S (Somatic)**: The main coding agent. Reads SOUL from DB via `before_agent_start` hook. Receives A's messages as natural language.

### Communication: The LLM is the Protocol

A communicates with S via `sendMessage()`. S is an LLM — it reads and understands natural language. No database intermediary needed.

**Anti-pattern to avoid**: Building database-mediated communication pipelines (like the removed `system_directives` table). See README.md "Lesson: The system_directives Anti-Pattern".

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

## System Prompt Composition

Both A and S read their identity from the `agent_souls` table (joined by `id_prefix`):

- **A**: `hook_on_agent_end` → `a_db_reader` reads soul + jobs → `a_prompt_builder` composes prompt → `call_monitor` calls LLM
- **S**: `hook_on_before_agent_start` → `s_db_reader` reads soul → returns as system prompt override

System prompt is bounded by context window. `system_prompt_types.gleam` provides `PromptComposition` with priority-based budget management.

## File Structure

```
src/
  agent_identity.gleam          -- semantic_id computation + DB soul reader
  agent_identity_types.gleam    -- IdentityContext, AgentIdentity, IdentityError
  agents.gleam                  -- psypi-agents tool
  areflect.gleam                -- psypi-areflect: extract markers from text
  broadcast.gleam               -- psypi-broadcast-send/list
  code_version.gleam            -- psypi-doc-save/list
  command_listen.gleam          -- autonomic-listen command
  command_reload.gleam          -- autonomic-reload command
  db.gleam                      -- PostgreSQL connection pool (node_pg FFI)
  event_hooks.gleam             -- Hook trigger recording
  extension_generator.gleam     -- Generates extension.js from Gleam typed values
  file_utils.gleam              -- File read/write helpers
  hook_on_agent_end.gleam       -- A-S coordination: debounce + idle_since gating + call_monitor
  hook_on_agent_start.gleam     -- S session start event
  hook_on_before_agent_start.gleam -- S system prompt from DB
  hook_on_tool_call.gleam       -- tool call event
  hook_on_tool_result.gleam     -- tool result event
  inter_review.gleam            -- Inter-review meeting creation
  issue_db.gleam                -- Issue DB operations
  issue_tools.gleam             -- psypi-issue-* tools
  issue_types.gleam             -- Issue type definitions
  learning.gleam                -- psypi-learn-save
  main.gleam                    -- Entry point
  meeting.gleam                 -- psypi-meeting-* tools
  memory.gleam                  -- psypi-memory-search
  monitor.gleam                 -- Model recording
  monitor_ai.gleam              -- psypi-autonomic-* tools
  pi_extension.gleam            -- FFI imports: notify, ctx_*, now_ms, get/set_config
  pi_extension_ffi.mjs          -- FFI: call_monitor, sendMessage, notify, now_ms, get/set_config
  pi_tool_call.gleam            -- PiToolCall, PiEventHook, PiCommandReg types + JS generators
  psypi_config.gleam            -- psypi_config table reads/writes
  s_db_reader.gleam             -- S's DB reads: soul (id_prefix='S')
  seed.gleam                    -- DB seed data
  simple_migrate.gleam          -- Migration runner
  skill.gleam                   -- psypi-skill-* tools
  stats.gleam                   -- psypi-stats-show
  system_prompt_types.gleam     -- PromptComposition with context window budget
  system_review_types.gleam     -- System review and finding type definitions
  system_review_db.gleam        -- System review and finding DB operations
  system_review_tools.gleam     -- psypi-review-* tools
  task.gleam                    -- psypi-task-add/list/complete
  tool_commit.gleam             -- psypi-commit tool
  tool_consult.gleam            -- psypi-consult-autonomic tool
  a_context_utils.gleam         -- Context window parsing, time utilities
  a_db_reader.gleam             -- A's DB reads: soul, jobs, project state (id_prefix='A')
  a_prompt_builder.gleam        -- A's system/user prompt composition
```

## Typed Pipeline: Gleam → JS

The architecture ensures AIs write Gleam, not JS:

1. Domain modules define typed values: `PiToolCall`, `PiEventHook`, `PiCommandReg`
2. Generator functions (`to_js_text()`, `event_hook_to_js()`, `command_to_js()`) convert these to JS text
3. `extension_generator` collects and composes them into `extension.js`
4. FFI functions (`pi_extension_ffi.mjs`) handle runtime JS that can't be generated

No raw JS strings in Gleam files. No `PiRawHook` or `PiRawCommand` escape hatches.
