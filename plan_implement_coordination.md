# Plan: Implement Simple A-Worker → S-Worker Coordination via Direct Messaging

## Goal
Implement the core psypi coordination mechanism where the Autonomic Worker (A-worker) wakes the Somatic Worker (S-worker) by emitting a system/user prompt when `ctx.isIdle()` becomes true.

## Current State
- The conceptual mechanism is **already correct** in psypi's architecture.
- It relies on direct messaging: `pi.sendMessage()` or `pi.broadcast()`.
- No existing implementation uses this simple approach; coordination is under‑developed.

## Required Implementation Steps

1. **Detect Idle State**
   - In the *Monitor* (A-worker), poll or listen for `ctx.isIdle()` becoming true.
   - This can be done via a timer loop or by hooking into the `agent_end`/`tool_result` events that signal completion.

2. **Emit a Wake‑up Prompt**
   - When idle is detected, send a prompt to the S‑worker.
   - Use either:
     - `pi.sendMessage(message, targetAgentId)` for direct messaging to a specific S‑worker.
     - `pi.broadcast(message)` for a global broadcast (both work).

3. **Message Content**
   - Include a recognizable `[Monitor]` prefix so the S‑worker can filter it.
   - Content should indicate new tasks, reminders, or directives.
   - Example: `"[Monitor] ⏰ Wake‑up call! New tasks ready for processing."`

4. **Persist Across Sessions (Optional)**
   - Ensure prompts survive process restarts if needed.
   - Use `psypi-memory-save` or a DB entry to keep track of outstanding prompts.

5. **Integrate with Existing Hooks**
   - Leverage active hooks (`tool_result`, `session_start`, etc.) to trigger the idle‑check loop.
   - Example: set up a `pi.on('tool_result', ...)` listener that schedules the next idle check.

6. **Testing & Validation**
   - Write unit tests that simulate `ctx.isIdle()` returning true.
   - Verify the prompt reaches the intended S‑worker.
   - Confirm system prompts are injected correctly by the before_agent_start hook.

## File Structure for Implementation
- `src/monitor/worker_coordination.gleam` – Core idle detection & messaging logic.
- `src/monitor/worker_coordination.hook.gleam` – Hook registration (e.g., `tool_result` listener).
- `extension_generator.gleam` – Ensure generated `extension.js` includes the new code paths.
- `README-update.md` – Document the new coordination feature.

## Acceptance Criteria
- When an S‑worker finishes its turn and becomes idle, the A‑worker automatically sends a system prompt.
- The S‑worker receives the prompt and resumes work with an updated system context.
- Logs show a "[Monitor]" message appearing before the S‑worker’s next action.
- No breaking changes to existing functionality.

## Timeline
- **Day 1**: Draft `worker_coordination.gleam` and hook registration.
- **Day 2**: Update `extension_generator.gleam` and regenerate `extension.js`.
- **Day 3**: Write tests, integrate with existing hooks, perform final review.
- **Day 4**: Documentation update and final commit.

## Risks & Mitigations
- **Risk**: Over‑polling could cause performance issues.
  - *Mitigation*: Use debounce/throttle; only check when relevant events (`tool_result`, `session_start`) fire.
- **Risk**: Prompt injection conflicts with existing prompt modifications.
  - *Mitigation*: Prefix messages clearly (`[Monitor]`) and allow configurable injection points.

---

*Prepared by the Autonomic Worker planning module. Ready for implementation.*