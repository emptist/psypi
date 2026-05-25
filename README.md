# psypi — Pi TUI + Gleam Extension

Pi extension that provides task management, code versioning, identity tracking, and autonomic monitoring — all built in Gleam and compiled to JavaScript.

## Architecture

```
Gleam source (src/*.gleam)
  ↓ gleam build
Compiled JS (build/dev/javascript/psypi/*.mjs)
  ↓ gleam run -m extension_generator
extension.js (auto-generated, never hand-edit)
  ↓ Pi TUI loads it
Pi runtime (tools, hooks, commands)
```

## Core Principle: ID is Everything

Every agent has an identity derived from `get_resolved_identity(ctx: IdentityContext)` — a pure function, one argument, no DB, no side effects. Gleam's type system guarantees this purity at compile time.

There is no "dual role system." The A- or S- prefix emerges from `ctx.isIdle()` at the moment of the call. The same agent can be S- now and A- a millisecond later. The ID is a snapshot of reality, not a label you stick on something.

```
IdentityContext:
  is_idle ← ctx.isIdle()        → A or S (THIS IS THE ONLY DIFFERENCE)
  model   ← ctx.model.id        → which intelligence is operating
  source  ← ctx.model.provider   → where it comes from
  project ← ctx.cwd              → which project context
  global  ← no .git found        → G- prefix for non-project dirs
```

**NEVER CACHE THE ID.** No variable, no database column, no session state, no "for convenience." The ID must be computed fresh every time because `ctx.isIdle()` is live — it changes moment to moment. A cached ID is a lie about who is acting.

## Build

```bash
gleam clean && gleam build
gleam run -m simple_migrate      # DB migrations
gleam run -m extension_generator # regenerate extension.js
```

## Pi Tools

All functionality is exposed as Pi tools — use them inside the TUI, never from shell.

| Tool                    | Description                 |
| ----------------------- | --------------------------- |
| `psypi-my-id`           | Get the calling agent's ID (S- or A- prefix) |
| `psypi-task-add`        | Add a task                  |
| `psypi-task-list`       | List tasks                  |
| `psypi-task-complete`   | Complete a task             |
| `psypi-doc-save`        | Save file version           |
| `psypi-doc-list`        | List file versions          |
| `psypi-issue-add`       | Report an issue             |

## Adding a Pi Tool

1. Define Gleam function in its module
2. Create `PiToolCall` value in that module
3. Import in `extension_generator.gleam`, add to `all_tools()`
4. `gleam clean && gleam build`
5. `gleam run -m extension_generator`

## The A/S Dialogue Model

psypi is a **multi-party conversation** between three participants: the human user, the Autonomic agentbot (A), and the Somatic agentbot (S). They can all see each other's words. It is a dialogue, not a pipeline.

### Alternating Current

Think of A and S like **alternating current** — they are never active at the same time. When S is working, A is watching. When S finishes and goes idle, A wakes up and reviews. When A finishes, S may be woken again. They alternate, never overlap.

This mirrors the biological **autonomic and somatic nervous systems**: the autonomic system monitors and regulates in the background; the somatic system executes voluntary actions. They don't fire simultaneously — they take turns, each responding to the other's state.

### A-bot: Quality Guardian, Not a Doer

A-bot's role is **observation, analysis, and communication**. A has infinite time between S's sessions — if A doesn't wake S, S sleeps forever. A should use that time to maintain the quality of the AI working process, not to execute tasks.

**What A does:**
- **Ongoing review**: After each S session, A reviews S's behavior — did S report issues before fixing them? Did S plan before acting? Did S update docs after modifying code? Did S update skills? Did S update `table_documentation` after schema changes?
- **Inter-review**: When `psypi-commit` is used, A reviews the specific code changes — are Gleam files real Gleam or polluted by handwritten JS strings? Are decoders matching DB column types? Are queries parameterized?
- **Anti-stupidity**: A catches dangerous S actions — deleting code before committing, trying to use sqlite3, trying to restart Pi, creating fake Gleam files, bypassing QC review
- **Suggest, don't command**: A gives reminders and suggestions, not instructions. S is intelligent — A should present findings and let S think for itself. S may have doubts or confusions, and can ask A back. This is a two-way dialogue, not a command chain.

**What A does NOT do:**
- Execute code changes (that's S's job)
- Research competitors or draft business proposals directly (A can suggest S do this when context is right, but A doesn't do it)
- Give generic wake-up messages ("hey S, continue working") — A's messages should contain specific, meaningful findings from review

**A's tool access**: A has access to all 36 Pi tools (task-add, issue-add, commit, etc.). A *can* add tasks, file issues, or commit. But A should use these sparingly — preferring to suggest S take action. The exception: when A needs to record a finding (filing an issue, adding a task) that S should address later.

### S-bot: The Doer

S-bot is the executor — it works inside the Pi agent lifetime, using tools to complete tasks. S follows instructions from the human user or suggestions from A.

**What S does:**
- Execute tasks using Pi tools
- Follow the human's direct instructions
- Consider A's suggestions and respond with thoughts, doubts, or questions
- Report issues before attempting fixes
- Plan before taking actions
- Update docs, skills, and `table_documentation` after changes

**What S does NOT do:**
- Self-review its own work (that's A's job)
- Restart Pi (that kills S — only A or the human should do this)
- Use sqlite3 (PostgreSQL is the database)
- Create fake Gleam files (JS strings in .gleam files)

### The Dialogue Protocol

```
Human → S: "Fix the decoder bug"
S works... S finishes, goes idle
A wakes up (after debounce):
  A reviews S's session:
    - Did S report the issue first? ✓
    - Did S plan before fixing? ✓
    - Is the Gleam code real (no JS strings)? ✓
    - Did S update docs? ✗ — forgot!
  A sends message to S:
    "The decoder fix looks good — real Gleam, parameterized queries.
     But you forgot to update table_documentation for the schema change.
     Also, the a_db_reader count_decoder had the same bug pattern."
S wakes up, reads A's message, thinks, responds:
  "Good catch on table_documentation — I'll update it now.
   The count_decoder — should I fix that too or file an issue?"
A responds:
  "Fix it now since you're already in that file. File an issue
   if you find more instances of the same pattern."
S acts on A's suggestion
```

This is a **two-way dialogue**. A doesn't command S — A observes, analyzes, and suggests. S thinks, questions, and decides. The cost is zero — A already sees S's conversation history, and S sees A's messages. No extra infrastructure needed.

### Doer-Jobs: A Suggests, S Executes

Some jobs like "research competitors" or "draft business proposals" are legitimate — but they're **S's jobs, not A's**. A may suggest these based on context (e.g., the project seems complete and S has capacity, or the project is commercial and needs market research). A decides *whether* to suggest; S decides *how* to execute.

### Reviewing Soul/Role/Jobs Definitions

Both bots should periodically review their own **database definitions** — soul, responsibilities, jobs — to check they still match reality. This is not "self-reviewing your own work" (that's A's job for S). It's reviewing whether your *definition* is accurate. For example: "My job says 'Research competitors' but I'm A-bot and can't execute that — this job definition is wrong and should be moved to S."

### System-Review vs Inter-Review

These are **completely different tasks**:
- **System-review**: A thorough review of the entire project — codebase, database, docs, architecture. Like the deep review that produced `REVIEW-2026-05-24-DEEP.md`. This is a major undertaking.
- **Inter-review**: A focused review of specific code changes, triggered by `psypi-commit`. Quick, targeted, per-change.

Do not confuse them. The database had them mixed up — S's "system-review" job was listed as "inter-review", which is wrong.

## Key Files

- `src/extension_generator.gleam` — collects tools/hooks/commands, generates extension.js
- `src/pi_tool_call.gleam` — PiToolCall, PiEventHook, PiCommandReg types
- `src/agent_identity.gleam` — identity resolution (single source of truth)
- `src/agent_identity_types.gleam` — IdentityContext, AgentIdentity types
- `src/db.gleam` — database access layer (all DB ops go through here)

## agent_end Workflow (A-S Communication)

When the S-worker finishes a turn, the `agent_end` event fires. The autonomic hook follows a strict 3-phase protocol:

### Phase 1: Immediate Feedback (debugging)
- `agent_end` fires → check `ctx.isIdle()` immediately
- If `True` → call `ctx.ui.notify()` right away with `[AUTONOMIC] S-worker is idle`
- This gives the user instant visual feedback that the autonomic worker detected the idle state
- **This is the debugging phase** — it confirms the hook fired and idle was detected

### Phase 2: Debounce Wait
- Read `monitor_debounce_ms` from `system_config` table (default: 300000ms = 5 minutes)
- Wait via `setTimeout(debounceMs)`
- Rationale: S-worker might receive a new prompt immediately. No need to wake it if it's already busy.

### Phase 3: Intelligent Composition
- After debounce, check `ctx.isIdle()` again
- If `False` → S-worker is busy, skip silently
- If `True` → call Monitor LLM via `callMonitor()` to compose a wake-up message
- Send via `pi_send_message(pi, 'autonomic-wakeup', msg, 'persistent')` with `triggerTurn: true`
- On LLM failure → send error message as persistent notification so S-worker can debug

**Key insight:** Phase 1 uses `ctx.ui.notify()` (transient toast) for immediate human feedback. Phase 3 uses `pi_send_message()` (persistent message) because by then the TUI session may be dormant and transient toasts are invisible.

**Current bug:** Phase 1 is missing from the code. The hook jumps straight to Phase 2 (debounce), so there's no immediate feedback. Additionally, `ctx.ui.notify()` calls in Phase 3 fire when the TUI is already dormant, making them invisible. The `pi_send_message` persistent messages still work but the LLM call (`callMonitor`) is returning empty output.

## Lesson: The `system_directives` Anti-Pattern

A previous AI built an entire communication pipeline for A→S coordination that was completely unnecessary:

- **`system_directives` table** — A writes directive rows, meant to be read by S's `before_agent_start` hook
- **`psypi-direct-agentbot` tool** — A uses this to insert directives into the table
- **`psypi-clear-directives` tool** — Clears active directives
- **`directive.gleam` module** — CRUD operations for the directives table
- **`before_agent_start` hook** — Was supposed to read directives and inject them into S's system prompt

**None of this was needed.** S is an LLM. It can read and understand messages from A directly via `sendMessage()`. The entire pipeline — database table, custom tools, hook injection — was over-engineering born from confusing "system prompt injection" (a Pi SDK mechanism) with "communication" (a natural language act between two LLMs).

The `before_agent_start` hook never actually read directives anyway — it returned a hardcoded identity string. The write end worked (A could insert rows), but the read end was never connected. A classic case of building infrastructure nobody uses.

**What replaced it:**
- A→S communication: `sendMessage()` — A sends a polite reminder, S reads it and decides what to do
- S's identity: `before_agent_start` now reads S's soul from `agent_souls WHERE id_prefix='S'` via `s_db_reader.gleam`
- A's identity: `agent_end` hook reads A's soul and jobs from `agent_souls` + `agent_jobs` joined by `id_prefix='A'`
- Both bots maintain their own soul and jobs in DB, joined by `id_prefix`, and can suggest adjustments through tasks, issues, or meetings

**The principle:** When two LLMs need to coordinate, use natural language messages. Don't build database-mediated injection pipelines. The LLM is the protocol.

## Docs

- `docs/AGENT-IDENTITY.md` — identity system design
- `docs/ARCHITECTURE.md` — core architecture
- `docs/AGENT-END-PLAN.md` — agent_end coordination design
- `docs/MONITOR-DEBOUNCE.md` — debounce configuration
- `AGENTS.md` — quick guide for AI agents
