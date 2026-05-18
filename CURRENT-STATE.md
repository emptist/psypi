# Current State — 2026-05-14

## What Works
- ✅ `psypi-somatic-id` — returns S- identity
- ✅ `psypi-autonomic-id` — returns A- identity
- ✅ `write` tool — can write files
- ✅ `bash` — can execute commands
- ✅ Build and regeneration — success

## What Needs Testing
- ⏳ `psypi-consult-autonomic` — S-agentbot asks A-agentbot for advice (was ERROR, now fixed with better error handling)
- ⏳ `psypi-direct-agentbot` — A-agentbot sets directives for S-agentbot
- ⏳ `agent_end` hook — A-agentbot wakes up S-agentbot when issues found

## Key Changes Made
1. Split extension_generator.gleam into small modules (< 40 lines each)
2. Removed dangerous pattern matching from hooks
3. Removed crashing identity/activity calls from hooks
4. Added [Autonomic] prefix to A-agentbot messages
5. agent_end hook: checks health, wakes up S-agentbot if issues found and no active directives
6. Renamed tools: psypi-consult-autonomic, psypi-direct-agentbot

## Architecture
- A-agentbot: event-driven, reads hooks, writes DB/messages
- S-agentbot: prompt-driven, reads system prompt, produces events
- Alternating current: each one's output = other's input

## Next Steps
1. Test psypi-consult-autonomic
2. Test agent_end wake-up behavior
3. Verify no infinite loops
