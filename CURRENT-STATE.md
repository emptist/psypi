# Current State — 2026-05-14

## What Works
- ✅ `psypi-somatic-id` — returns S- identity
- ✅ `psypi-autonomic-id` — returns A- identity
- ✅ `write` tool — can write files
- ✅ `bash` — can execute commands
- ✅ Build and regeneration — success

## What Needs Testing
- ⏳ `psypi-consult-autonomic` — S-worker asks A-worker for advice (was ERROR, now fixed with better error handling)
- ⏳ `psypi-direct-worker` — A-worker sets directives for S-worker
- ⏳ `agent_end` hook — A-worker wakes up S-worker when issues found

## Key Changes Made
1. Split extension_generator.gleam into small modules (< 40 lines each)
2. Removed dangerous pattern matching from hooks
3. Removed crashing identity/activity calls from hooks
4. Added [Autonomic] prefix to A-worker messages
5. agent_end hook: checks health, wakes up S-worker if issues found and no active directives
6. Renamed tools: psypi-consult-autonomic, psypi-direct-worker

## Architecture
- A-worker: event-driven, reads hooks, writes DB/messages
- S-worker: prompt-driven, reads system prompt, produces events
- Alternating current: each one's output = other's input

## Next Steps
1. Test psypi-consult-autonomic
2. Test agent_end wake-up behavior
3. Verify no infinite loops
