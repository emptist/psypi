# Session Summary — 2026-05-14

## What Was Fixed

### Root Cause of Tool Blocking
The `tool_call` hook in `extension.js` had dangerous pattern matching that tested `inputStr` (file content) against patterns like `/rm.*-rf/i`. This meant writing a file containing "rm -rf" in the content would block the write tool.

Additionally, `agent_identity_get_resolved_identity` and `log_activity` calls crashed silently, blocking all tools.

### Solution
1. **Split `extension_generator.gleam` (550 lines) into small modules** (< 40 lines each):
   - `generator/tool_call.gleam` — Thin hook, auto-backup only
   - `generator/before_agent_start.gleam` — Read directives from DB
   - `generator/session_start.gleam` — Session init
   - `generator/model_select.gleam` — Record model changes
   - `generator/tool_result.gleam` — Detect errors, create directives
   - `generator/agent_lifecycle.gleam` — Agent start/end logging

2. **Removed dangerous pattern matching** — hooks no longer block tools

3. **Removed crashing calls** — identity resolution and activity logging removed from hooks

## Tool Renaming
- `psypi-my-id` → `psypi-somatic-id` (S- prefix, prompt-driven)
- `psypi-autonomic-id` → `psypi-autonomic-id` (A- prefix, event-driven)
- `psypi-set-directive` → `psypi-direct-agentbot` (better English, only A-agentbot uses this)

## Key Architectural Insight
**"Any efforts to remove intelligence from psypi system are just wrong!"**

Hooks should be THIN — no pattern matching, no blocking logic. The Autonomic Agentbot (LLM-powered thinking) handles all intelligent decisions. Scripts are just scaffolding for DB reads/writes and prompt injection.

## Build Status
- ✅ `gleam build` — success
- ✅ `gleam run -m extension_generator` — success
- ✅ `psypi-somatic-id` — works
- ✅ `psypi-autonomic-id` — works
- ✅ `write` tool — works

## Files Changed
- `src/extension_generator.gleam` — Rewritten (318 lines, down from 550)
- `src/generator/tool_call.gleam` — New (31 lines)
- `src/generator/before_agent_start.gleam` — New (36 lines)
- `src/generator/session_start.gleam` — New (20 lines)
- `src/generator/model_select.gleam` — New (19 lines)
- `src/generator/tool_result.gleam` — New (34 lines)
- `src/generator/agent_lifecycle.gleam` — New (20 lines)
- `src/directive.gleam` — Renamed tool to `direct_agentbot_tool`
- `src/agent_identity.gleam` — Renamed to `somatic_id_tool` and `autonomic_id_tool`
- `AGENTS.md` — Updated documentation

## Next Steps
1. Test all tools after restart
2. Continue splitting large Gleam files (< 100 lines target)
3. Let Autonomic Agentbot use `psypi-direct-agentbot` to set directives

---

## Session 2 — A-Agentbot Behavior Fix (2026-05-20)

### Problem
A-agentbot was directing S to do passive observation work ("check the database", "review tasks") instead of helping S finish current work. This created useless loops where A asks S to inspect things, S reports back, A asks for more inspections.

### Root Causes Found
1. **`souls` table was empty** — `read_soul_from_db()` queried `souls` (plural) which had zero rows. Should query `soul` (singular) which has 5 active Monitor responsibilities.
2. **A's identity prompt was too vague** — Said "observe, analyze, and direct S" without specifying *how* to pick good tasks or that A should help S finish current work.
3. **No project state in A's prompt** — A had no data about active tasks/issues, so it defaulted to generic "check" directives.
4. **No behavioral rules** — Nothing in the prompt prevented A from redirecting S to unrelated tasks.

### Fixes Applied

#### 1. Fixed `read_soul_from_db()` — query correct table
- Changed from `SELECT content FROM souls WHERE name='Monitor'` to `SELECT role, domain, responsibility FROM soul WHERE is_active=true AND role='Monitor'`
- Created `soul_responsibility_decoder()` to format soul entries
- Dropped empty `souls` table from database

#### 2. Rewrote `a_identity_prompt()` — clear behavioral rules
- Primary job: help S finish current work, not redirect
- Priority order: inter-review → unblock → continue → new task (only if idle)
- Rules: never distract, never busywork, never repeat, always check in-progress work

#### 3. Added `read_project_state_from_db()` — real context for A
- Queries active tasks (status, priority, stuck flag)
- Queries open issues (severity, title)
- Injects results into A's user prompt as "Project State"

#### 4. Rewrote `build_user_prompt()` — instruct A to use project state
- Includes project state section with active tasks and issues
- Instructs A to check in-progress work before suggesting new tasks
- Emphasizes inter-review and finishing over redirecting

#### 5. Updated `MONITOR-BRIEF.md` — align documentation with new behavior
- Added "Core Principle: Help S Finish, Don't Redirect"
- Updated priority order and rules
- Added "What NOT to do" section
- Changed tone from "check and report" to "inter-review and unblock"

### Build Status
- ✅ `gleam build` — success
- ✅ `gleam run -m extension_generator` — success
- ✅ All changes in `extension.js`

### Files Changed
- `src/hook_on_agent_end.gleam` — Major rewrite of soul reading, identity prompt, user prompt, added project state queries
- `docs/MONITOR-BRIEF.md` — Updated behavioral guidelines
- Database: dropped empty `souls` table
