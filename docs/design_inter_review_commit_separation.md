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

When S-bot is truly idle (all conditions must be met):
1. `ctx.isIdle` is `true`
2. Debounce time has elapsed (default 5 minutes)
3. No agent session exists (any agent start event resets `idle_since` to 0)

Then A-bot:
1. Gets recent S-bot commits since last A-bot session (`get_recent_commits`)
2. Creates an inter-review record via `inter_review.create_review_for_commits`
3. Includes commit info in the prompt for A-bot's review
4. Calls the monitor (LLM) to review the commits
5. Saves the review result via `inter_review.save_review_result`
6. Updates `last_a_session_at` config timestamp
7. Sends wake-up message to S-bot with review summary
8. Flags serious issues (CRITICAL/URGENT) in the wake-up message prefix

### 2.3 Key Principle: A and S Never Work Simultaneously

Every piece of work must be inter-reviewed by A-bot, naturally:
- S-bot works → S-bot commits → S-bot becomes idle
- A-bot wakes → A-bot reviews S-bot's work → A-bot optionally does more → A-bot wakes S-bot
- S-bot works again → cycle repeats

### 2.4 Commit Logic (Simplified)

- Only S-bot commits using psypi-commit tool
- psypi-commit always appends the agent id to the commit message
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
- Added `create_inter_review()` — async wrapper for `inter_review.create_review_for_commits`
- Added `save_review_and_wake_up()` — saves review result, then sends wake-up with flags
- `run_full_workflow()` now: gets commits → creates review → calls monitor → saves result → wakes S
- Wake-up message prefixes `[INTER-REVIEW: SERIOUS ISSUES FOUND]` when CRITICAL/URGENT detected

### 3.5 a_prompt_builder.gleam
- Added `commit_info` parameter to `build_user_prompt()`
- When commits exist, adds "S-bot's Recent Commits" section to prompt
- Instructs A-bot to review commits and flag serious issues with CRITICAL/URGENT

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
A-bot gets recent commits since last_a_session_at
    │
    ▼
A-bot creates inter-review record (inter_reviews table)
    │
    ▼
A-bot reviews commits via monitor (LLM)
    │
    ▼
A-bot saves review result (status=completed, summary, score)
    │
    ▼
A-bot updates last_a_session_at in config
    │
    ▼
A-bot sends wake-up message to S-bot
    └─ If serious issues: "[INTER-REVIEW: SERIOUS ISSUES FOUND] ..."
    └─ If OK: normal review summary + "(inter-review: <id>)"
```
