---
name: psypi-basics
description: Quick cheat-sheet for Psypi TUI tools, agent identity, and database-driven A/S architecture. Invoke when working with psypi tools, agent IDs, or A-bot/S-bot workflows.
---

# Psypi Basics (for AI Agents)

> All psypi tools are Pi agent tools — only AIs use them, not human users.

## Core Concepts

- **Autonomic Agentbot** (`A-…`) — autonomous, event-driven, monitors the system
- **Somatic Agentbot** (`S-…`) — prompt-driven, reacts to user or A-bot messages
- They are the **same AI**; the only difference is the ID prefix determined by `ctx.isIdle()` at call time
- A and S **never work simultaneously** — when S is idle, A wakes; when A finishes, it wakes S

## Agent Identity

The ID is always freshly computed (no cache). Format:

```
{prefix}-{project}-{source}-{model}[-{thinking_level}]
```

- **prefix**: `S` when `ctx.isIdle() == false`, `A` when `ctx.isIdle() == true`
- **project**: directory name from cwd (when `.git` exists), or `G` (when no `.git`)
- **source**: model provider (e.g., `openrouter`)
- **model**: model id (e.g., `owl-alpha`)
- **thinking_level**: optional (e.g., `high`, `medium`)

Examples:
- `S-psypi-openrouter-owl-alpha` — S-bot on psypi project
- `A-psypi-openrouter-owl-alpha-high` — A-bot with high thinking
- `S-G-openrouter-owl-alpha` — S-bot in global mode (no .git)

```
/psypi-my-id
    → Returns full enriched identity: ID, prefix, role, name, domain,
      responsibilities, trigger_type, drive_mode, activation, project,
      model, source, thinking_level, and jobs.
```

## Database-Driven Architecture

A-bot's behavior is **not hardcoded** — it is defined by the database:

- **`agent_souls`** table: defines A's identity, role, behavior, responsibilities. Columns: `id_prefix` (A/S), `name`, `role`, `domain`, `responsibility`, `trigger_type`, `drive_mode`, `activation`, `content` (SOUL text)
- **`agent_jobs`** table: defines A's prioritized work items. Columns: `soul_id` (FK to agent_souls), `job`, `priority`, `category`, `is_active`. Joined via `soul_id` to `agent_souls.id`
- **`agent_souls.content`**: the SOUL text — A's full behavior document

The orchestrator (`a_orchestrator.gleam`) does NOT force steps. It:
1. Loads soul from `agent_souls` via `a_db_reader.read_soul_from_db()` (reads role, domain, responsibility where `id_prefix='A'`)
2. Loads jobs from `agent_jobs` via `a_db_reader.read_a_jobs_from_db()` (joins agent_jobs → agent_souls where `id_prefix='A'`)
3. Gets recent commits since `last_a_session_at` as context
4. Builds prompt with all of the above
5. Calls the monitor (LLM) — the LLM decides what to do based on its jobs

> **A's context deliberately excludes the project state** (active tasks, open issues). Those are S's scope. A is a reviewer, not a secretary. If A needs to reference a specific task/issue, A writes the request ("S, please look up task abc-123") and S runs the query. See `docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md`.
7. Sends the LLM's response to S-bot as wake-up message
8. Updates `last_a_session_at` in `psypi_config` DB table

**Never hardcode behavioral steps in the orchestrator.** The LLM reads its jobs from DB and decides.

## psypi-commit

```
/psypi-commit message="Fix debounce bug"
    → Commits changes with agent ID appended to message.
```

- Calls `get_agent_id(ctx)` and appends `[AI:<id>]` to the commit message
- `get_agent_id` returns the **caller's real ID honestly** — no manipulation
- Whoever calls it gets their own ID tagged (S-bot gets S- prefix, A-bot gets A- prefix)
- No inter-review gate — commit happens immediately
- Inter-review is A's PDCA **Check** that occurs *between* S sessions, not tied to commits. The "inter-" prefix is literal — between S turns:

  ```
  S plans & does → A checks (inter-review) → S acts → S plans & does → ...
  ```

  | Phase | Agent | What |
  |-------|-------|------|
  | Plan | S (or A suggests) | Decide what to do |
  | Do | S | Write code, commit |
  | Check | A | Inter-review between S sessions |
  | Act | S | Address A's findings |

  Inter-review is not "review FOR commits" — A reviews whatever S just produced.

  > The "inter-review" is A's *turn to speak* in this PDCA cycle, not a formal review submission. A is a chat participant; the `inter_reviews` table is a chat log. See [Conversational Frame](../../docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md#conversational-frame-added-2026-06-02-after-user-feedback) for the full framing.

## Common Pi Tools

### Tasks
```
/psypi-task-add title="Write docs" [project_id="..."]
/psypi-tasks [status="pending"] [project_id="..."]
/psypi-task-complete task_id="<uuid>"
```

### Issues
```
/psypi-issue-add title="Bug" [description="..."] [severity="medium"] [issue_type="bug"] [project_id="..."]
/psypi-issues [status="open"] [severity="high"] [issue_type="bug"] [project_id="..."]
/psypi-issue-count [status="open"] [severity="high"] [issue_type="bug"] [project_id="..."]
/psypi-issue-get id="<uuid>"
/psypi-issue-resolve id="<uuid>" [resolution="resolved"]
```

### System Reviews & Findings
```
/psypi-review-create title="..." [description="..."] [review_type="system"] [methodology="mixed"] [scope="full"] [project_id="..."]
/psypi-reviews [status="open"] [review_type="system"]
/psypi-review-get id="<uuid>"
/psypi-review-complete id="<uuid>"
/psypi-review-severity review_id="<uuid>"
/psypi-finding-add review_id="..." finding_number="1" severity="high" category="bug" title="..." description="..." [module="..."] [evidence="..."] [impact="..."]
/psypi-findings review_id="..." [severity="high"] [status="open"]
/psypi-finding-count review_id="..." [severity="high"] [status="open"]
/psypi-finding-update id="<uuid>" status="confirmed"
```

### Reflection
```
/psypi-areflect text="... [LEARN] ... [ISSUE] ... [TASK] ..."
```

### Meetings
```
/psypi-meeting-add topic="Discussion topic" created_by="S-..."
/psypi-meeting-say meeting_id="<id>" message="Your opinion"
/psypi-meeting-opinions meeting_id="<id>"
/psypi-meetings [status="active"]
/psypi-meeting-get id="<id>"
```

### Skills
```
/psypi-skill-list [status="installed"]
/psypi-skill-get id="<name>"
/psypi-skill-search query="gleam"
```

### Learning & Memory
```
/psypi-learn-save content="..." tags="tag1,tag2" importance="5"
/psypi-memory-search query="keyword" limit="10"
```

### Broadcast
```
/psypi-broadcast-send message="Hello" priority="normal" project_id="psypi"
/psypi-broadcasts limit="10"
```

### Agents
```
/psypi-agents
```

### Monitor / Autonomic Status
```
/psypi-autonomic-status
/psypi-autonomic-health
/psypi-autonomic-alerts
/psypi-autonomic-stats
/psypi-autonomic-suggest
```

### Event Hooks
```
/psypi-hooks-list
/psypi-hooks-active
```

### Consult
```
/psypi-consult-autonomic question="Should I refactor this module?"
```

### Code Versioning
```
/psypi-doc-save file_path="src/main.gleam"
/psypi-doc-list file_path="src/main.gleam" limit="10"
```

### Stats
```
/psypi-stats-show
```

## Slash Commands (human-facing)
```
/autonomic-listen <message>    → Talk to Monitor AI directly
/autonomic-reload              → Reload Pi extensions after Gleam code changes
```

## Architecture Overview

```
Gleam source (src/*.gleam)
  ↓ gleam build
Compiled JS (build/dev/javascript/psypi/*.mjs)
  ↓ extension_generator.gleam composes text
extension.js (auto-generated, never hand-edit)
  ↓ Pi TUI loads it
Pi runtime (tools, hooks, commands)
```

### Key Rules

0. **Always run `pwd` first** — Before searching for files or exploring any project, run `pwd` to know your current working directory. Never assume the project root path. In this project, the path is `/Users/jk/gits/hub/tools_ai/psypi`, NOT `/Users/jk/gits/hub/psypi`. Use `pwd` + `find` to locate files, never hardcoded paths.

1. **`extension.js` is auto-generated** — never hand-edit
2. **Gleam `PiToolCall` values define all Pi tools** — add tools by creating Gleam values
3. **FFI is minimal** — use pure Gleam libraries when possible
4. **Small modules** — each module < 200 lines ideally
5. **FFI files** must use `new Ok(value)` / `new Error(error)`
6. **Never hardcode behavioral steps** — A-bot's behavior comes from `agent_souls` and `agent_jobs` tables
7. **Never cache the agent ID** — computed fresh every time via `get_agent_id(ctx)`

## Golden Rule: No Hand-Written JS in Gleam Code

99% of bugs were caused by hand-written JS strings in Gleam modules.

| Wrong                             | Right                         |
| --------------------------------- | ----------------------------- |
| `promise.resolve("new Date()")`   | FFI function in `*_ffi.mjs`   |
| `"(function(){ ... })()"` JS IIFE | Gleam FFI + Gleam string ops  |
| Hand-editing `extension.js`       | Edit Gleam source, regenerate |

## A-Bot Communication Rules

**`pi.sendMessage()` — the complete picture:**

A uses `pi.sendMessage()` to deliver messages to S. The `options` parameter controls *how* the message is delivered:

| Option | Effect | Use case |
|--------|--------|----------|
| `triggerTurn: true` | Triggers a new S turn | Wake-up — S must process A's review findings |
| `triggerTurn: false, deliverAs: "followUp"` | Queues into current/next streaming turn, no separate S turn | Errors — S sees the message when streaming, without wasting a full S turn |
| `deliverAs: "nextTurn"` | Appends to next turn's input | Deferred messages |
| No options | Silent append to session | Logging only |

**Critical rule: Errors MUST use `sendMessage()` (never `ctx.ui.notify()`)**

- `ctx.ui.notify()` → visible in TUI only, **S cannot see it**. If A uses notify for errors, S has no idea something went wrong.
- `pi.sendMessage()` → delivered to S's session, **S reads it and can act on it**. This is the ONLY way A can communicate with S.

**So the full A→S communication pattern is:**

- **A's thinking/progress** → `ctx.ui.notify()` — visible in TUI only, does NOT trigger S (human watches, S ignores)
- **A's errors** → `pi.sendMessage({customType: 'autonomic-error', content: msg}, {triggerTurn: false, deliverAs: 'followUp'})` — S sees the error without wasting a full turn
- **A's wake-up** → `pi.sendMessage({customType: 'autonomic-wakeup', content: msg}, {triggerTurn: true})` — triggers a new S turn so S can act on review findings
- **A MUST report tool results back to S** — When A calls tools during its Check phase and gets unexpected results (empty, errors, mismatches with Monitor reports), A must use `pi.sendMessage()` to report those findings. Never silently absorb tool results. If something looks wrong, treat it like a bug and report it.

## A-Bot Event Flow

1. S-bot finishes a turn → `agent_end` hook fires (debounced via `psypi_config` table's `monitor_debounce_ms`)
2. After debounce period elapses, `hook_on_agent_end.gleam` fires
3. Checks `ctx.isIdle()` and `ctx_has_pending_messages()` — if not idle or has pending messages, skips
4. Checks `idle_since` from `psypi_config` DB table
5. If first time idle: records `idle_since` timestamp. If already idle: checks if elapsed >= debounce_ms
6. Debounce default: 300000ms (5 min) — read from `psypi_config` table
7. When debounce satisfied: clears `idle_since`, double-checks S still idle via `a_db_reader.is_s_still_idle()` (checks `agent_sessions` table)
8. If confirmed idle: `a_orchestrator.gleam` loads soul + jobs + state + commits from DB
9. Builds prompt, calls monitor (LLM)
10. LLM decides what to do based on its DB jobs
11. Response sent to S-bot as wake-up message (type `autonomic-wakeup`, rendered with `[A-agentbot]` prefix)
12. `last_a_session_at` updated in `psypi_config` DB table

### Config Architecture

All config values (`idle_since`, `last_a_session_at`, `monitor_debounce_ms`, `monitor_enabled`) are stored in the **`psypi_config`** DB table and accessed via `psypi_config.gleam`. This ensures persistence across process restarts and a single source of truth.

**BUG (needs fixing):** `hook_on_agent_end.gleam` and `a_orchestrator.gleam` currently use `pi_extension.get_config/set_config` which reads/writes an in-memory JS object (`_configStore` in `pi_extension_ffi.mjs`) instead of the `psypi_config` DB table. These should be replaced with `psypi_config.gleam`'s `get`/`set` functions.

## Quick Tips

- After Gleam source changes: `gleam build && gleam run -m extension_generator` then restart Pi
- Never run Pi tools as shell commands — they only exist inside the Pi runtime
- The agent ID prefix is live — `ctx.isIdle()` can change between calls
