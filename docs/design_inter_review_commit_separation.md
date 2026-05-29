# psypi Design Redesign — Inter-Review & Commit Separation

## Date: 2026-05-29
## Status: Implemented

---

## 1. Problem Statement

The previous design coupled inter-review with psypi-commit in a two-phase workflow:
- Phase 1: S-bot calls `psypi-commit` without review_id → triggers inter-review request
- Phase 2: S-bot calls `psypi-commit` with review_id → checks score, commits if >= 50

**Issues with previous design:**
- `respond_to_inter_review()` DB function existed but no Gleam code called it — workflow stuck at phase 2
- A-bot and S-bot struggled to understand the two-phase commit flow
- The inter-review response was never written back to DB
- Commit workflow was permanently broken

## 2. New Design (Implemented)

### 2.1 Separate Inter-Review from psypi-commit

**psypi-commit** is now simple:
- No longer requires `inter_review_id`
- Just does `git commit` with the message
- **Always appends the agent AI id** to the end of the commit message
- Only S-bot uses psypi-commit (not A-bot)
- Format: `git commit -m "<message> [AI:<agent-id>]"`

**inter-review** is now A-bot's main job:
- A-bot performs inter-review during its autonomous time
- Reviews are saved to the `inter_reviews` database table
- When A-bot sends a message to wake S-bot, it mentions the review (especially serious problems)

### 2.2 A-bot Workflow

A-bot's behavior is **database-driven**, not hardcoded:
- `agent_souls` table defines A's identity, role, and responsibilities
- `agent_jobs` table defines A's prioritized work items (including "Inter-review S code changes")
- The orchestrator loads soul + jobs from DB, builds a prompt, and calls the monitor (LLM)
- The LLM decides what to do based on its jobs — we do NOT force steps

What the orchestrator provides (context, not commands):
1. Loads soul from `agent_souls` (identity, behavior rules)
2. Loads jobs from `agent_jobs` (prioritized work items)
3. Loads project state (tasks, issues)
4. Gets recent commits since last A-bot session (as context for the LLM)
5. Builds prompt with all of the above
6. Calls monitor (LLM) — the LLM decides what to do
7. Sends the LLM's response to S-bot as a wake-up message
8. Updates `last_a_session_at` timestamp

### 2.3 Key Principle: A and S Never Work Simultaneously

Every piece of work must be inter-reviewed by A-bot, naturally:
- S-bot works → S-bot commits → S-bot becomes idle
- A-bot wakes → A-bot reviews S-bot's work → A-bot optionally does more → A-bot wakes S-bot
- S-bot works again → cycle repeats

### 2.4 Commit Logic (Simplified)

- psypi-commit appends the agent id to the commit message honestly
- `get_agent_id(ctx)` returns the caller's real ID — no manipulation
- Whoever calls psypi-commit gets their own ID tagged (S-bot gets S- prefix, A-bot gets A- prefix)
- No inter-review gate on commit — commit happens immediately
- Inter-review happens AFTER commit, during A-bot's autonomous time

### 2.5 Global ID Design

When psypi is not working on a project (no .git directory):
- `G` moves to the **project position** instead of before the prefix
- This is needed because `id_prefix` must be `S` or `A` for DB lookups

**ID format:**
- Project mode: `{prefix}-{project}-{source}-{model}[-{thinking_level}]`
  - Example: `S-psypi-claude-sonnet-4`
  - Example: `A-psypi-claude-sonnet-4`
- Global mode: `{prefix}-G-{source}-{model}[-{thinking_level}]`
  - Example: `S-G-claude-sonnet-4`
  - Example: `A-G-claude-sonnet-4`

The `id_prefix` column in `agent_souls` and `agent_prefixes` tables remains `A` or `S`.

---

## 3. Implementation Details

### 3.1 tool_commit.gleam (Phase 01-01)
- Removed `trigger_review()` function (phase 1)
- Removed `commit_if_reviewed()` function (phase 2)
- Removed `on_commit()` two-phase dispatch
- New `on_commit()` — simple commit with agent id appended via `get_agent_id(ctx)`
- Removed `inter_review` import
- Uses `shell_escape()` for safe commit messages

### 3.2 agent_identity_types.gleam / agent_identity.gleam (Phase 01-02)
- Changed `semantic_id()` to put `G` in project position
- Old: `global_prefix <> prefix <> "-" <> project <> ...` → `"G-A--source-model"`
- New: `prefix <> "-" <> project_or_G <> "-" <> source <> ...` → `"A-G-source-model"`
- `get_enriched_identity()` resolves project and global from cwd before calling `semantic_id()`

### 3.3 extension_generator.gleam (Phase 01-03)
- Removed `review_id` parameter from psypi-commit tool definition
- Updated description to "Commit changes with agent ID tagging. S-bot only."
- Tool now takes only `message` parameter

### 3.4 a_orchestrator.gleam (Phase 01-04)
- Added `get_recent_commits()` — runs `git log --oneline` since last A-bot session
- Provides commit_info as context to the LLM via `build_user_prompt`
- Does NOT force inter-review as a step — the LLM decides based on its DB jobs
- `handle_monitor_response()` sends the LLM's response directly to S-bot
- Updates `last_a_session_at` timestamp after each A-bot session

### 3.5 a_prompt_builder.gleam
- Added `commit_info` parameter to `build_user_prompt()`
- When commits exist, adds "S-bot's Recent Commits" section as context
- Does NOT instruct the LLM to review — the LLM reads its jobs from DB and decides

### 3.6 a_db_reader.gleam
- Added `get_last_a_session_at()` — reads `last_a_session_at` from config table
- Used to determine the time window for fetching recent S-bot commits

### 3.7 inter_review.gleam
- Added `save_review_result(review_id, summary, score)` — updates inter_reviews with completed status
- Added `create_review_for_commits(reviewer_id, commit_info)` — creates review record via DB function

### 3.8 pi_extension_ffi.mjs
- Added `get_agent_id(ctx)` — computes agent ID from context (prefix, project, source, model, thinking)
- Mirrors the Gleam `semantic_id()` logic for use in FFI contexts

### 3.9 pi_extension.gleam
- Added `@external(javascript, "./pi_extension_ffi.mjs", "get_agent_id")` declaration

---

## 4. Test Coverage

- `psypi_test.gleam`: Updated semantic_id tests for new `S-G-` / `A-G-` format
- `a_prompt_builder_test.gleam`: Updated all `build_user_prompt` calls with `commit_info` param
- Added `build_user_prompt_with_commit_info_test` and `build_user_prompt_no_commit_info_test`
- All 89 tests pass

---

## 5. Data Flow

```
S-bot works on code
    │
    ▼
S-bot calls psypi-commit("fix: debounce bug")
    │
    ▼
tool_commit.on_commit() appends [AI:S-psypi-openrouter-owl-alpha]
(get_agent_id returns the caller's real ID honestly)
    │
    ▼
git commit -m "fix: debounce bug [AI:S-psypi-openrouter-owl-alpha]"
    │
    ▼
S-bot becomes idle → debounce timer starts
    │
    ▼
A-bot wakes (ctx.isIdle=true, debounce elapsed, no agent session)
    │
    ▼
A-bot loads: soul (agent_souls) + jobs (agent_jobs) + project state
    │
    ▼
A-bot gets recent commits since last_a_session_at (as context)
    │
    ▼
A-bot builds prompt with soul, jobs, state, commits
    │
    ▼
A-bot calls monitor (LLM) — LLM decides what to do based on its jobs
    │
    ▼
A-bot sends LLM's response to S-bot as wake-up message
    │
    ▼
A-bot updates last_a_session_at in config
```
