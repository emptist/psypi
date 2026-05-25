# AGENTS.md — psypi Quick Guide

## Project Overview

**psypi** = Pi TUI + Gleam extension. Two AI agents (A-bot and S-bot) working together inside your terminal. All functionality via Pi tools — never run from shell, only inside the TUI.

## First Run / Fresh Setup

```bash
make setup          # full first-time setup (deps, DB, build, migrate, seed)
# or step by step:
gleam deps download
rm -rf build/ && gleam build
gleam run -m simple_migrate
gleam run -m seed
node bin/ppi.mjs    # start Pi with psypi loaded
```

After any Gleam source change:
```bash
rm -rf build/ && gleam build
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

### `id_prefix`

Field in `agent_souls` table (`text UNIQUE NOT NULL`):
- `'A'` — Autonomic Agentbot (event-driven, monitors system)
- `'S'` — Somatic Agentbot (prompt-driven, executes tasks)

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
| Tool           | Module           | Description                                         |
| -------------- | ---------------- | --------------------------------------------------- |
| `psypi-my-id`  | `agent_identity` | Get calling agent's full identity (ID, role, tasks) |
| `psypi-agents` | `agents`         | List all registered agents                          |

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

### Commit (QC Two-Phase)
| Tool           | Module   | Description                                     |
| -------------- | -------- | ----------------------------------------------- |
| `psypi-commit` | `commit` | Commit with Monitor review (see workflow below) |

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

## Commit Workflow (QC Two-Phase)

`psypi-commit` requires a review_id — no ticket, no commit.

**Phase 1:** Call `psypi-commit` without `review_id` → stages changes, sends review request to S-worker. A reviews diff, responds PASS/FAIL + score + review_id.

**Phase 2:** Call `psypi-commit` with `review_id` → performs actual git commit.

**Proper flow:** S makes changes → S calls `psypi-commit` (no review_id) → A reviews diff → A responds with review_id → S calls `psypi-commit` with review_id → commit lands.

**Note:** S MUST use `psypi-commit` for all commits. The two-phase review ensures A reviews S's work before it lands. There is no self-review loop — A is the reviewer, not S.

**⚠️ NEVER restart psypi by yourself.** Never run `pkill`, `node bin/ppi.mjs`, `npx`, or any Pi restart commands. That is A-bot's job or the human's job. S-bot dies when Pi restarts — that is normal. Do not try to resurrect yourself.

## agent_end Workflow (A-S Communication)

When S-worker finishes a turn, `agent_end` fires:

1. **Debounce Wait** — Read `monitor_debounce_ms` from `psypi_config` table (default: 300000ms = 5 min). Start `setTimeout`. No early exit, no idle check before timer.
2. **After debounce** — `hook_on_agent_end.gleam` checks `ctx.isIdle()`. If idle, reads soul from DB, composes wake-up via `call_monitor()`, sends via `pi_send_message` with type `autonomic-wakeup`.

Changes to debounce take effect immediately (read fresh from DB each event).

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

Hand-written JS files (only these 3):
- `src/pi_extension_ffi.mjs` — ctx.ui.notify, ctx.isIdle, pi_send_message, call_monitor, etc.
- `src/agent_identity_ffi.mjs` — check_git_exists
- `src/node_ffi.mjs` — get_env, get_project_id_env
- `src/time_utils_ffi.mjs` — date/time helpers

## Critical Rules

1. **Use Pi tools, not shell commands** — `/psypi-task-add`, not `psql` or CLI
2. **Use `psypi-commit`** for commits (not `git commit`) — mandatory Monitor review
3. **Read files first** — `read` then `edit` with exact match
4. **Never spawn Pi from Pi tools** — infinite loop crash
5. **Gleam types** — Enums are source of truth. Validate at boundary via `string_to_*()` → `Result`, never pass raw strings to SQL
6. **Clean build** — Always `rm -rf build/ && gleam build` before building
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
| `src/commit.gleam`                    | QC two-phase commit                                       |
| `src/simple_migrate.gleam`            | DB migration runner                                       |
| `src/seed.gleam`                      | Initial data seeder                                       |
| `AGENTS.md`                           | This file — agent quick guide                             |
| `ppi_skills/psypi-basics/SKILL.md`    | Full psypi cheat sheet                                    |
| `ppi_skills/getting-started/SKILL.md` | First-time user guide                                     |
| `docs/MONITOR-DEBOUNCE.md`            | Debounce configuration                                    |
| `Makefile`                            | Convenience targets                                       |
| `bin/setup.sh`                        | First-time setup script                                   |
