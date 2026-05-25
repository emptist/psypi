# Handover — 2026-05-26

## What was done this session

### Committed (49dc6a7)
- `src/a_orchestrator.gleam` — added `fully_functional = False` gate that bypasses A's full workflow (DB reads + LLM call) and sends a simple greeting instead
- `src/a_prompt_builder.gleam` — added inter-review detection in `build_user_prompt` + "Inter-Review" section in A's identity prompt
- `AGENTS.md`, `README.md`, `ppi_skills/psypi-basics/SKILL.md` — fixed `rm -rf build/` → `gleam clean && gleam build`
- `docs/REVIEW-A-BOT-DEBOUNCE.md` — full root cause analysis of 3 debounce bugs

### Issues filed
- **16ef800a** — CONSOLIDATED: agent_end debounce (timer stacking + no idle_since + fires wrong time)
- **6cf92c87** — A-bot can't do inter-review: drifts to tangents
- **0c5022df** — psypi-task-add fails: project_id NOT NULL constraint violation

### Issues resolved (consolidated)
- b9ea707f, f0c389d5, 0bd23575 → consolidated into 16ef800a

### Rebuilt
- `gleam clean && gleam build` — DecodeError fix (cc64c9f5) now in compiled .mjs files

## Current state of A-bot
- `fully_functional = False` in a_orchestrator.gleam — A sends only a simple greeting, no DB/LLM
- This is intentional — prevents A from disturbing S while we debug
- To re-enable: change `False` to `True` in a_orchestrator.gleam, rebuild

## What to do next

### Priority 1: Fix psypi-task-add (issue 0c5022df)
- Small fix: add `project_id` to the INSERT in `src/task.gleam` `add()` function
- Or make the column nullable / add default
- This is blocking task management

### Priority 2: Test A-bot with fully_functional = True
- After the prompt fix (inter-review detection), test if A can actually do focused review
- If A still drifts, the prompt fix may need strengthening
- If A works, set `fully_functional = True` and rebuild

### Priority 3: Implement debounce fix (issue 16ef800a)
- Timer dedup in `pi_tool_call.gleam` `event_hook_to_js()` for PiDebouncedHook
- idle_since tracking in `hook_on_agent_end.gleam`
- debounceMs caching
- Full plan in `docs/REVIEW-A-BOT-DEBOUNCE.md`

### Priority 4: Docs review (original task from user)
- Compare all docs to codebase, fix gaps
- README.md and ARCHITECTURE.md have known gaps (see REVIEW-A-BOT-DEBOUNCE.md section 3)
- agent_soul DB content still references old table names (issue 22261e08)

## Key files modified this session
- `src/a_orchestrator.gleam` — fully_functional gate
- `src/a_prompt_builder.gleam` — inter-review detection + focus prompt

## Key files to modify next
- `src/task.gleam` — fix project_id INSERT
- `src/pi_tool_call.gleam` — timer dedup in PiDebouncedHook generation
- `src/hook_on_agent_end.gleam` — idle_since tracking

## Build command
Always use: `gleam clean && gleam build` (NOT `rm -rf build/`)
