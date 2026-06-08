# psypi

Pi TUI extension with dual AI agents (A-bot and S-bot) for autonomous code quality. Built in Gleam, compiled to JavaScript, backed by PostgreSQL. [MIT License](LICENSE)

## Features

- **Dual-Agent Architecture** — A-bot (Autonomic) and S-bot (Somatic) alternate like alternating current, never active simultaneously
- **PDCA Cycle** — Plan (S) → Do (S) → Check (A) → Act (S) — continuous quality improvement
- **44+ Pi Tools** — Identity, tasks, issues, skills, meetings, learning, code versioning, system review, monitoring, and more
- **Zero Hand-Written JS** — All JavaScript is either compiled from Gleam, generated from structured types, or in FFI bridge files
- **Append-Only Versioning** — Agent souls and jobs preserve full evolution history
- **Auto Code Backup** — Files are automatically versioned before edits via tool_call hook
- **System Prompt Composition** — Token-budget-aware prompt assembly from soul, jobs, concepts, and skills
- **30+ Skills** — Development, architecture, code quality, debugging, security, and platform skills
- **Monitoring & Alerts** — Health metrics, alert system, model quality tracking, and work suggestions
- **Inter-Review** — A-bot reviews S-bot's work between sessions, saving findings to database
- **Broadcast & Meetings** — Cross-agent communication via shared bulletin board and structured discussions
- **Reflection System** — Parse `[LEARN]`/`[ISSUE]`/`[TASK]` markers from text and save to database

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

**Zero hand-written JS.** All JavaScript is either compiled from Gleam, generated from structured types, or in FFI bridge files. See [Zero Hand-Written JS](docs/ZERO-HANDWRITTEN-JS.md) for the full guide.

```
Gleam source (src/*.gleam)
  → gleam build → Compiled JS (build/dev/javascript/psypi/*.mjs)
  → extension_generator → extension.js (auto-generated, never hand-edit)
  → Pi TUI loads extension.js → 44 tools, 7 hooks, 2 commands
```

### Three-Layer Code Generation

1. **FFI Layer** (`*_ffi.mjs`): Only 4 files — `pi_extension_ffi.mjs`, `agent_identity_ffi.mjs`, `node_ffi.mjs`, `time_utils_ffi.mjs`
2. **Generator Layer** (`pi_tool_call.gleam`): Structured types (`PiToolCall`, `PiEventHook`, etc.) that mechanically convert to JS text
3. **Business Logic Layer** (all other `.gleam` files): Pure Gleam, compiled by the Gleam compiler

### Structured Type System

- `ParamSrc` (8 variants): WHERE to get a value from Pi callbacks
- `FnArgument` (6 variants): WHAT to pass to handlers
- `HookGuard` (3 variants): WHEN a hook executes
- `ResultFormat` (2 variants): HOW to format output
- `HookSuccessAction` / `HookErrorAction`: What to do on success/error

**Deleted escape hatches:** `JsLiteral`, `FromParam(String)`, `CustomJs(String)`, `FnArg`, `lit()`, `from_param()`, `custom_js()` — all deleted to prevent hand-written JS in Gleam code.

## The A/S Dual-Agent Model

A and S are like **alternating current** — never active simultaneously. One Pi extension instance, differentiated by `id_prefix`.

| Phase | Agent | What |
|-------|-------|------|
| **Plan** | S (or A suggests) | Decide what to do next |
| **Do** | S | Write code, commit, use tools |
| **Check** | A | Inter-review between S sessions |
| **Act** | S | Address A's findings, improve |

### A-bot (Autonomic) — The Doctor

- Activates only after `monitor_debounce_ms` (default 5 minutes) of **continuous** S idle
- Any S activity (agent_start, input, tool_call) **cancels** the debounce timer
- Cannot call any `psypi-*` tools — runs via `call_monitor()` (single-shot LLM call)
- Communicates with S via `pi.sendMessage()` — the LLM reads natural language
- Saves inter-reviews to `inter_reviews` table
- Strips hallucinated IDs from its own responses before saving

### S-bot (Somatic) — The Patient

- Runs through the standard Pi agent loop with all 44 tools
- Reads its SOUL from `agent_souls` via `before_agent_start` hook
- Receives A's messages as natural language in its conversation stream
- Must wait for A's inter-review before resolving issues or completing tasks

### A-S Communication Protocol

| Method | Effect | Use Case |
|--------|--------|----------|
| `ctx.ui.notify()` | TUI only, S cannot see | A's internal thinking/progress |
| `pi.sendMessage(triggerTurn: false, deliverAs: "followUp")` | S sees in next turn | Errors |
| `pi.sendMessage(triggerTurn: true)` | Triggers new S turn | Wake-up with review findings |

### Debounce Timer Logic

```
agent_end event → CLEAR previous timer → SET setTimeout(callback, debounce_ms)
agent_start/input → CLEAR timer (cancel A's pending activation)

When timer fires (after continuous idle):
  → on_agent_end(ctx, pi) → ctx_is_idle()? run_a_bot() : skip
```

## Identity System

Every agent has a dynamic identity: `(G-)(A|S)-<project>-<source>-<model>[-<thinking_level>]`

- **A/S prefix** emerges from `ctx.isIdle()` at call time — never cached
- **G- prefix** when no `.git` found (global/non-project context)
- Project, model, source derived from live Pi runtime state
- Identity is a **pure function**: `semantic_id(ctx)` — same input always produces same output
- Project URL resolved fresh from `process.cwd()` on every call, never cached

### Enriched Identity

`get_enriched_identity(ctx)` returns:
- Full semantic ID
- Soul data from DB (role, name, domain, responsibilities, trigger_type, drive_mode, activation)
- Jobs from DB (priority-ordered list)
- Runtime data (project, model, source, thinking_level)

## Pi Agent Tools (44)

| Category | Tools |
|----------|-------|
| **Identity** | `psypi-my-id`, `psypi-agents` |
| **Tasks** | `psypi-task-add`, `psypi-tasks`, `psypi-task-complete` |
| **Issues** | `psypi-issue-add`, `psypi-issues`, `psypi-issue-count`, `psypi-issue-get`, `psypi-issue-resolve` |
| **Code Versions** | `psypi-doc-save`, `psypi-doc-list` |
| **Skills** | `psypi-skill-list`, `psypi-skill-get`, `psypi-skill-search` |
| **Meetings** | `psypi-meetings`, `psypi-meeting-get`, `psypi-meeting-opinions`, `psypi-meeting-add`, `psypi-meeting-say` |
| **Learning/Memory** | `psypi-learn-save`, `psypi-memory-search` |
| **Broadcast** | `psypi-broadcast-send`, `psypi-broadcasts` |
| **Reflection** | `psypi-areflect` — parse `[LEARN]`/`[ISSUE]`/`[TASK]`/`[ISSUELIST]` markers from text |
| **Autonomic** | `psypi-autonomic-status`, `psypi-autonomic-health`, `psypi-autonomic-alerts`, `psypi-autonomic-stats`, `psypi-autonomic-suggest` |
| **System Review** | `psypi-review-create`, `psypi-review-get`, `psypi-reviews`, `psypi-review-complete`, `psypi-review-severity`, `psypi-finding-add`, `psypi-findings`, `psypi-finding-count`, `psypi-finding-update` |
| **Hooks** | `psypi-hooks-list`, `psypi-hooks-active` |
| **Other** | `psypi-commit`, `psypi-consult-autonomic`, `psypi-stats-show` |

All tools are used inside the Pi TUI, never from shell.

## Event Hooks (7)

| Hook | Event | Type | Description |
|------|-------|------|-------------|
| `tool_call` | `tool_call` | Regular | Auto-backs up files before edits |
| `session_start` | `session_start` | Regular | Records current model |
| `model_select` | `model_select` | Regular | Records model change |
| `before_agent_start` | `before_agent_start` | System Prompt | Injects S's soul from DB as system prompt |
| `agent_start` | `agent_start` | Regular | Records trigger in event_hooks table |
| `agent_end` | `agent_end` | **Debounced** | A-bot trigger: debounce + idle detection + call_monitor |
| `tool_result` | `tool_result` | Regular | Detects tool errors and reports via pi.sendMessage |

### Hook Tracking

Each hook's trigger count, last triggered time, and error count are tracked in the `psypi_event_hooks` table. After 5 errors, a hook's status changes to `'error'`.

### Message Renderers

- `autonomic-wakeup`: Accent/Warning colors, shows A's messages to S
- `autonomic-error`: Error/Error colors, shows A's error reports

## System Prompt Composition

### PromptComposition System

- `PromptComponent`: kind (Soul/Directive/Skill/ContextFile), priority, content, estimated_tokens
- `ContextBudget`: total_tokens, used_tokens
- `compose_within_budget()`: sorts by priority, keeps components until budget exhausted
- Priority order: Critical (SOUL) > High (jobs/concepts) > Medium (skills) > Low (context files)
- Token estimation: `string.length(text) / 4 + 1`

### A-bot Prompt Building

`a_prompt_builder` composes:
1. Soul content (Critical priority)
2. Key concepts from `key_concept_definitions` table (High priority)
3. A's jobs from `agent_jobs` table (High priority)

User prompt includes: working directory, context usage, project state, S-bot's recent commits, S-bot's full conversation log.

### S-bot Prompt

S reads its soul from `agent_souls WHERE id_prefix='S'` via `before_agent_start` hook, which returns it as a system prompt override.

## Key Concepts System

The `key_concept_definitions` table provides a shared vocabulary:
- `concept_key`: unique identifier
- `term`: human-readable name
- `definition`: what it means
- `context`: when/where to apply
- `examples`: correct usage
- `anti_patterns`: common mistakes
- `related_concepts`: connections to other concepts
- `category`: grouping (e.g., 'database')

A-bot loads database-category concepts to verify S's work against correct field semantics.

## Skills System (30+)

| Category | Skills |
|----------|--------|
| **Development** | `psypi-dev`, `gleam-language`, `gleam-pi-extension-patterns`, `gleam-pi-tool-generator` |
| **Architecture** | `context-engineering`, `planning-and-task-breakdown`, `create-plans` |
| **Code Quality** | `code-review-and-quality`, `code-simplification`, `test-driven-development` |
| **Tools** | `create-hooks`, `create-slash-commands`, `create-subagents`, `create-agent-skills`, `create-meta-prompts` |
| **Platform** | `pi-platform`, `monitor`, `getting-started`, `setup-ralph` |
| **Operations** | `debugging-and-error-recovery`, `debug-like-expert`, `troubleshoot-tool-blocked`, `unblock-pi-tools` |
| **Security** | `security-and-hardening` |
| **Git** | `git-workflow-and-versioning` |
| **Documentation** | `documentation-and-adrs` |
| **Misc** | `build-pi-extension`, `the-pirate-bay`, `psypi-basics` |

Skills in the `skills` table have:
- `source`: Clawhub, Local, Generated, Imported, AiBuilt
- `status`: Pending, Approved, Rejected, Blocked, Installed, Uninstalled
- `safety_score`: Integer (0-100)
- `content`: Full skill content (JSONB)
- `version`: Version string

Skills use append-only versioning via `save_skill_version()`.

## Monitoring & Autonomic System

### Health Metrics

- Failed tasks count
- Open issues count
- Activities in last hour
- DB connectivity check

### Alert System

- Failed tasks needing attention
- Open issues (by severity)
- Critical issues requiring resolution
- Stale pending tasks (>7 days)

### Model Quality Tracking

- Total reviews in last 24 hours
- Average review score
- Average response time
- Failure count

### Work Suggestions

The monitor suggests work based on:
- Open issues grouped by severity
- Stale tasks pending >7 days
- Pending skills needing review

### Safety Check

Blocks actions when open issues exceed threshold (default: 3).

### Auto-Issue Filing

Automatically files issues from tool errors (title: "Tool error: <name>").

## Code Versioning System

### Auto-Backup

The `tool_call` hook automatically backs up files before edits:
1. Detects `edit` tool call with a file path
2. Reads file content via `simplifile.read()`
3. Saves to `code_versions` table via `save_code_version()` SQL function
4. Updates TUI status bar with backup confirmation

### Manual Save/Restore

- `psypi-doc-save`: manually save a file version
- `psypi-doc-list`: view version history
- `restore_code_version()`: SQL function to restore a specific version

### Version Metadata

Each version records: `file_path`, `content`, `saved_by`, `commit_hash`, `reason`, `saved_at`.

## Reflection & Learning System

### areflect Tool

Parses structured markers from text and saves to database:
- `[LEARN]` → `learning_insights` table (insight_type='pattern', confidence=0.8)
- `[ISSUE]` → `issues` table (severity='medium')
- `[TASK]` → `tasks` table (priority=5)
- `[ISSUELIST N]` → fetches N recent issues for context

### Learning Save

`psypi-learn-save` saves learnings to `memory` table with:
- Content, tags (JSON array or comma-separated), importance (1-10), agent_id

### Memory Search

`psypi-memory-search` searches `memory` table by keyword, ordered by importance and recency.

## Broadcast & Meeting System

### Broadcasts

- Stored in `project_communications` table with `message_type='broadcast'`
- Priority: low, normal, high, critical
- Cross-project communication via shared database

### Meetings

- Structured discussion threads with topics
- Opinions from multiple agents
- Status: Active, Completed, Cancelled
- Consensus tracking (when meeting is completed)
- Meeting opinions include: author, perspective, reasoning, position

## Database Schema

### Key Tables

| Table | Purpose | Pattern |
|-------|---------|---------|
| `agent_souls` | Agent identity definitions (A and S) | **Append-only** — `save_soul_version()` |
| `agent_jobs` | Prioritized work items per soul | **Append-only** — `save_job_version()` |
| `tasks` | Task queue (PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE) | Standard CRUD |
| `issues` | Bug/feature/improvement tracker (severity: critical/high/medium/low/cosmetic) | Standard CRUD |
| `skills` | Skill registry (name, status, safety_score, content, version) | **Append-only** — `save_skill_version()` |
| `meetings` | Cross-agent AI communication (shared bulletin board) | Standard CRUD |
| `meeting_opinions` | Individual opinions within meetings | Standard CRUD |
| `memory` | Stored agent memories (content, tags, source, importance) | Standard CRUD |
| `learning_insights` | Learned knowledge (insight_type, title, content, confidence) | Standard CRUD |
| `code_versions` | File version history (auto-backup before AI edits) | Append-only |
| `psypi_config` | Key-value configuration store | Upsert |
| `system_reviews` | System review records (type, status, methodology, scope) | Standard CRUD |
| `review_findings` | Individual findings from system reviews (severity, category, status) | Standard CRUD |
| `inter_reviews` | A-bot's inter-review of S's work between sessions | Append-only |
| `psypi_event_hooks` | Event hook metadata and trigger counts | Standard CRUD |
| `project_communications` | Broadcast messages between agents | Standard CRUD |
| `activity_log` | Activity tracking (agent_id, activity, context) | Append-only |
| `notifications` | Agent-to-agent notifications | Standard CRUD |
| `key_concept_definitions` | Shared vocabulary/dictionary of project concepts | Standard CRUD |

### Append-Only Pattern

Used for `agent_souls`, `agent_jobs`, and `skills`:
- Never `UPDATE` in place — always `INSERT` via `save_soul_version()` / `save_job_version()` / `save_skill_version()`
- Two flags with distinct semantics:
  - `is_archived` (default false): primary gate. `true` = historical, never read
  - `is_active` (default true): business flag. NOT touched by versioning functions
- Read path: `WHERE is_active = true AND is_archived = false`
- Partial unique indexes enforce uniqueness on active, non-archived rows

**When to apply:** Table holds evolving config/identity, you need change history, read-heavy.
**Do NOT apply when:** Write-once log (already append-only), transactional status transitions (UPDATE is correct).

## Commit Workflow

```
S makes changes → psypi-commit("message") → git add -A && git commit -m "message [AI:<agent-id>]"
  → S goes idle → debounce timer fires → A wakes → inter-review → A sends findings to S
```

- Tags commits with `[AI:<agent-id>]` where agent_id is the semantic identity
- Uses `git add -A` (stages all changes)
- Shell-escapes the commit message for safety
- S MUST use `psypi-commit` for all commits (not raw `git commit`)

## Key Files

| File | Purpose |
|------|---------|
| `src/extension_generator.gleam` | Collects tools/hooks/commands, generates extension.js |
| `src/pi_tool_call.gleam` | PiToolCall, PiEventHook types + JS code generators |
| `src/agent_identity.gleam` | Identity resolution (single source of truth) |
| `src/db.gleam` | Database access layer |
| `src/hook_on_agent_end.gleam` | A-bot trigger: debounce + idle detection |
| `src/areflect.gleam` | Marker-parsing reflection tool |
| `src/monitor_ai.gleam` | Monitoring, health, alerts, suggestions |
| `src/system_prompt.gleam` | Prompt composition with token budget |
| `src/a_prompt_builder.gleam` | A-bot prompt construction |
| `src/hook_on_before_agent_start.gleam` | S-bot soul injection |
| `src/pi_extension_ffi.mjs` | ctx.ui.notify, ctx.isIdle, pi_send_message, call_monitor |
| `src/agent_identity_ffi.mjs` | check_git_exists |
| `src/node_ffi.mjs` | get_env, get_project_id_env, spawn_pi |
| `AGENTS.md` | Quick guide for AI agents |
| `docs/` | Design docs, reviews, ADRs |

## Build Commands

```bash
make setup                      # first-time setup (deps, DB, build, migrate, seed)
make build                      # compile + regenerate extension.js
make migrate                    # run DB migrations
make seed                       # seed initial data (idempotent)
make start                      # start Pi with psypi
make clean                      # clean build artifacts
make test                       # run tests
```

```bash
gleam clean && gleam build       # compile
gleam run -m simple_migrate      # run DB migrations
gleam run -m seed                # seed agent souls and jobs
gleam run -m extension_generator # regenerate extension.js
node bin/ppi.mjs                 # start Pi with psypi loaded
```

### Pi Slash Commands

| Command | Description |
|---------|-------------|
| `/autonomic-listen <message>` | Debug tool: talk to A directly |
| `/autonomic-reload` | Reload Pi extensions after code changes |

## Critical Rules

0. **NEVER delete data without explicit human confirmation** — No DELETE/DROP/TRUNCATE without asking
1. **NEVER use `psql` to modify DB directly** — All changes through migrations and Gleam code
2. **Always `pwd` first** — Never assume project root path
3. **Use Pi tools, not shell commands** — `/psypi-task-add`, not `psql`
4. **Use `psypi-commit`** for commits — not `git commit`
5. **Read files first** — `read` then `edit` with exact match
6. **Never spawn Pi from Pi tools** — infinite loop crash
7. **Gleam types** — Enums are source of truth. Validate at boundary via `string_to_*()` → `Result`
8. **Clean build** — Always `gleam clean && gleam build`
9. **pnpm** — Not npm
10. **NO FAKE GLEAM** — Never create `pi_*.gleam` modules. Never write JS as Gleam string literals

## Documentation

| Document | Description |
|----------|-------------|
| [AGENTS.md](AGENTS.md) | Quick guide for AI agents — project structure, tools, DB, identity, append-only pattern |
| [Zero Hand-Written JS](docs/ZERO-HANDWRITTEN-JS.md) | How to run a Node.js project without writing any JS — type-driven code generation with Gleam |
| [REFACTOR-NOTES.md](REFACTOR-NOTES.md) | Refactoring history and migration records |
| [CURRENT-STATE.md](CURRENT-STATE.md) | Current project state and recent changes |
| [HANDOVER.md](HANDOVER.md) | Session handover notes |
| [docs/](docs/) | Design docs, system reviews, ADRs |

## Lessons Learned

1. **`system_directives` Anti-Pattern**: Built DB table + tools + hook injection for A→S communication, when `sendMessage()` already exists. S is an LLM that reads messages directly — no database intermediary needed.
2. **Append-Only for evolving config**: Direct UPDATE destroyed history. Append-only preserves full evolution.
3. **Never cache `project_url()`**: Previous caching caused silent data corruption when CWD changed.
4. **Error reporting**: `ctx.ui.notify()` is for transient status only; errors must go through `pi.sendMessage()` to reach the conversation log.
5. **A-bot scope discipline**: A reviews the LATEST CYCLE only, not the whole session. Prior context is for deviation detection.
