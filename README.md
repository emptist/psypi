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
gleam run -m seed                # seed data
gleam run -m extension_generator # regenerate extension.js
```

After any Gleam source change, rebuild and restart Pi:
```bash
gleam clean && gleam build
gleam run -m extension_generator
# Then restart Pi to load the new extension.js
```

## Pi Tools

All functionality is exposed as Pi tools — use them inside the TUI, never from shell.

| Tool                      | Description                                        |
| ------------------------- | -------------------------------------------------- |
| **Identity**              |                                                    |
| `psypi-my-id`             | Get the calling agent's full identity              |
| **Tasks**                 |                                                    |
| `psypi-task-add`          | Add a new task                                     |
| `psypi-tasks`             | List tasks (filter by status/project_id)           |
| `psypi-task-complete`     | Mark a task as completed                           |
| **Issues**                |                                                    |
| `psypi-issue-add`         | File a new issue                                   |
| `psypi-issues`            | List issues                                        |
| `psypi-issue-count`       | Count issues                                       |
| `psypi-issue-get`         | Get a single issue by ID                           |
| `psypi-issue-resolve`     | Resolve an issue                                   |
| **Docs/Versions**         |                                                    |
| `psypi-doc-save`          | Save a file version                                |
| `psypi-doc-list`          | List version history                               |
| **Skills**                |                                                    |
| `psypi-skill-list`        | List skills                                        |
| `psypi-skill-get`         | Get a skill by ID                                  |
| `psypi-skill-search`      | Search skills by name                              |
| **Meetings**              |                                                    |
| `psypi-meetings`          | List meetings                                      |
| `psypi-meeting-get`       | Get a meeting by ID                                |
| `psypi-meeting-opinions`  | List opinions for a meeting                        |
| `psypi-meeting-add`       | Create a new meeting                               |
| `psypi-meeting-say`       | Add an opinion to a meeting                        |
| **Learning/Memory**       |                                                    |
| `psypi-learn-save`        | Save a learning to memory                          |
| `psypi-memory-search`     | Search memories by keyword                         |
| **Broadcast**             |                                                    |
| `psypi-broadcast-send`    | Send a broadcast message                           |
| `psypi-broadcasts`        | List broadcast messages                            |
| **Reflection**            |                                                    |
| `psypi-areflect`          | Extract [LEARN], [ISSUE], [TASK] markers from text |
| **Autonomic**             |                                                    |
| `psypi-autonomic-status`  | Get Monitor status                                 |
| `psypi-autonomic-health`  | Get system health metrics                          |
| `psypi-autonomic-alerts`  | Get active alerts                                  |
| `psypi-autonomic-stats`   | Get Monitor statistics                             |
| `psypi-autonomic-suggest` | Get work suggestions                               |
| **Hooks**                 |                                                    |
| `psypi-hooks-list`        | List all event hooks                               |
| `psypi-hooks-active`      | List active hooks                                  |
| **Agents**                |                                                    |
| `psypi-agents`            | List all registered agents                         |
| **Stats**                 |                                                    |
| `psypi-stats-show`        | Show project statistics                            |
| **Other**                 |                                                    |
| `psypi-consult-autonomic` | Consult A-bot for difficult decisions              |
| `psypi-commit`            | Commit with agent ID tagging (S-bot only)          |

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

A and S look like two bots but are actually the same Pi extension instance, differentiated only by `id_prefix` in the `agent_souls` table, which gives them different roles and jobs.

### A-bot's Two Modes: Waiting and Working

A-bot has exactly two modes of existence:

1. **Waiting mode** — A stopwatch runs, counting how long S has been **continuously idle** (`ctx.isIdle() === true`, `ctx.isStreaming === false`). The stopwatch **resets to zero** on any S activity signal. The stopwatch **resets to zero** when A starts working.

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

**NEVER reduce debounce time as a "fix"** — the debounce duration is a design choice, not a bug. If A-bot doesn't fire, it means S hasn't been idle long enough. That is correct behavior.

### A-bot Communication Rules

- **A's thinking/progress** → `ctx.ui.notify()` — visible in TUI, does NOT trigger S
- **A's output for S** → `pi.sendMessage({customType: 'autonomic-wakeup', content: msg}, {triggerTurn: true})` — injects message into S's session, triggers a new S turn
- Both A and S can see each other's messages, forming a **dialogue pattern**

### Why A-bot Must Work

Without A-bot, psypi has no autonomous capability. All tools are passive — they only fire when S calls them. A-bot is the only component that proactively observes, reviews, and suggests. Without it, psypi is just a Pi extension with tools, not an autonomous system.

### A-bot: Quality Guardian, Not a MainDoer

A-bot's role is **observation, analysis, and communication**, it mainly works on the "check" phase in PDCA. A has infinite time between S's sessions — if A doesn't wake S, S sleeps forever. A should use that time to maintain the quality of the AI working process, not to execute tasks.

**What A does:**
- **Behavior review**: After each S session, A reviews S's behavior — did S report issues before fixing them? Did S plan before acting? Did S update docs after modifying code? Did S update skills? Did S update `table_documentation` after schema changes?
- **Inter-review**:  A reviews the specific code changes — are Gleam files real Gleam or polluted by handwritten JS strings? Are decoders matching DB column types? Are queries parameterized?
- **Anti-stupidity**: A catches dangerous S actions — deleting code before committing, trying to use sqlite3, trying to restart Pi, creating fake Gleam files, bypassing QC review
- **Suggest, don't command**: A gives reminders and suggestions, not instructions. S is intelligent — A should present findings and let S think for itself. S may have doubts or confusions, and can ask A back. This is a two-way dialogue, not a command chain.

**What A does NOT do:**
- Execute code changes (that's S's job)
- Research competitors or draft business proposals directly (A can suggest S do this when context is right, but A doesn't do it)
- Give disturbing wake-up messages ("hey S, continue working") — A's messages should contain specific, meaningful findings from review which will not disturb S's workflow.

**A's tool access**: A has access to all Pi tools (task-add, issue-add, commit, etc.). A *can* add tasks, file issues, or commit. But A should use these sparingly — preferring to suggest S take action. The exception: when A needs to record a finding (filing an issue, adding a task) that S should address later.

### S-bot: The Doer

S-bot is the executor — it works mainly on PDCA's "Plan","Do","Act" phases,inside the Pi agent lifetime, using tools to complete tasks. S follows instructions from the human user or suggestions from A.

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

> See `docs/DESIGN-inter-review-PDCA.md` for the full design document.

These are fundamentally different types of quality control:

- **Inter-review** = A-bot's **Check** in the PDCA cycle. It happens *between* S-bot sessions (the "inter-" prefix is literal — between turns). A reviews whatever S just did (code, docs, data, decisions) and files findings to the `inter_reviews` table. Then S wakes, reads A's feedback, and acts on it (PDCA's Act). Results go to the `inter_reviews` table.

  PDCA cycle:
  | Phase | Agent | What |
  |-------|-------|------|
  | **Plan** | S (or A suggests) | Decide what to do next |
  | **Do** | S | Write code, commit, use tools |
  | **Check** | A | Inter-review between S sessions |
  | **Act** | S | Address A's findings, improve |

  ```
  S plans & does → A checks (inter-review) → S acts → S plans & does → A checks → ...
  ```

- **System-review** = **End-of-line QC** (delayed, comprehensive). A thorough examination of the **entire system** across all dimensions — codebase architecture, database schema integrity, type coverage, documentation completeness, code duplication patterns, missing Gleam types, stale data, and accumulated technical debt. Like an annual audit that looks at the whole factory, not just one unit. Broad in scope but infrequent and deep. This is **S's job** (or an external AI invited by the user), NOT A's job. A is an added mechanism, not Pi's native component — complex tasks like system-review should be done by S. A can prompt S to do a system-review when A judges it is needed. Results go to `system_reviews` + `review_findings` tables.

| Aspect | Inter-Review | System-Review |
|--------|-------------|---------------|
| Nature | A's **Check** between S sessions (PDCA) | Comprehensive audit of entire system |
| Scope | What S just did (code, docs, data, decisions) | Entire codebase + DB schema + docs + config |
| Timing | Between every S-bot cycle | Periodic / on-demand |
| Who | A-bot (autonomous) | S-bot (or external AI invited by user) |
| Inputs | S's recent work | All source files, DB schema, docs, configs |
| Focus | Correctness, behavior, data quality | Architecture, type coverage, tech debt, completeness |
| Output | `inter_reviews` table | `system_reviews` + `review_findings` tables |
| PDCA role | **Check** | S doing a deep self-assessment |
| Analogy | Doctor checking vitals between shifts | Annual full-body scan |

## Key Files

- `src/extension_generator.gleam` — collects tools/hooks/commands, generates extension.js
- `src/pi_tool_call.gleam` — PiToolCall, PiEventHook, PiCommandReg types + JS code generators
- `src/pi_extension.gleam` — FFI imports for ctx, notify, config, time
- `src/pi_extension_ffi.mjs` — runtime FFI: call_monitor, sendMessage, notify, now_ms, get/set_config
- `src/agent_identity.gleam` — identity resolution (single source of truth)
- `src/agent_identity_types.gleam` — IdentityContext, AgentIdentity types
- `src/db.gleam` — database access layer (all DB ops go through here)
- `src/a_prompt_builder.gleam` — A-bot system/user prompt composition
- `src/hook_on_agent_end.gleam` — agent_end hook: idle_since gating + debounce + A-bot trigger
- `src/hook_on_before_agent_start.gleam` — S system prompt from DB
- `src/psypi_config.gleam` — psypi_config table reads/writes (debounce_ms, etc.)
- `src/system_prompt_types.gleam` — PromptComposition with context window budget
- `docs/DESIGN-inter-review-PDCA.md` — inter-review design: PDCA cycle, data flow, comparison with system-review

## agent_end Workflow (A-S Communication)

When the S-worker finishes a turn, the `agent_end` event fires. The autonomic hook follows a strict 3-phase protocol:

### Phase 1: Immediate Feedback (debugging)
- `agent_end` fires → check `ctx.isIdle()` immediately
- If `True` → call `ctx.ui.notify()` right away with `[AUTONOMIC] S-worker is idle`
- This gives the user instant visual feedback that the autonomic worker detected the idle state
- **This is the debugging phase** — it confirms the hook fired and idle was detected

### Phase 2: Debounce Wait + Timer Dedup
- Read `monitor_debounce_ms` from `psypi_config` table (default: 300000ms = 5 minutes) — cached at module level (DB read once)
- Start `setTimeout(debounceMs)` — but first `clearTimeout` any existing timer (prevents timer stacking)
- The `idle_since` timestamp is recorded when S first becomes idle, ensuring the debounce measures from the first idle moment, not the last
- Rationale: S-worker might receive a new prompt immediately. No need to wake it if it's already busy.

### Phase 3: Intelligent Composition
- After debounce, the Gleam handler checks `idle_since`: only proceeds if elapsed idle time >= debounce_ms
- Check `ctx.isIdle()` again
- If `False` → S-worker is busy, skip silently
- If `True` → clear `idle_since`, then call Monitor LLM via `callMonitor()` to compose a wake-up message
- Send via `pi_send_message(pi, 'autonomic-wakeup', msg, 'persistent')` with `triggerTurn: true`
- On LLM failure → send error message as persistent notification so S-worker can debug

**Key insight:** `setTimeout` callback uses `pi_send_message()` (persistent) because the TUI session may be dormant.

**Note:** A-bot's full workflow runs via `hook_on_agent_end.gleam` which handles idle_since debounce gating, DB reads, LLM call, and wake-up message composition inline.

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
