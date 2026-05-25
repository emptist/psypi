# Agent Identity — Final Design

## One Function, One Argument

```gleam
semantic_id(ctx: IdentityContext) -> Result(String, IdentityError)
```

That's it. One argument. Everything comes from `ctx`.

## IdentityContext Type

```gleam
pub type IdentityContext {
  IdentityContext(
    is_idle: Bool,
    project: String,
    source: String,
    model: String,
    thinking_level: String,
    global: Bool,
    cwd: String,
  )
}
```

## How It Works

```gleam
pub fn semantic_id(ctx: IdentityContext) -> Result(String, IdentityError) {
  let prefix = case ctx.is_idle {
    True -> "A"
    False -> "S"
  }
  // ... build ID: "A-tools_ai-openrouter-owl-alpha-high"
}
```

## Call Sites

### S-agentbot (always is_idle=false)
```javascript
agent_identity_types_semantic_id({
    is_idle: false,
    project: "tools_ai",
    source: ctx.model?.provider,
    model: ctx.model?.id,
    thinking_level: ctx.model?.thinkingLevel,
    global: false,
    cwd: ctx.cwd
})
```

### A-agentbot (always is_idle=true)
```javascript
agent_identity_types_semantic_id({
    is_idle: true,
    project: "tools_ai",
    source: ctx.model?.provider,
    model: ctx.model?.id,
    thinking_level: ctx.model?.thinkingLevel,
    global: false,
    cwd: ctx.cwd
})
```

### agent_end coordination (dynamic)
```javascript
agent_identity_types_semantic_id({
    is_idle: ctx.isIdle(),    // DYNAMIC — depends on S-agentbot state
    project: "tools_ai",
    source: ctx.model?.provider,
    model: ctx.model?.id,
    thinking_level: ctx.model?.thinkingLevel,
    global: false,
    cwd: ctx.cwd
})
```

## Key Insight

The `is_idle` field means different things in different contexts:
- **S-agentbot**: always `false` (S is working when it calls this)
- **A-agentbot**: always `true` (A is always idle/event-driven)
- **agent_end**: `ctx.isIdle()` (dynamic — is S still idle?)

The function doesn't care WHAT `is_idle` means. It just builds the ID. The caller decides.

## Benefits

1. **One function signature** — no more 6 arguments
2. **Type-safe** — `IdentityContext` type ensures all fields are present
3. **Composable** — construct `IdentityContext` once, pass to function
4. **Testable** — create an `IdentityContext` value in tests, no mock `ctx` needed
5. **Clear** — the function signature shows exactly what it needs

## Files

| File | Role |
|------|------|
| `src/agent_identity_types.gleam` | `IdentityContext`, `semantic_id()`, `IdentityError` |
| `src/agent_identity.gleam` | `get_enriched_identity()`, `my_id_tool()` |
