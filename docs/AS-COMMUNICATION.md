# A-S Communication System

## Core Principle

**Everything is an ID.** The ID is the single source of truth. `get_resolved_identity` is the only function that produces IDs. No tool, no DB query, no hardcoded string — just one function call.

## The ID Encodes Everything

```
A-psypi-openrouter/owl-alpha-high
│   │     │         │         │
│   │     │         │         └─ thinking level (optional)
│   │     │         └─ model (from ctx.model.id)
│   │     └─ source/provider (from ctx.model.provider)
│   └─ project (from ctx.cwd)
└─ role: A=Autonomic, S=Somatic
```

The ID tells you:
- **Who**: A-worker or S-worker
- **What**: which model is running
- **Where**: which project
- **How**: thinking level

## Two Workers, One Function

```javascript
// S-worker identity (autonomous=false)
const sId = await agent_identity_get_resolved_identity(
    false,                    // autonomous
    ctx.cwd,                  // project
    ctx.model?.provider,      // source
    ctx.model?.id,            // model
    ctx.model?.thinkingLevel  // thinking
);
// Result: "S-psypi-openrouter/owl-alpha"

// A-worker identity (autonomous=true)
const aId = await agent_identity_get_resolved_identity(
    true,                     // autonomous
    ctx.cwd,                  // project
    ctx.model?.provider,      // source
    ctx.model?.id,            // model
    ctx.model?.thinkingLevel  // thinking
);
// Result: "A-psypi-openrouter/owl-alpha"
```

The ONLY difference is the first argument: `true` or `false`. Everything else comes from `ctx`.

## How A-S Exchange Happens

### S-worker side (normal operation)
1. User sends prompt
2. `before_agent_start` fires → S-worker reads notifications from DB
3. S-worker processes prompt, calls tools, etc.
4. `agent_end` fires → S-worker is done

### A-worker side (agent_end coordination)
1. `agent_end` fires → S-worker finished
2. Wait 5 min (debounce)
3. Check `ctx.isIdle()` → is S-worker still idle?
4. If NO → S-worker got new work, skip
5. If YES → call `get_resolved_identity(true, ...)` → get A-worker ID
6. Read MONITOR-BRIEF.md
7. Call Monitor LLM with A-worker ID in system prompt
8. Send wake-up message to S-worker via `pi.sendMessage`

### The Exchange
- A-worker sends: `pi.sendMessage({ customType: 'autonomic-wakeup', content: msg })`
- S-worker receives: the message appears in session
- S-worker sees: "[from A-worker:] You have 3 open issues..."
- S-worker decides: what to do next

**No explicit handshake. No shared state. Just the ID and the message.**

## ctx.isIdle() — The Gate

`ctx.isIdle()` is the ONLY check needed. It tells you:
- `true` → S-worker is idle → A-worker can speak
- `false` → S-worker is busy → A-worker stays silent

This is the gate that prevents A-worker from interrupting S-worker.

## Debounce — Why 5 Minutes?

After `agent_end` fires, S-worker might immediately get a new prompt. No need to wake it up if it's already busy.

- Old: 15 seconds (too short, S-worker could still be processing)
- New: 5 minutes (300000ms) — enough time for S-worker to settle

Configurable via `psypi_config` table: `monitor_debounce_ms`

## agent_end.gleam — The Implementation

Single file. Single function. Under 100 lines.

```gleam
// agent_end.gleam
pub fn handler() -> PiEventHook {
  custom_hook("agent_end", handler_body())
}
```

The handler body is JS text constructed by Gleam string functions. It:
1. Reads debounce from DB (default 300000ms)
2. setTimeout(debounceMs)
3. Checks ctx.isIdle()
4. Calls get_resolved_identity(true, ...) for A-worker ID
5. Reads MONITOR-BRIEF.md
6. Calls callMonitor with A-worker ID in prompt
7. Sends message via pi.sendMessage

## Key Design Decisions

### Why custom_hook instead of simple_hook?
The agent_end coordination needs Pi runtime APIs: `ctx.isIdle()`, `ctx.model`, `callMonitor()`, `pi.sendMessage()`. These can't be expressed as a Gleam function call. So we use `custom_hook` with JS text body.

### Why construct JS text instead of hardcoding?
The old fake generator files had hardcoded JS strings. If you wanted to change the debounce from 15s to 5min, you edited a string. Now, the debounce is a Gleam value (`300000`) that gets inserted into the generated JS. Change one number, rebuild, done.

### Why call get_resolved_identity instead of building ID inline?
`get_resolved_identity` is the single source of truth. If the ID format changes (e.g., add new segment), we change ONE function, not every place that builds IDs.

### Why pass A-worker ID to callMonitor?
The LLM needs to know who it is. The ID tells the LLM: "You are A-psypi-openrouter/owl-alpha-high" — the Autonomic Worker with this specific model and thinking level. The LLM can then compose a contextually appropriate message.

## File Structure

```
src/
  agent_identity.gleam      -- get_resolved_identity (single source of truth)
  agent_identity_logic.gleam -- generate_semantic_id (ID format)
  agent_end.gleam           -- agent_end coordination (complex hook)
  autonomic_hooks.gleam     -- simple hooks (session_start, model_select, etc.)
  pi_tool_call.gleam        -- PiEventHook type + generators
  extension_generator.gleam -- collects all hooks
```

Each file under 100 lines. Clean separation. Composed together.
