# Session Summary — 2026-05-14 (Final)

## Architecture: Alternating Current

One AI, two SOULs, alternating current:
- **A-worker** (Autonomic): Event-driven, reads hooks, writes DB/messages
- **S-worker** (Somatic): Prompt-driven, reads system prompt, produces events

They alternate — each one's output is the other's input.

## Two Communication Channels

### A→S: Direct Messages
`ctx.ui.notify()` → appears as user message with `[Autonomic]` prefix

### A→S: System Prompt Directives  
Write to `system_directives` table → `before_agent_start` injects into prompt

### S→A: Consultation
`psypi-consult-autonomic` tool → A-worker responds with `[Autonomic]` advice

## Key Changes

### 1. Split extension_generator.gleam into small modules
All modules < 40 lines:
- `generator/tool_call.gleam` — Thin hook, auto-backup only
- `generator/before_agent_start.gleam` — Read directives, inject into prompt
- `generator/session_start.gleam` — Health check, [Autonomic] messages
- `generator/model_select.gleam` — Record model changes
- `generator/tool_result.gleam` — Detect errors, create directives
- `generator/agent_lifecycle.gleam` — Agent start/end logging

### 2. Removed dangerous pattern matching from hooks
No more blocking file writes based on content.

### 3. Removed crashing calls from hooks
- `agent_identity_get_resolved_identity` 
- `log_activity`

### 4. Added [Autonomic] prefix
A-worker messages display with `[Autonomic]` prefix on screen.

### 5. Renamed tools
- `psypi-my-id` → `psypi-somatic-id`
- `psypi-monitor-id` → `psypi-autonomic-id`
- `psypi-set-directive` → `psypi-direct-worker`
- `psypi-monitor-consult` → `psypi-consult-autonomic`

### 6. Updated documentation
- `docs/DREAM-TEAM-ARCHITECTURE.md` — Complete rewrite with AC metaphor
- `docs/FIXES-2026-05-14.md` — All fixes documented
- `AGENTS.md` — Updated tool names and directive system

## Build Status
- ✅ `gleam build` — success
- ✅ `gleam run -m extension_generator` — success
- ✅ All files backed up in `code_versions`

## Next Steps
1. Restart psypi and test all tools
2. Test `psypi-consult-autonomic` (S→A communication)
3. Test `psypi-direct-worker` (A→S communication)
4. Verify `[Autonomic]` messages appear on screen
5. End-to-end dream-team cycle test
