# AGENTS.md — psypi Agent Guide

## Quick Start

```bash
make setup                      # first-time setup (deps, DB, build, migrate, seed)
gleam clean && gleam build      # after any Gleam source change
gleam run -m simple_migrate     # run DB migrations
gleam run -m seed               # seed agent souls and jobs
node bin/ppi.mjs                # start Pi with psypi loaded
```

After source changes: `gleam clean && gleam build && node bin/ppi.mjs --generate-only`

Verify: inside Pi TUI, use `/psypi-my-id` to check identity.

## Architecture

```
Gleam source (src/*.gleam)
  → gleam build → Compiled JS (build/dev/javascript/psypi/*.mjs)
  → extension_generator → extension.js (auto-generated, never hand-edit)
  → Pi TUI loads extension.js → 44 tools, 7 hooks, 2 commands
```

**Zero hand-written JS in Gleam code.** See [docs/ZERO-HANDWRITTEN-JS.md](docs/ZERO-HANDWRITTEN-JS.md).

## Database

| Key | Value |
|-----|-------|
| **Host** | `localhost:5432` |
| **Database** | `psypi` |
| **User** | `postgres` |
| **Driver** | `node_pg` (Gleam FFI to Node.js `pg`) |
| **Access** | `src/db.gleam` — all DB ops via `with_connection()` |

### CRITICAL: Always `psql -d psypi`

Default `psql` connects to the OS user database (e.g. `jk`), which has different data. Always specify `-d psypi`.

### Key Tables

| Table | Purpose |
|-------|---------|
| `agent_souls` | Agent identity. `id_prefix` = `'A'` or `'S'`. **Append-only** — use `save_soul_version()` |
| `agent_jobs` | Prioritized work items per soul. **Append-only** — use `save_job_version()` |
| `tasks` | Task queue (PENDING/RUNNING/COMPLETED/FAILED) |
| `issues` | Bug/feature tracker |
| `skills` | Skill registry (name, status, safety_score, content) |
| `meetings` | Cross-project AI communication (shared bulletin board) |
| `memory` | Stored agent memories |
| `learning_insights` | Learned knowledge |
| `code_versions` | File version history (auto-backup before edits) |
| `psypi_config` | Key-value config (`monitor_debounce_ms` default 300000) |
| `system_reviews` | System review records |
| `review_findings` | Individual findings from system reviews |
| `inter_reviews` | A-bot's inter-review of S's work between sessions |

### Append-Only Pattern

`agent_souls` and `agent_jobs` use append-only. Never UPDATE in place — always INSERT via `save_soul_version()` / `save_job_version()`. Two flags with distinct semantics:

- `is_archived` (default false) — **primary gate**. `true` = historical, never read by application. `false` = alive.
- `is_active` (default true) — **business flag**. Whether the row is enabled. NOT touched by versioning functions. If a row is un-archived later, is_active retains its original value.

Read path: `WHERE is_active = true AND is_archived = false`
Partial unique indexes: `WHERE is_active = true AND is_archived = false` (not just `is_active`)

**NEVER** use `UPDATE agent_souls SET content = ...` — use `save_soul_version()`.
**NEVER** let versioning functions change `is_active` — only `is_archived`.

## Identity System

One pure function: `get_resolved_identity(ctx)`. A/S prefix from `ctx.isIdle()` at call time.

**NEVER CACHE THE ID.** Compute fresh every time.

Format: `(G-)(A|S)-<project>-<source>-<model>[-<thinking_level>]`
- `G-` prefix when no `.git` found
- Fields from live Pi runtime: `is_idle`, `model`, `source`, `thinking_level`, `project`

## A/S Dual-Agent Model

A and S are like **alternating current** — never active simultaneously. One Pi extension instance, differentiated by `id_prefix`.

| Phase | Agent | What |
|-------|-------|------|
| **Plan** | S (or A suggests) | Decide what to do next |
| **Do** | S | Write code, commit, use tools |
| **Check** | A | Inter-review between S sessions |
| **Act** | S | Address A's findings, improve |

### A-bot (Autonomic) — The Doctor

- Owns PDCA **Check** phase
- Activates after debounce timer fires (S continuously idle for `monitor_debounce_ms`)
- Check scope: behavior compliance, code quality, DB quality, doc quality, inter-review, follow-up enforcement
- Communicates with S via `pi.sendMessage()` — never `ctx.ui.notify()` for errors
- **NEVER does system-review** — can prompt S to do one

### S-bot (Somatic) — The Patient

- Owns Plan, Do, Act phases
- Executes tasks, writes code, uses tools
- Can self-check, but Check is A's professional responsibility
- Does system-review **only when A or user asks** — never self-initiates
- **MUST wait for A's inter-review** before resolving issues or completing tasks

### Responsibility Split

| Concern | A-bot | S-bot |
|---------|-------|-------|
| Inter-review (PDCA Check) | Owns it | Never as primary |
| System-review (full audit) | Never | Owns it (on request) |
| Behavior/code/DB/doc quality | Owns it | — |
| Code execution, file edits, git | — | Owns it |

### Debounce Timer Logic

```
agent_end event → CLEAR previous timer → SET setTimeout(callback, debounce_ms)
agent_start/input → CLEAR timer (cancel A's pending activation)

When timer fires (after continuous idle):
  → on_agent_end(ctx, pi) → ctx_is_idle()? run_a_bot() : skip
```

Key invariant: timer ONLY fires after **continuous** idle. Any S activity cancels it. Never reduce debounce as a "fix".

### A-bot Communication

| Method | Effect | Use case |
|--------|--------|----------|
| `ctx.ui.notify()` | TUI only, S cannot see | A's thinking/progress |
| `sendMessage(triggerTurn: false, deliverAs: "followUp")` | S sees in stream | Errors |
| `sendMessage(triggerTurn: true)` | Triggers new S turn | Wake-up with review findings |

## Pi Tools (44)

All tools defined as `PiToolCall` values in Gleam. Source of truth: grep `pub fn.*tool()` in `src/`.

### Identity & Tasks & Issues
| Tool | Module | Description |
|------|--------|-------------|
| `psypi-my-id` | `agent_identity` | Get calling agent's full identity |
| `psypi-agents` | `agents` | List all registered agents |
| `psypi-task-add` | `task` | Create a task |
| `psypi-tasks` | `task` | List tasks (filter by status, project) |
| `psypi-task-complete` | `task` | Mark task completed by UUID |
| `psypi-issue-add` | `issue_tools` | Create issue |
| `psypi-issues` | `issue_tools` | List issues |
| `psypi-issue-count` | `issue_tools` | Count issues |
| `psypi-issue-get` | `issue_tools` | Get issue by ID |
| `psypi-issue-resolve` | `issue_tools` | Resolve issue by ID |

### Skills & Meetings & Memory
| Tool | Module | Description |
|------|--------|-------------|
| `psypi-skill-list` | `skill` | List skills |
| `psypi-skill-get` | `skill` | Get skill by name |
| `psypi-skill-search` | `skill` | Search skills |
| `psypi-meeting-add` | `meeting` | Create meeting |
| `psypi-meetings` | `meeting` | List meetings |
| `psypi-meeting-get` | `meeting` | Get meeting by ID |
| `psypi-meeting-say` | `meeting` | Add opinion |
| `psypi-meeting-opinions` | `meeting` | List opinions |
| `psypi-learn-save` | `learning` | Save learning |
| `psypi-memory-search` | `memory` | Search memories |

### Code & Commit & Reflection
| Tool | Module | Description |
|------|--------|-------------|
| `psypi-doc-save` | `code_version` | Save file version |
| `psypi-doc-list` | `code_version` | List version history |
| `psypi-commit` | `commit` | Commit with agent ID tag (S only) |
| `psypi-areflect` | `areflect` | Parse [LEARN]/[ISSUE]/[TASK] markers |

### Monitor & Review & Stats
| Tool | Module | Description |
|------|--------|-------------|
| `psypi-autonomic-status` | `monitor_ai` | Monitor status |
| `psypi-autonomic-health` | `monitor_ai` | System health |
| `psypi-autonomic-alerts` | `monitor_ai` | Active alerts |
| `psypi-autonomic-stats` | `monitor_ai` | Statistics |
| `psypi-autonomic-suggest` | `monitor_ai` | Work suggestions |
| `psypi-review-create` | `system_review_tools` | Create system review |
| `psypi-review-get` | `system_review_tools` | Get review |
| `psypi-reviews` | `system_review_tools` | List reviews |
| `psypi-review-complete` | `system_review_tools` | Complete review |
| `psypi-review-severity` | `system_review_tools` | Update finding severity |
| `psypi-finding-add` | `system_review_tools` | Add finding |
| `psypi-findings` | `system_review_tools` | List findings |
| `psypi-finding-count` | `system_review_tools` | Count findings |
| `psypi-finding-update` | `system_review_tools` | Update finding |
| `psypi-hooks-list` | `event_hooks` | List all hooks |
| `psypi-hooks-active` | `event_hooks` | List active hooks |
| `psypi-stats-show` | `stats` | Project statistics |
| `psypi-consult-autonomic` | `tool_consult` | S asks A for advice |
| `psypi-broadcast-send` | `broadcast` | Send broadcast |
| `psypi-broadcasts` | `broadcast` | List broadcasts |

## Commit Workflow

S makes changes → `psypi-commit("message")` → commit with `[AI:<agent-id>]` tag → S goes idle → A wakes → inter-review → A sends findings to S.

**S MUST wait for A's inter-review before resolving issues or completing tasks.** PDCA: Plan→Do→Check→Act. S does Plan+Do, A does Check, then S Acts.

**S MUST use `psypi-commit`** for all commits (not raw `git commit`).

**NEVER restart psypi from a tool.** That is A-bot's or the human's job.

## Issues → Tasks: The Derivation Principle

Issues (Plans) → Tasks. Every plan starts from something new or wrong — that is an issue. Issues accept discussion through comments. When the plan is sound, tasks are deduced. This is behavioral, not programmatic — no FK needed.

**Review → Issue → Task closed loop:**
```
A inter-review → findings → significant findings become issues
  → issue comments (root cause, plan) → tasks → execution
  → next A cycle: check + follow-up → new findings → ...
```

Every significant finding should become an issue. A finding without an issue is an orphan.

## Jobs Over Code

What you want to program, make a job instead. A's jobs load every cycle via `a_db_reader.read_a_jobs_from_db()`. A reads them, A decides what to do. No FK constraints, no triggers — just behavioral guidelines.

## Critical Rules

0. **NEVER delete data without explicit human confirmation** — No DELETE/DROP/TRUNCATE without asking. Data loss is permanent.
1. **NEVER use `psql` to modify DB directly** — All changes through migrations and Gleam code.
2. **Always `pwd` first** — Never assume project root path.
3. **Use Pi tools, not shell commands** — `/psypi-task-add`, not `psql`.
4. **Use `psypi-commit`** for commits — not `git commit`.
5. **Read files first** — `read` then `edit` with exact match.
6. **Never spawn Pi from Pi tools** — infinite loop crash.
7. **Gleam types** — Enums are source of truth. Validate at boundary via `string_to_*()` → `Result`.
8. **Clean build** — Always `gleam clean && gleam build`.
9. **pnpm** — Not npm.
10. **NO FAKE GLEAM** — Never create `pi_*.gleam` modules. Never write JS as Gleam string literals.

## No Hand-Written JS in Gleam Code

Three valid patterns:
1. **Gleam FFI (`@external`)** — `src/<module>_ffi.mjs` + `@external(javascript, ...)`
2. **Gleam generator** — `pi_tool_call.gleam` composes JS text from structured types
3. **Pi type constructors** — `param()`, `opt_param()`, `str()`, `int_val()`, `ctx()`, `pi()`, `event_hook()`, `template()`

Only 4 hand-written JS files exist: `pi_extension_ffi.mjs`, `agent_identity_ffi.mjs`, `node_ffi.mjs`, `time_utils_ffi.mjs`.

**Deleted types (do NOT reintroduce):** `JsLiteral(String)`, `FromParam(String)`, `CustomJs(String)`, `FnArg`, `lit()`, `from_param()`, `custom_js()`.

See [docs/ZERO-HANDWRITTEN-JS.md](docs/ZERO-HANDWRITTEN-JS.md) for the full guide.

## FFI Files

| File | Purpose |
|------|---------|
| `src/pi_extension_ffi.mjs` | ctx.ui.notify, ctx.isIdle, pi_send_message, call_monitor |
| `src/agent_identity_ffi.mjs` | check_git_exists |
| `src/node_ffi.mjs` | get_env, get_project_id_env |
| `src/time_utils_ffi.mjs` | date/time helpers |

## Key Files

| File | Purpose |
|------|---------|
| `src/extension_generator.gleam` | Collects tools/hooks/commands, generates extension.js |
| `src/pi_tool_call.gleam` | PiToolCall, PiEventHook, FnArgument, ParamSrc, HookGuard types |
| `src/db.gleam` | Database access layer |
| `src/agent_identity.gleam` | Identity resolution + enrichment from DB |
| `src/hook_on_agent_end.gleam` | A-bot trigger: debounce + idle detection |
| `src/simple_migrate.gleam` | DB migration runner |
| `src/seed.gleam` | Initial data seeder |

## Lessons Learned

### The `system_directives` Anti-Pattern

Built DB table + tools + hook injection for A→S communication, when `sendMessage()` already exists. S is an LLM that reads messages directly — no database intermediary needed. **Correct pattern:** A→S communication = `sendMessage()`.

### Append-Only for `agent_souls` / `agent_jobs`

Direct UPDATE destroyed history. Append-only preserves full evolution. Use `save_soul_version()` / `save_job_version()`. Versioning functions ONLY set `is_archived = true` on old rows — they never touch `is_active`. Partial unique indexes use `WHERE is_active = true AND is_archived = false`.

Apply append-only when: table holds evolving config/identity, you need change history, read-heavy. Do NOT apply when: write-once log (already append-only), transactional status transitions (UPDATE is correct).
