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
