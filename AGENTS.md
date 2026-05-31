# AGENTS.md — psypi Quick Guide

## Project Overview

**psypi** = Pi TUI + Gleam extension. Two AI agents (A-bot and S-bot) working together inside your terminal. All functionality via Pi tools — never run from shell, only inside the TUI.

## First Run / Fresh Setup

```bash
make setup          # full first-time setup (deps, DB, build, migrate, seed)
# or step by step:
gleam deps download
gleam clean && gleam build
gleam run -m simple_migrate
gleam run -m seed
node bin/ppi.mjs    # start Pi with psypi loaded
```

After any Gleam source change:
```bash
gleam clean && gleam build
node bin/ppi.mjs --generate-only   # or: gleam run -m extension_generator
```

Restart Pi:
```bash
pkill -f pi-coding-agent 2>/dev/null; cd /Users/jk/gits/hub/tools_ai/psypi && node bin/ppi.mjs
```

Inside Pi TUI, use `/psypi-my-id` to verify identity.

## Database

**PostgreSQL** is the source of truth. All state lives here: tasks, issues, skills, meetings, agent identity, memory, directives.

| Key              | Value                                                      |
| ---------------- | ---------------------------------------------------------- |
| **Host**         | `localhost`                                                |
| **Port**         | `5432`                                                     |
| **Database**     | `psypi`                                                    |
| **User**         | `postgres`                                                 |
| **Driver**       | `node_pg` (Gleam FFI to Node.js `pg`)                      |
| **Access layer** | `src/db.gleam` — all DB ops go through `with_connection()` |

Connect manually: `psql -d psypi`

### ⚠️ CRITICAL: Always use `-d psypi`

**NEVER run `psql` without `-d psypi`.** The default `psql` connects to a database named after your OS user (e.g. `jk`), which has many of the same tables but is a DIFFERENT database. Running queries without `-d psypi` will silently read/write the wrong data.

```bash
# CORRECT — always specify the database
psql -d psypi -c "SELECT COUNT(*) FROM review_findings;"

# WRONG — connects to `jk` database by default
psql -c "SELECT COUNT(*) FROM review_findings;"
```

The Gleam app (`db.gleam`) correctly defaults to `psypi` when `DATABASE_URL` is not set. The danger is only with manual `psql` commands — or if `DATABASE_URL` is set to the wrong database.

### Key Tables

| Table                 | Purpose                                                                            |
| --------------------- | ---------------------------------------------------------------------------------- |
| `agent_souls`         | Agent identity. `id_prefix` = `'A'` or `'S'`                                       |
| `agent_jobs`          | Prioritized work items per agent soul (NOT the same as user-facing `tasks` table!) |
| `agent_identities`    | Agent identity records                                                             |
| `agent_prefixes`      | Valid prefixes: A, S, G                                                            |
| `tasks`               | Task queue (PENDING/RUNNING/COMPLETED/FAILED)                                      |
| `issues`              | Bug tracker                                                                        |
| `skills`              | Skill registry (name, status, safety_score, content)                               |
| `meetings`            | A↔S structured discussions                                                         |
| `memory`              | Stored agent memories                                                              |
| `learning_insights`   | Learned knowledge                                                                  |
| `code_versions`       | File version history (auto-backup before edits)                                    |
| `psypi_config`        | Key-value config (`monitor_debounce_ms` default 300000)                            |
| `system_directives`   | ~~A→S injected directives~~ (DEPRECATED — anti-pattern, use sendMessage instead)   |
| `system_config`       | Legacy config table                                                                |
| `compaction_history`  | Context compaction summaries                                                       |
| `event_hooks`         | Hook registry                                                                      |
| `table_documentation` | Meta-table documenting schema (outdated, 24 rows)                                  |
| `system_reviews`      | System review records (code quality audits, architecture reviews)                  |
| `review_findings`     | Individual findings from system reviews (severity, category, evidence, impact)     |
| `review_comments`     | Comments on review findings                                                        |
| `review_labels`       | Labels/tags for review findings                                                    |
| `inter_reviews`       | A-bot's PDCA **Check** — inter-review of S's work between S sessions (code, docs, data, decisions). Not gated on commits. |

### `id_prefix`

Field in `agent_souls` table (`text UNIQUE NOT NULL`):
- `'A'` — Autonomic Agentbot (quality guardian: performs PDCA **Check** between S sessions — inter-review, behavior compliance, anti-stupidity)
- `'S'` — Somatic Agentbot (the doer: prompt-driven task execution, considers A suggestions thoughtfully)

A and S work like **alternating current** — never active simultaneously. When S finishes and goes idle, A wakes up and reviews. When A finishes, S may be woken. They alternate, never overlap. See README.md "The A/S Dialogue Model" for full details.

Used throughout hooks, seed, and directives to look up agent identity.

## Identity System

One pure function: `get_resolved_identity(ctx)`. The A/S prefix emerges from `ctx.isIdle()` at call time.

**NEVER CACHE THE ID.** It must be computed fresh every time.

ID format: `(G-)(A|S)-<project>-<source>-<model>[-<thinking_level>]`
- Example: `S-psypi-openrouter/owl-alpha`
- `G-` prefix when no `.git` found in cwd

Fields from live Pi runtime:
- `is_idle` ← `ctx.isIdle()` → determines A/S
- `model` ← `ctx.model.id`
- `source` ← `ctx.model.provider`
- `thinking_level` ← `ctx.model.thinkingLevel`
- `project` ← `ctx.cwd` directory name

Use `psypi-my-id` to get your current identity.

## Pi Tools (complete list)

All tools are defined as `PiToolCall` values in Gleam source. Source of truth: grep for `pub fn.*tool()` in `src/`.

### Agent Identity
| Tool           | Module           | Description                                        |
| -------------- | ---------------- | -------------------------------------------------- |
| `psypi-my-id`  | `agent_identity` | Get calling agent's full identity (ID, role, jobs) |
| `psypi-agents` | `agents`         | List all registered agents                         |

### Tasks
| Tool                  | Module | Description                               |
| --------------------- | ------ | ----------------------------------------- |
| `psypi-task-add`      | `task` | Create a task (title required)            |
| `psypi-tasks`         | `task` | List tasks (filter by status, project_id) |
| `psypi-task-complete` | `task` | Mark task completed by UUID               |

### Issues
| Tool                  | Module        | Description                                       |
| --------------------- | ------------- | ------------------------------------------------- |
| `psypi-issue-add`     | `issue_tools` | Create issue (title, description, severity, type) |
| `psypi-issues`        | `issue_tools` | List issues (filter by status, severity, type)    |
| `psypi-issue-count`   | `issue_tools` | Count issues matching filters                     |
| `psypi-issue-get`     | `issue_tools` | Get single issue by ID                            |
| `psypi-issue-resolve` | `issue_tools` | Resolve issue by ID                               |

### Skills
| Tool                 | Module  | Description                               |
| -------------------- | ------- | ----------------------------------------- |
| `psypi-skill-list`   | `skill` | List skills (filter by status)            |
| `psypi-skill-get`    | `skill` | Get skill by name                         |
| `psypi-skill-search` | `skill` | Search skills by name/description (ILIKE) |

Skills are stored in the `skills` table. Key fields: `name`, `status` (pending/approved/rejected/blocked/installed/uninstalled), `source` (clawhub/local/generated/imported), `safety_score`, `content` (jsonb with markdown body).

To load a skill at runtime: `read path="ppi_skills/[skill-name]/SKILL.md"`

### Meetings (A↔S discussions)
| Tool                     | Module    | Description                        |
| ------------------------ | --------- | ---------------------------------- |
| `psypi-meeting-add`      | `meeting` | Create meeting (topic, created_by) |
| `psypi-meetings`         | `meeting` | List meetings (filter by status)   |
| `psypi-meeting-get`      | `meeting` | Get meeting by ID                  |
| `psypi-meeting-say`      | `meeting` | Add opinion to meeting             |
| `psypi-meeting-opinions` | `meeting` | List opinions for meeting          |

### Memory & Learning
| Tool                  | Module     | Description                                         |
| --------------------- | ---------- | --------------------------------------------------- |
| `psypi-learn-save`    | `learning` | Save learning to memory (content, tags, importance) |
| `psypi-memory-search` | `memory`   | Search memories by keyword                          |

### Code Versioning
| Tool             | Module         | Description                                     |
| ---------------- | -------------- | ----------------------------------------------- |
| `psypi-doc-save` | `code_version` | Save file version (auto-backup before AI edits) |
| `psypi-doc-list` | `code_version` | List version history for a file                 |

### Commit
| Tool           | Module   | Description                                     |
| -------------- | -------- | ----------------------------------------------- |
| `psypi-commit` | `commit` | Commit with agent ID tagging (S-bot only)       |

### Reflection
| Tool             | Module     | Description                                                               |
| ---------------- | ---------- | ------------------------------------------------------------------------- |
| `psypi-areflect` | `areflect` | Parse [LEARN], [ISSUE], [TASK], [ISSUELIST] markers from text, save to DB |

### Broadcast
| Tool                   | Module      | Description                                            |
| ---------------------- | ----------- | ------------------------------------------------------ |
| `psypi-broadcast-send` | `broadcast` | Send broadcast message (message, priority, project_id) |
| `psypi-broadcasts`     | `broadcast` | List recent broadcasts                                 |

### Monitor / Autonomic
| Tool                      | Module       | Description                                                 |
| ------------------------- | ------------ | ----------------------------------------------------------- |
| `psypi-autonomic-status`  | `monitor_ai` | Monitor status and capabilities                             |
| `psypi-autonomic-health`  | `monitor_ai` | System health (failed tasks, open issues, activity)         |
| `psypi-autonomic-alerts`  | `monitor_ai` | Active alerts                                               |
| `psypi-autonomic-stats`   | `monitor_ai` | Statistics (review scores, response times, failure rate)    |
| `psypi-autonomic-suggest` | `monitor_ai` | Work suggestions (open issues, stale tasks, pending skills) |

### Directives (REMOVED — anti-pattern)
~~`psypi-direct-agentbot` and `psypi-clear-directives`~~ have been removed. A communicates with S via `sendMessage()` — S is an LLM that reads and understands natural language. No database intermediary needed. See "Lessons Learned" below.

### Consult
| Tool                      | Module         | Description         |
| ------------------------- | -------------- | ------------------- |
| `psypi-consult-autonomic` | `tool_consult` | S asks A for advice |

### Event Hooks
| Tool                 | Module        | Description               |
| -------------------- | ------------- | ------------------------- |
| `psypi-hooks-list`   | `event_hooks` | List all hooks and status |
| `psypi-hooks-active` | `event_hooks` | List only active hooks    |

### Stats
| Tool               | Module  | Description                                                 |
| ------------------ | ------- | ----------------------------------------------------------- |
| `psypi-stats-show` | `stats` | Project statistics (tasks, issues, skills, meetings counts) |

## Commit Workflow

`psypi-commit` is simple: it commits immediately with the agent ID appended.

**Flow:** S makes changes → S calls `psypi-commit("message")` → commit lands with `[AI:<agent-id>]` tag. No review gate. No two-phase flow. No `review_id` parameter.

After commit, S goes idle → A wakes → A performs inter-review (PDCA Check) → A saves findings to `inter_reviews` table → A sends results to S for the next cycle.

**Note:** S MUST use `psypi-commit` for all commits (not raw `git commit`). The agent ID tag is how we track who did what.

**⚠️ NEVER restart psypi by yourself.** Never run `pkill`, `node bin/ppi.mjs`, `npx`, or any Pi restart commands. That is A-bot's job or the human's job. S-bot dies when Pi restarts — that is normal. Do not try to resurrect yourself.

## A/S Dual-Agent Model — Core Design

### Biological Analogy

A and S borrow from the autonomic and somatic nervous systems. Like alternating current, they **never work simultaneously** — when one is active, the other is idle. They look like two bots but are actually the same Pi extension instance, differentiated only by `id_prefix` in the `agent_souls` table, which gives them different roles and jobs.

- **S (Somatic)**: The doer. Executes tasks, writes code, uses tools. Active when the user is interacting.
- **A (Autonomic)**: The checker. Focuses on PDCA's **Check** phase — comprehensive review of S's work across all PDCA dimensions (see "A-bot's Check Scope" below). Active only when S is idle.

### A-bot's Two Modes: Waiting and Working

A-bot has exactly two modes:

1. **Waiting mode** — S is working or has not been idle long enough. The debounce timer in extension.js counts down. Any S activity resets the timer.

2. **Working mode** — Triggered when the debounce timer fires (after `monitor_debounce_ms` of continuous S inactivity). A reads soul/jobs from DB, calls LLM via `call_monitor()`, and sends results to S.

**The debounce timer is the only technically non-trivial part of the entire A/S system.** Everything else uses Pi's built-in support (`pi.on()`, `pi.sendMessage()`, `ctx.ui.notify()`).

### Debounce Timer Logic (CRITICAL — read this until you understand it)

```
In extension.js, on each agent_end event:
  → CLEAR previous timer (if any)
  → SET new timer: setTimeout(callback, monitor_debounce_ms)

When timer fires (after monitor_debounce_ms of no new agent_end events):
  → CALL hook_on_agent_end.on_agent_end(ctx, pi)
  → Gleam code checks ctx_is_idle(ctx):
      → True:  run_a_bot() — read soul/jobs, call LLM, send result
      → False: do nothing (S became active during debounce period)

Key invariant: The timer only fires if S has been continuously idle
for the full debounce period. Any S activity (new agent_end event)
resets the timer. This guarantees A never interrupts S.
```

**Why this works**: Pi fires `agent_end` each time S finishes a turn. While S is working (multiple turns), each `agent_end` resets the timer. When S truly stops, no more `agent_end` events fire, and after `monitor_debounce_ms` of silence the timer fires. The `ctx_is_idle()` check at timer fire time is a safety net — if S somehow became active again during the debounce period (edge case), the hook silently does nothing.

### A-bot's Check Scope

A's primary job is **Check** across all PDCA dimensions, not just inter-review:

1. **Behavior compliance** — Did S follow the PDCA cycle? Was Plan done before Do? Did Check lead to Act? Because of the alternating-current model, A always has enough time to deeply inspect S's behavior patterns from the previous turn.

2. **Code quality & standards** — Code conventions, database conventions, Gleam type safety, FFI policy compliance, no fake Gleam patterns.

3. **Database quality** — Schema correctness, data integrity, type coverage (are all DB enum columns backed by Gleam types?), query patterns (no N+1, no missing indexes).

4. **Documentation quality** — Are skill docs up to date? Are ADRs recorded? Is the README current? Is the `table_documentation` accurate and complete?

5. **Inter-review** — The core of A's Check: A reviews whatever S just produced (code, docs, data, decisions) during A's autonomous time between S sessions. The "inter-" prefix is literal — it happens *between* S turns, not gated on commits or tied to specific tasks. Results MUST be saved to the `inter_reviews` database table. The message to S MUST reference the review ID so S can look it up, and SHOULD include a brief summary of key findings.

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

6. **Follow-up enforcement** — In the next alternating cycle, A MUST verify whether S responded to the previous round's check findings. Unaddressed findings are NOT allowed to slip through — A must escalate or re-raise them.

**Inter-review is the most structured and visible part of Check, but not the whole of Check.** A also reviews behavior compliance, database quality, documentation quality, and follows up on prior findings. Inter-review is simply the component with the clearest input (S's latest work) and the most structured output (`inter_reviews` table).

### Inter-Review vs System-Review

These are fundamentally different types of quality control, performed by different agents, at different times:

- **Inter-review** = A's **Check** in the PDCA cycle. A autonomously reviews whatever S just produced (code, docs, data, decisions) during the "inter" space between N sessions. The "inter-" prefix is literal — between S turns, not gated on commits, not 1:1 with tasks. Narrow in scope, immediate and actionable. This is A-primary job. Results go to the `inter_reviews` table.

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

- **System-review** = **End-of-line QC** (delayed, comprehensive). A thorough examination of the **entire system** across all dimensions — codebase architecture, database schema integrity, type coverage, documentation completeness, code duplication patterns, missing Gleam types, stale data, and accumulated technical debt. Like an annual audit that looks at the whole factory, not just one unit. Broad in scope but infrequent and deep. This is **S's job** (or an external AI invited by the user), NOT A's job. A is an added mechanism, not Pi's native component — complex tasks like system-review should be done by S, which has full Pi capabilities. A can, however, prompt S to do a system-review when A judges it is needed. Results go to `system_reviews` + `review_findings` tables.

| Aspect | Inter-Review | System-Review |
|--------|-------------|---------------|
| Nature | A's **Check** between S sessions (PDCA) | Comprehensive audit of entire system |
| Scope | What S just produced (code, docs, data, decisions) | Entire codebase + DB schema + docs + config |
| Timing | Between S sessions (every A cycle) | Periodic / on-demand |
| Who | A-bot (autonomous) | S-bot (or external AI invited by user) |
| Inputs | S's recent work | All source files, DB schema, docs, configs |
| Focus | Correctness, behavior, data quality | Architecture, type coverage, tech debt, completeness |
| Output | `inter_reviews` table | `system_reviews` + `review_findings` tables |
| PDCA role | **Check** | S doing a deep self-assessment |
| Analogy | Doctor checking vitals between shifts | Annual full-body scan |

### A-bot Communication Rules

- **A's thinking/progress** → `ctx.ui.notify()` — visible in TUI, does NOT trigger S
- **A's output for S** → `pi.sendMessage({customType: 'autonomic-wakeup', content: msg}, {triggerTurn: true})` — injects message into S's session, triggers a new S turn
- Both A and S can see each other's messages, forming a **dialogue pattern**

### Why A-bot Must Work

Without A-bot, psypi has no autonomous capability. All tools are passive — they only fire when S calls them. A-bot is the only component that proactively observes, reviews, and suggests. Without it, psypi is just a Pi extension with tools, not an autonomous system.

## Issues → Tasks: The Derivation Principle

**Issues (Plans) → Tasks.** This is the simple formula.

1. **Every plan starts from something new or something wrong** — that is an issue. Issues are the natural starting point for all work.

2. **Issues accept discussion through comments** — investigations, analysis, and plans live as comments on the issue. A database-backed issue with comments supports threaded discussion; a file-system plan does not.

3. **When the plan in an issue is discussed or felt sound enough, then comes the task.** Tasks are deduced from issues (plans). This is a logical and behavioral relationship, not a programmatic one — there is no foreign key from tasks to issues, and there should not be. The derivation is a matter of discipline, not schema.

**How agents should work**: When you (S or A) identify something new or something wrong, create an issue first. Use issue comments to investigate, analyze, and plan. When the plan is sound enough, create a task from it. This is how PDCA's Plan phase works — the issue IS the plan, and the task IS the do. A checks that S follows this flow: issues before tasks, discussion before action.

## The Review → Issue → Task Closed Loop

Review findings do not stay buried in `review_findings` — they flow into issues, which flow into tasks, which are reviewed again. This is the complete PDCA closed loop:

```
A-bot inter-review (PDCA Check between S sessions)
  → findings saved to inter_reviews table
  → significant findings also become issues
    → issue comments: root cause analysis, solution discussion, action plan
      → if conflicting views or needs structured dialogue: convene a meeting (psypi-meeting-add)
        → meeting produces consensus → feeds back into issue plan
      → when plan is sound: tasks created from the issue
        → task execution (S does the work)
          → next A cycle: inter-review checks S's work + follow-up on prior findings
            → new findings → new issues → new tasks → ...

S-bot system-review (periodic, on-demand)
  → comprehensive audit of entire system
  → findings saved to system_reviews + review_findings tables
  → significant findings become issues → same loop as above
```

**Critical rule**: Every significant finding from a review should become an issue. This is an agent behavior guideline, not a programmatic constraint — no new FK needed, just reference IDs in comments and descriptions. A finding without a corresponding issue is an orphan — it was observed but never acted upon.

**How agents should work**: After inter-review, A creates issues for significant findings. After system-review, S does the same. In the issue, analyze root cause, discuss solutions, and plan actions. When the plan is sound, derive tasks. During task execution, A's next inter-review checks progress and follows up on prior findings. The loop never breaks — every problem is tracked from discovery to resolution.

### Jobs Over Code

The closed loop is enforced through **jobs**, not programmatic constraints. A's jobs are loaded every time A activates. Each job is a behavioral guideline that A follows naturally:

| Priority | Category    | Job                                                                                                       |
| -------- | ----------- | --------------------------------------------------------------------------------------------------------- |
| 12       | closed_loop | Check if issue discussion needs a meeting: conflicting views or structured A-S dialogue → convene meeting |
| 11       | closed_loop | Check task execution follow-up: verify S addressed previous review findings                               |
| 10       | closed_loop | Check planned issues have tasks: when issue has sound plan, verify tasks exist                            |
| 9        | closed_loop | Check issues have discussion and plan: issues should have comments with analysis                          |
| 8        | closed_loop | Check review findings have corresponding issues: every finding should become an issue                     |
| 7        | definition  | Review own soul, responsibilities, and jobs — update if stale                                             |
| 6        | maintenance | Identify stale S tasks, suggest cleanup                                                                   |
| 5        | suggestion  | Suggest doer-jobs to S when context is right                                                              |
| 4        | unblock     | Unblock stuck S tasks                                                                                     |
| 3        | safety      | Anti-stupidity: catch dangerous S behavior                                                                |
| 2        | behavior    | Review S behavior: PDCA compliance                                                                        |
| 1        | review      | Inter-review S code changes                                                                               |

**Principle**: What you want to program, make a job instead. Jobs load every cycle, A reads them, A decides what to do. No FK constraints, no triggers, no stored procedures — just behavioral guidelines that A follows because they are in A's job list.

## agent_end Workflow (A-bot Activation)

When S finishes a turn, Pi fires `agent_end`:

1. **extension.js debounce** — `setTimeout(callback, debounceMs)` with timer dedup (clear previous timer before starting new one). Debounce value read from `psypi_config.monitor_debounce_ms` (cached after first read).
2. **After debounce timer fires** — `hook_on_agent_end.on_agent_end(ctx, pi)` checks `ctx_is_idle(ctx)`. If idle, calls `run_a_bot()`.
3. **run_a_bot()** reads soul+jobs+state from DB, builds prompts, calls `call_monitor()`, sends result via `pi_send_message()` with `triggerTurn: true`.

Changes to debounce take effect after restart (cached at module level in extension.js).

## Skills System

Skills are discoverable capability extensions. Stored in `skills` table, also available as markdown files in `ppi_skills/*/SKILL.md`.

**psypi-managed skills** (in `ppi_skills/`):
- `psypi-basics` — full cheat sheet for using psypi from TUI
- `psypi-dev` — developer guide
- `getting-started` — first-time user guide

**Other skill categories:** code-review, debugging, documentation, git-workflow, gleam-language, planning, security, testing, and more.

Skill statuses: `pending → approved → installed` (or `rejected`/`blocked`). Sources: `local`, `clawhub`, `generated`, `imported`.

## Architecture

```
Gleam source (src/*.gleam)
  ↓ gleam build
Compiled JS (build/dev/javascript/psypi/*.mjs)
  ↓ extension_generator.gleam composes text
extension.js (auto-generated, never hand-edit)
  ↓ Pi TUI loads it
Pi runtime (tools, hooks, commands)
```

- `bin/ppi.mjs` — bootstrapper, spawns Pi with psypi loaded
- `extension.js` — auto-generated, **never hand-edit**
- `src/extension_generator.gleam` — collects all PiToolCall values, generates extension.js
- `src/pi_tool_call.gleam` — PiToolCall, PiEventHook, PiCommandReg types
- `src/db.gleam` — database access layer (all DB ops)

## FFI Files

Hand-written JS files (only these 4):
- `src/pi_extension_ffi.mjs` — ctx.ui.notify, ctx.isIdle, pi_send_message, call_monitor, etc.
- `src/agent_identity_ffi.mjs` — check_git_exists
- `src/node_ffi.mjs` — get_env, get_project_id_env
- `src/time_utils_ffi.mjs` — date/time helpers

## Critical Rules

1. **Use Pi tools, not shell commands** — `/psypi-task-add`, not `psql` or CLI
2. **Use `psypi-commit`** for commits (not `git commit`) — commits immediately with agent ID tag. Inter-review happens after, during A's autonomous time.
3. **Read files first** — `read` then `edit` with exact match
4. **Never spawn Pi from Pi tools** — infinite loop crash
5. **Gleam types** — Enums are source of truth. Validate at boundary via `string_to_*()` → `Result`, never pass raw strings to SQL
6. **Clean build** — Always `gleam clean && gleam build` before building
7. **pnpm** — Not npm
8. **☠️ NO FAKE GLEAM** — Never create `pi_*.gleam` modules. Never write JS code as Gleam string literals. Use `.mjs` + `@external` FFI instead. This is the #1 source of bugs.

## ⚠️ GOLDEN RULE: No Hand-Written JS in Gleam Code

**NEVER write JavaScript code as Gleam string literals in non-generator modules.**

Three valid patterns:
1. **Gleam FFI (`@external`)** — `src/<module>_ffi.mjs` + `@external(javascript, "./<module>_ffi.mjs", "fn_name")`
2. **Gleam generator functions** — return JS text strings, compose in `extension_generator.gleam`
3. **Pi type constructors** — `lit()`, `from_param()`, `event_hook()`, `template()`

The ONLY hand-written JS files are the 4 `*_ffi.mjs` files. Everything else is auto-generated or uses proper FFI.

## Lessons Learned

### The `system_directives` Anti-Pattern

**Mistake:** Building a database table + Pi tools + hook injection pipeline for A→S communication, when `sendMessage()` already exists.

The `system_directives` table, `psypi-direct-agentbot` tool, `psypi-clear-directives` tool, and the `before_agent_start` directive-reading logic were all built to let A "inject directives into S's system prompt." This is over-engineering: S is an LLM that can read and understand messages from A directly via `sendMessage()`. No database intermediary, no special injection pipeline, no custom tool needed.

**Why it happened:** An AI confused "system prompt injection" (a Pi mechanism) with "communication" (a natural language act). A doesn't need to modify S's system prompt — A just needs to talk to S.

**Correct pattern:** A→S communication = `sendMessage()`. S reads A's message and decides what to do. Both bots read their own soul/jobs from DB via `id_prefix` for their identity, not for inter-agent communication.

## Key Files

| File                                  | Purpose                                                   |
| ------------------------------------- | --------------------------------------------------------- |
| `src/extension_generator.gleam`       | Collects all tools/hooks/commands, generates extension.js |
| `src/pi_tool_call.gleam`              | PiToolCall, PiEventHook, PiCommandReg types               |
| `src/db.gleam`                        | Database access layer                                     |
| `src/agent_identity.gleam`            | Identity resolution + enrichment from DB                  |
| `src/skill.gleam`                     | Skill CRUD + Pi tools                                     |
| `src/task.gleam`                      | Task CRUD + Pi tools                                      |
| `src/issue_tools.gleam`               | Issue CRUD + Pi tools                                     |
| `src/meeting.gleam`                   | Meeting CRUD + Pi tools                                   |
| `src/monitor_ai.gleam`                | Autonomic monitoring tools                                |
| `src/commit.gleam`                    | Simple commit with agent ID tagging                       |
| `src/simple_migrate.gleam`            | DB migration runner                                       |
| `src/seed.gleam`                      | Initial data seeder                                       |
| `AGENTS.md`                           | This file — agent quick guide                             |
| `ppi_skills/psypi-basics/SKILL.md`    | Full psypi cheat sheet                                    |
| `ppi_skills/getting-started/SKILL.md` | First-time user guide                                     |
| `docs/MONITOR-DEBOUNCE.md`            | Debounce configuration                                    |
| `Makefile`                            | Convenience targets                                       |
| `bin/setup.sh`                        | First-time setup script                                   |
