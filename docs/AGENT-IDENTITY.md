# Agent Identity System

## ID Format

```
(A|S)-source-project-model[-thinking_level]
```

| Segment          | Description                         | Example                |
| ---------------- | ----------------------------------- | ---------------------- |
| `A\|S`           | Agentbot type: Autonomic or Somatic | `A` or `S`             |
| `source`         | Origin system                       | `psypi`                |
| `project`        | Project name                        | `psypi`                |
| `model`          | Model ID from `ctx.model.id`        | `openrouter/owl-alpha` |
| `thinking_level` | *(optional)* Active thinking level  | `medium`, `high`       |

### Examples

```
S-psypi-psypi-openrouter/owl-alpha
S-psypi-psypi-openrouter/owl-alpha-medium
A-psypi-psypi-anthropic/claude-opus-4-5-high
A-psypi-psypi-openrouter/owl-alpha
```

## Design Rationale

**Why model instead of session_id?**

The previous ID format used `session_id` as the differentiator:
```
S-psypi-psypi-<uuid>   →  S-psypi-psypi-019e2b28-d3b0-737a-978f-0ad79b7fb161
```

Session IDs are ephemeral — they change every session, making them useless for
persistent identity tracking. The **model** is far more meaningful because it
captures *what kind of intelligence* is operating. Two IDs with the same model
represent the same reasoning capability, even across sessions.

**Why thinking level is optional:**

Not all models support reasoning/thinking modes. When `thinking_level` is empty
(or the model doesn't support it), the segment is omitted entirely. When present,
it distinguishes different reasoning modes of the same model:
```
S-psypi-psypi-openrouter/owl-alpha          # thinking off
S-psypi-psypi-openrouter/owl-alpha-medium   # medium reasoning
S-psypi-psypi-openrouter/owl-alpha-high     # high reasoning
```

## How Model Info Gets Into the ID

### The `ctx.model` Live Reference

The Pi SDK provides `ctx.model` on the `ExtensionContext` object passed to every
event handler and tool `execute()` callback. This is a **live getter** — it reads
`AgentSession.model` at the moment of access, so it always reflects the current
model even if the user changed it mid-session via `/model` or `Ctrl+P`.

```typescript
// In extension.js — generated from Gleam PiToolCall values
async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    // ctx.model is ALWAYS the current model
    const modelId = ctx.model?.id || '';        // e.g. "openrouter/owl-alpha"
    const thinking = ctx.model?.thinkingLevel || ''; // e.g. "medium" or ""
}
```

### What `ctx.model` Contains

From the Pi SDK `Model<TApi>` interface:

| Field              | Type               | Example                           |
| ------------------ | ------------------ | --------------------------------- |
| `id`               | `string`           | `openrouter/owl-alpha`            |
| `name`             | `string`           | `Owl Alpha`                       |
| `provider`         | `Provider`         | `openrouter`                      |
| `api`              | `Api`              | `openai-completions`              |
| `reasoning`        | `boolean`          | `true`                            |
| `thinkingLevelMap` | `ThinkingLevelMap` | maps pi levels to provider values |
| `contextWindow`    | `number`           | `128000`                          |
| `maxTokens`        | `number`           | `8192`                            |

### Thinking Level: `ctx.model.thinkingLevel`

The `ctx.model` object includes the **current active thinking level** as a
property. This is the live value — it updates when the user changes thinking
level via settings, keybindings, or `pi.setThinkingLevel()`.

Possible values: `"off"`, `"minimal"`, `"low"`, `"medium"`, `"high"`, `"xhigh"`

When `"off"` or empty, the thinking_level segment is omitted from the ID.

### Fallback: Empty String

When `ctx.model` is `undefined` (should not happen in normal operation, but
defensive coding), both `model` and `thinking_level` fall back to `''`. The ID
generator handles this gracefully — the model segment is omitted, producing:
```
S-psypi-psypi
```

## Gleam Implementation

### `IdentityContext` — Single Argument Type

```gleam
pub type IdentityContext {
  IdentityContext(
    is_idle: Bool,        // ctx.isIdle() — determines A/S prefix
    project: String,      // from ctx.cwd
    source: String,       // from ctx.model.provider
    model: String,        // from ctx.model.id
    thinking_level: String, // from ctx.model.thinkingLevel
    global: Bool,         // whether no .git found in cwd
  )
}
```

All fields come from the live Pi runtime. No hidden state. No DB access.

### `agent_identity_logic.gleam` — ID Generation

```gleam
pub fn generate_semantic_id(
  ctx: IdentityContext,
) -> Result(String, IdentityError)
```

Pure function. No DB access. Reads `ctx.is_idle` for A/S prefix, `ctx.model` for the ID body.

### `agent_identity.gleam` — Identity Resolution

```gleam
pub fn get_resolved_identity(
  ctx: IdentityContext,
) -> Result(AgentIdentity, IdentityError)
```

Calls `generate_semantic_id` and wraps the result in an `AgentIdentity` record.

### Tool Wrappers

The `somatic_id_tool()` and `autonomic_id_tool()` Gleam functions define
`PiToolCall` values that the generator turns into `pi.registerTool()` blocks.
The generated JS constructs an `IdentityContext` from live `ctx` fields:

```javascript
// Generated in extension.js
const result = await agent_identity_get_resolved_identity({
    is_idle: ctx.isIdle(),              // LIVE — A or S prefix
    project: (function(){ ... }()),     // from ctx.cwd
    source: (ctx.model?.provider || ''),
    model: (ctx.model?.id || ''),       // LIVE — always current model
    thinking_level: (ctx.model?.thinkingLevel || ''),
    global: (function(){ ... }())       // from ctx.cwd
});
```

## Database Storage

The `agent_identities` table stores identities with the new columns:

```sql
ALTER TABLE agent_identities
    ADD COLUMN model VARCHAR(255) DEFAULT '',
    ADD COLUMN thinking_level VARCHAR(20) DEFAULT '';
```

The `agent_identity_db.gleam` module handles INSERT/SELECT with these columns.
When an identity is stored, the model and thinking level are captured at that
moment. On conflict (same ID), the model and thinking level are updated.

## Pi SDK Context Reference

### What's Available on `ctx` (ExtensionContext)

| Property/Method           | Type                      | Live? | Description                          |
| ------------------------- | ------------------------- | ----- | ------------------------------------ |
| `ctx.model`               | `Model<any> \| undefined` | ✅ Yes | Current model object                 |
| `ctx.model.id`            | `string`                  | ✅ Yes | Model ID like `openrouter/owl-alpha` |
| `ctx.model.thinkingLevel` | `string`                  | ✅ Yes | Active thinking level                |
| `ctx.model.provider`      | `Provider`                | ✅ Yes | Provider name                        |
| `ctx.model.contextWindow` | `number`                  | ✅ Yes | Context window size                  |
| `ctx.isIdle()`            | `boolean`                 | ✅ Yes | Agent not streaming                  |
| `ctx.getContextUsage()`   | `ContextUsage`            | ✅ Yes | Token usage stats                    |
| `ctx.sessionManager`      | `ReadonlySessionManager`  | ✅ Yes | Session state                        |

### What's on `pi` (ExtensionAPI) but NOT on `ctx`

| Method                       | Description                            |
| ---------------------------- | -------------------------------------- |
| `pi.setModel(model)`         | Change the current model               |
| `pi.getThinkingLevel()`      | Get thinking level (also on ctx.model) |
| `pi.setThinkingLevel(level)` | Set thinking level                     |
| `pi.sendMessage()`           | Inject custom message into session     |
| `pi.sendUserMessage()`       | Send user message to agent             |

### What's NOT Available Anywhere

- **No `pi.getModel()`** — use `ctx.model` instead
- **No `ctx.getThinkingLevel()`** — use `ctx.model.thinkingLevel` instead
- **No persistent "current model" in settings.json** — that file is only written
  at startup; use `ctx.model` for live values

## Migration from Old Format

Old IDs: `S-psypi-psypi-<session_id>` (ephemeral, session-bound)
New IDs: `S-psypi-psypi-<model_id>[-<thinking_level>]` (intelligence-bound)

The old `session_id` field still exists in the `AgentIdentity` record and the
`agent_identities` table but is no longer part of the generated ID. It remains
available for session correlation if needed.
