# Agent Identity — Final Design

## One Function, One Argument

```gleam
get_resolved_identity(ctx: Context) -> Result(AgentIdentity, IdentityError)
```

That's it. One argument. Everything comes from `ctx`.

## Context Type

```gleam
pub type Context {
  Context(
    is_idle: Bool,        // ctx.isIdle() — determines A/S prefix
    model_id: String,     // ctx.model?.id
    provider: String,     // ctx.model?.provider
    thinking_level: String, // ctx.model?.thinkingLevel
    cwd: String,          // ctx.cwd — determines project/global
  )
}
```

## How It Works

```gleam
pub fn get_resolved_identity(ctx: Context) -> Result(AgentIdentity, IdentityError) {
  let autonomous = ctx.is_idle  // idle → A-agentbot, busy → S-agentbot
  // ... build ID from ctx fields
}
```

## Call Sites

### S-agentbot tool (always autonomous=false)
```javascript
agent_identity_get_resolved_identity({
    is_idle: false,           // S-agentbot is never "idle" when it's working
    model_id: ctx.model?.id,
    provider: ctx.model?.provider,
    thinking_level: ctx.model?.thinkingLevel,
    cwd: ctx.cwd
})
```

### A-agentbot tool (always autonomous=true)
```javascript
agent_identity_get_resolved_identity({
    is_idle: true,            // A-agentbot is always "idle" (event-driven)
    model_id: ctx.model?.id,
    provider: ctx.model?.provider,
    thinking_level: ctx.model?.thinkingLevel,
    cwd: ctx.cwd
})
```

### agent_end coordination (dynamic)
```javascript
agent_identity_get_resolved_identity({
    is_idle: ctx.isIdle(),    // DYNAMIC — depends on S-agentbot state
    model_id: ctx.model?.id,
    provider: ctx.model?.provider,
    thinking_level: ctx.model?.thinkingLevel,
    cwd: ctx.cwd
})
```

## Key Insight

The `is_idle` field means different things in different contexts:
- **S-agentbot tool**: always `false` (S-agentbot is working when it calls this)
- **A-agentbot tool**: always `true` (A-agentbot is always idle/event-driven)
- **agent_end**: `ctx.isIdle()` (dynamic — is S-agentbot still idle?)

The function doesn't care WHAT `is_idle` means. It just builds the ID. The caller decides.

## Benefits

1. **One function signature** — no more 6 arguments
2. **Type-safe** — `Context` type ensures all fields are present
3. **Composable** — construct `Context` once, pass to function
4. **Testable** — create a `Context` value in tests, no mock `ctx` needed
5. **Clear** — the function signature shows exactly what it needs

## Migration

Old:
```gleam
get_resolved_identity(autonomous, project, source, model, thinking_level, global)
```

New:
```gleam
get_resolved_identity(ctx: Context)
```

All callers construct a `Context` value and pass it. The function stays pure.
