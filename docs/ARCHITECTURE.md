# PsyPI Architecture — Id is Everything

## Core Principle

**ID is everything. Everything is ID.**

The ID is not just a label. It IS the context. It encodes:
- Role (A/S) — from `ctx.isIdle()`
- Model — from `ctx.model.id`
- Source — from `ctx.model.provider`
- Thinking level — from `ctx.model.thinkingLevel`
- Project — from `ctx.cwd`

## Pure Function

`get_resolved_identity(ctx)` is a **pure function**:
- Same `ctx` → same ID, always
- No side effects
- No DB access
- No hidden state

The function doesn't know or care WHERE `ctx` came from. It just builds the ID.

## Function is Gleam, Function is JS

The SAME function runs in TWO worlds:

### Gleam world (compile time)
```gleam
pub fn get_resolved_identity(ctx: Context) -> Result(AgentIdentity, IdentityError) {
  let prefix = case ctx.is_idle { True -> "A", False -> "S" }
  // ... build ID
}
```
- Type-safe
- Compiler catches errors
- Pure, no side effects

### JS world (runtime)
```javascript
// Generated from Gleam by extension_generator
const result = await agent_identity_get_resolved_identity({
    is_idle: ctx.isIdle(),
    model_id: ctx.model?.id,
    provider: ctx.model?.provider,
    thinking_level: ctx.model?.thinkingLevel,
    cwd: ctx.cwd
});
```
- Runs inside Pi
- Has access to `ctx`
- Calls the SAME function

**Gleam is JS. JS is Gleam.** The function is the bridge.

## Everything is Pure Function

| Function | Input | Output | Pure? |
|----------|-------|--------|-------|
| `get_resolved_identity` | `Context` | `AgentIdentity` | ✅ Yes |
| `generate_semantic_id` | `Context` | `String` (ID) | ✅ Yes |
| `on_session_start` | `Context` | `Result(Nil, Error)` | ✅ Yes |
| `on_model_select` | `Context` | `Result(Nil, Error)` | ✅ Yes |
| `on_tool_call` | `Context` | `Result(String, Error)` | ✅ Yes |
| `on_tool_result` | `Context` | `Result(Nil, Error)` | ✅ Yes |
| `on_agent_end` | `Context` | `Result(String, Error)` | ✅ Yes |

Every hook takes `Context` and returns a `Result`. No side effects. No hidden state.

## Context is King

`Context` is the SINGLE source of truth. It flows through the entire system:

```
ctx (Pi runtime)
  ↓
Context (Gleam type)
  ↓
get_resolved_identity(ctx)
  ↓
AgentIdentity { id: "A-psypi-openrouter/owl-alpha" }
  ↓
ID flows into:
  - System prompt ("You are A-psypi-openrouter/owl-alpha")
  - Activity log
  - Event hooks
  - Message metadata
```

## No More JS Strings

Old way:
```gleam
lit("ctx.model?.id || ''")  // JS expression hidden in Gleam
```

New way:
```gleam
ctx.model_id  // Pure Gleam field
```

The `Context` type carries all the data. No JS expression strings needed.

## File Structure

```
src/
  agent_identity.gleam       -- Context type + get_resolved_identity
  agent_identity_logic.gleam -- generate_semantic_id (pure)
  agent_identity_types.gleam -- AgentIdentity, AgentId, IdentityError
  agent_end.gleam            -- agent_end hook (calls get_resolved_identity)
  autonomic_hooks.gleam      -- simple hooks (all take Context)
  pi_tool_call.gleam         -- PiEventHook, PiToolCall types
  extension_generator.gleam  -- generates JS from Gleam values
```

Each file is small (< 100 lines). Each function is pure. Everything composes.
