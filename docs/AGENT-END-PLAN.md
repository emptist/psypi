# Plan: A-S Communication System (agent_end coordination)

## Starting Point: ctx.isIdle()

`ctx.isIdle()` is a Pi runtime API that returns whether the agent (S-worker) is currently processing anything. This is the foundation of the A-S communication mechanism.

## Business Logic Chain (from old fake Gleam)

### Trigger: agent_end event
- Fires when S-worker finishes processing a user prompt
- The S-worker has gone idle

### Step 1: Debounce (wait 5 minutes)
- Read `monitor_debounce_ms` from `psypi_config` table (key: monitor_debounce_ms)
- Default: 300000ms (5 minutes) — NOT 15000ms (15 seconds) which was too short
- Use `setTimeout(debounceMs)` to wait
- Rationale: S-worker might get a new prompt immediately after finishing. No need to wake it up if it's already busy.

### Step 2: Check ctx.isIdle()
- After debounce, check if S-worker is STILL idle
- If `ctx.isIdle() === false` → S-worker is busy with new work, skip wake-up
- If `ctx.isIdle() === true` → S-worker is idle, proceed to compose message

### Step 3: Read MONITOR-BRIEF.md
- Read from `{ctx.cwd}/docs/MONITOR-BRIEF.md`
- If file not found, continue with empty brief
- Brief contains hard-to-find knowledge for the A-worker

### Step 4: Get context usage
- Call `ctx.getContextUsage()` → returns {tokens, contextWindow}
- Format: "Context: X% used." (only if usage data available)

### Step 5: Build system prompt for Monitor LLM
```
You are the Autonomic Worker (Monitor). The Somatic Worker has gone idle.

Context: X% used.

Monitor Brief:
{brief content}

Compose a brief, natural wake-up message (1-2 sentences). Mention what needs attention. The S-worker is smart — it will decide what to do. Prefix with [from A-worker:].
```

### Step 6: Call Monitor LLM
- Use `callMonitor(ctx, messages, systemPrompt)` helper
- Messages: [{role: 'user', content: [{type: 'text', text: 'Somatic worker is idle. Compose a wake-up message.'}]}]
- Get composed message text

### Step 7: Handle errors
- If callMonitor throws → msg = "Issue! LLM call failed: {error}"
- If callMonitor returns empty/null → msg = "Issue! LLM returned empty"

### Step 8: Send message to S-worker
```javascript
pi.sendMessage({
  customType: 'autonomic-wakeup',
  content: [{type: 'text', text: msg}],
  display: 'persistent',
  details: { source: 'agent_end_coordination' }
}, { triggerTurn: true })
```
- `triggerTurn: true` → Immediately wakes up S-worker to process the message
- S-worker sees the message and decides what to do

## Two sendMessage Use Cases

### Use Case 1: callMonitor works (success)
- customType: 'autonomic-wakeup'
- content: composed message from Monitor LLM
- Example: "[from A-worker:] You have 3 open issues. Consider reviewing them."

### Use Case 2: Something went wrong (error)
- customType: 'autonomic-wakeup' (same type, still wakes S-worker)
- content: error message
- Example: "Issue! LLM call failed: connection timeout"

## Design Decision: SimpleHook vs ComplexHook

The agent_end coordination CANNOT be expressed as a single Gleam function call because it needs:
1. `ctx.isIdle()` — Pi runtime API
2. `setTimeout()` — JS runtime
3. `fs.readFileSync()` — Node.js file system
4. `callMonitor()` — calls Monitor LLM
5. `pi.sendMessage()` — sends message to S-worker

These are all Pi/JS runtime APIs. The Gleam type system can't express this.

**Solution: Two hook types in PiEventHook:**

1. **SimpleHook** — for hooks that call a single Gleam function
   - Fields: event_name, module, fn_name, args
   - Generator produces: `pi.on('name', async (event, ctx) => { try { const result = await module_fnName(args); ... } })`

2. **ComplexHook** — for hooks that need custom JS body
   - Fields: event_name, handler_body: String
   - Generator produces: `pi.on('name', async (event, ctx) => { handler_body })`
   - The handler_body is constructed by Gleam string functions (not hardcoded)

## Implementation Plan

### Phase 1: Update PiEventHook type
- Change from single type with on_send field to two-variant type (SimpleHook | ComplexHook)
- Update event_hook_to_js() to handle both variants
- Update helper functions (simple_hook(), complex_hook())

### Phase 2: Update autonomic_hooks.gleam
- Simple hooks: session_start, model_select, tool_call, tool_result, before_agent_start, agent_start
- Complex hook: agent_end (with full coordination logic as generated JS)
- Fix debounce to 300000ms (5 minutes)

### Phase 3: Update extension_generator.gleam
- Import agent_end_hook from autonomic_hooks
- Add to all_event_hooks()

### Phase 4: Build and test
- rm -rf build/ && gleam build
- gleam run -m extension_generator
- Verify extension.js output
- Test in Pi TUI

## Key Insight

The ComplexHook.handler_body is NOT hand-written JS. It's CONSTRUCTED by Gleam string functions from structured data. This is the key difference from the old fake generator files.

Old way: hardcoded JS string in Gleam source
New way: Gleam function constructs JS string from structured data (event_name, debounce_ms, brief_path, etc.)

This means if we need to change the debounce from 5 minutes to 10 minutes, we change ONE Gleam value, not a hardcoded JS string.
