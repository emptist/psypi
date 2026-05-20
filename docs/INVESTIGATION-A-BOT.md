# A-Bot (Autonomic Agentbot) Investigation

## Status: Partially Working

### What works
- `psypi-autonomic-status` — returns "OK"
- `psypi-autonomic-health` — returns metrics (failed_tasks, open_issues, activities_1h, db_healthy)
- `psypi-autonomic-alerts` — returns alert metrics
- `psypi-autonomic-suggest` — returns work suggestions
- `psypi-autonomic-stats` — returns model stats (all zeros)
- `psypi-hooks-list` / `psypi-hooks-active` — lists event hooks
- `psypi-direct-agentbot` / `psypi-clear-directives` — directive management
- `psypi-commit` — commit with review
- Event hooks registered: tool_call, session_start, model_select, before_agent_start, agent_start, agent_end, tool_result

### What doesn't work
1. **A-bot wake-up messages not being sent** — The `agent_end` hook fires (confirmed by `[AUTONOMIC] isIdle=` notifications appearing), but the wake-up message composition via `call_monitor` may be failing silently
2. **call_monitor returns empty** — The `call_monitor` function in `pi_extension_ffi.mjs` uses `completeSimple` from `@earendil-works/pi-ai`. The LLM call may be returning empty output or the response parsing may be failing
3. **Autonomic stats all zeros** — `total_reviews: 0, avg_score: 0, avg_response_time_ms: 0, failure_count: 0` — suggests the inter_review system is not being used
4. **No A-bot activity in session** — The A-bot should be injecting wake-up messages into the S-bot's session via `pi_send_message`, but no such messages appear

### Root cause analysis

#### agent_end hook flow
1. `agent_end` event fires → hook checks `ctx.isIdle()`
2. If idle → reads `monitor_debounce_ms` from `system_config` table
3. Waits `debounceMs` (default 300000ms = 5 minutes)
4. After debounce → calls `hook_on_agent_end.on_agent_end(ctx, pi)`
5. The hook reads session entries, context usage, soul, directives, project state
6. Calls `call_monitor(ctx, userPrompt, systemPrompt)` to compose wake-up
7. Sends via `pi_send_message(pi, 'autonomic-wakeup', response, 'persistent')`

#### Potential failure points
1. **Step 2**: `get_debounce_ms()` might fail if `system_config` table doesn't have the key → returns error, hook exits silently
2. **Step 5**: Any of the DB reads (soul, directives, project state) might fail → hook exits with error message
3. **Step 6**: `call_monitor` might fail because:
   - `ctx.model` is missing
   - `modelRegistry.getApiKeyAndHeaders()` fails
   - `completeSimple()` returns empty content
   - Response parsing fails (expects `result.content` array but gets different format)
4. **Step 7**: `pi_send_message` might fail silently

### Diagnostic steps needed
1. Check if `system_config` table has `monitor_debounce_ms` key
2. Add logging to `call_monitor` to see what `completeSimple` returns
3. Check if `ctx.model` and `ctx.modelRegistry` are available in the agent_end hook context
4. Test `call_monitor` independently with a simple prompt

### Files involved
- `src/hook_on_agent_end.gleam` — main agent_end hook logic
- `src/pi_extension_ffi.mjs` — call_monitor FFI function
- `src/system_config.gleam` — debounce config reader
- `src/pi_extension.gleam` — FFI declarations
- `extension.js` — generated extension (lines ~105-150 for agent_end hook)

### Recommended fixes
1. Add more error logging in the agent_end hook to identify which step fails
2. Make `call_monitor` more resilient to different response formats
3. Add a fallback if `system_config` doesn't have the debounce key (use default 300000ms)
4. Test the completeSimple API independently to verify it works with the current model/provider

*Investigated: 2026-05-20 by S-agentbot*
