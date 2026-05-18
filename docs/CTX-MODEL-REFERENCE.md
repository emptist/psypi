# ctx.model — Live Model Reference

## How Pi Exposes the Current Model to Extensions

### The Short Answer

`ctx.model` is a **live getter** on `ExtensionContext`. It always reflects the current
model, even if the user changes it mid-session via `/model` or `Ctrl+P`.

```javascript
// In any event handler or tool execute() callback:
ctx.model.id            // "openrouter/owl-alpha"
ctx.model.thinkingLevel // "medium" (or "" when off)
ctx.model.provider      // "openrouter"
ctx.model.contextWindow // 128000
```

### Why It's Live (Source Code Proof)

In `packages/coding-agent/src/core/extensions/runner.ts`, the `createContext()` method
builds the context object using **getters**, not plain property assignments:

```typescript
createContext(): ExtensionContext {
    const runner = this;
    const getModel = this.getModel;  // captured once, but delegates to live source
    return {
        get model() {
            runner.assertActive();
            return getModel();  // calls this.getModel on every access
        },
        // ... all other properties are also getters
    };
}
```

`this.getModel` is bound at `bindCore()` time:

```typescript
this.getModel = contextActions.getModel;
```

Which comes from `agent-session.ts`:

```typescript
getModel: () => this.model,  // live reference to AgentSession.model
```

**Result:** Every read of `ctx.model` goes through: `ctx.model` → getter → `getModel()` → `AgentSession.model` → current model.

### What Happens When the Model Changes

When a user runs `/model` or presses `Ctrl+P`:

1. `AgentSession.setModel(newModel)` is called
2. `AgentSession.model` is updated to `newModel`
3. A `model_select` event fires (extensions can listen via `pi.on("model_select", ...)`)
4. **Next read of `ctx.model`** returns the new model — no restart needed

### What About settings.json?

`settings.json` is **NOT** updated when the model changes mid-session. It's only
written at startup. Do NOT use it as the source of truth for the current model.

```bash
# WRONG - settings.json is stale after /model change
cat ~/.pi/agent/settings.json | grep defaultModel

# CORRECT - use ctx.model in extension code
# ctx.model is always current
```

### Complete ctx.model API

From the Pi SDK `Model<TApi>` interface (`packages/ai/src/types.ts`):

| Property           | Type                                     | Example                        | Description                       |
| ------------------ | ---------------------------------------- | ------------------------------ | --------------------------------- |
| `id`               | `string`                                 | `openrouter/owl-alpha`         | Full model ID                     |
| `name`             | `string`                                 | `Owl Alpha`                    | Display name                      |
| `provider`         | `Provider`                               | `openrouter`                   | Provider name                     |
| `api`              | `Api`                                    | `openai-completions`           | API type                          |
| `baseUrl`          | `string`                                 | `https://openrouter.ai/api/v1` | API endpoint                      |
| `reasoning`        | `boolean`                                | `true`                         | Supports reasoning/thinking       |
| `thinkingLevelMap` | `ThinkingLevelMap`                       | —                              | Maps pi levels to provider values |
| `input`            | `("text"\|"image")[]`                    | `["text", "image"]`            | Supported input types             |
| `cost`             | `{input, output, cacheRead, cacheWrite}` | —                              | Cost per million tokens           |
| `contextWindow`    | `number`                                 | `128000`                       | Max context tokens                |
| `maxTokens`        | `number`                                 | `8192`                         | Max output tokens                 |
| `thinkingLevel`    | `string`                                 | `medium`                       | **Current active thinking level** |

### Thinking Level Values

From `packages/ai/src/types.ts`:

```typescript
export type ThinkingLevel = "minimal" | "low" | "medium" | "high" | "xhigh";
export type ModelThinkingLevel = "off" | ThinkingLevel;
```

`ctx.model.thinkingLevel` returns the **current active** thinking level. When thinking
is off, it returns `""` (empty string).

### What's on pi (ExtensionAPI) but NOT on ctx

| Method                              | Description                                            |
| ----------------------------------- | ------------------------------------------------------ |
| `pi.setModel(model)`                | Change the current model                               |
| `pi.getThinkingLevel()`             | Get thinking level (also on `ctx.model.thinkingLevel`) |
| `pi.setThinkingLevel(level)`        | Set thinking level                                     |
| `pi.sendMessage(msg, opts)`         | Inject custom message into session                     |
| `pi.sendUserMessage(content, opts)` | Send user message to agent                             |
| `pi.getActiveTools()`               | Get currently active tool names                        |
| `pi.getAllTools()`                  | Get all configured tools                               |
| `pi.setActiveTools(names)`          | Enable/disable tools at runtime                        |

### What's NOT Available Anywhere

- **`pi.getModel()`** — does NOT exist. Use `ctx.model` instead.
- **`ctx.getThinkingLevel()`** — does NOT exist. Use `ctx.model.thinkingLevel` instead.
- **Persistent "current model" in settings.json** — only written at startup.

### All ctx Properties (ExtensionContext)

From `packages/coding-agent/src/core/extensions/types.ts`:

```typescript
interface ExtensionContext {
    ui: ExtensionUIContext;           // notify, setStatus, select, confirm, etc.
    hasUI: boolean;                   // false in print/RPC mode
    cwd: string;                      // current working directory
    sessionManager: ReadonlySessionManager;  // session state (read-only)
    modelRegistry: ModelRegistry;     // for API key resolution
    model: Model<any> | undefined;    // ✅ LIVE current model
    isIdle(): boolean;                // true when agent not streaming
    signal: AbortSignal | undefined;  // current abort signal
    abort(): void;                    // abort current operation
    hasPendingMessages(): boolean;    // queued messages waiting
    shutdown(): void;                 // graceful shutdown
    getContextUsage(): ContextUsage | undefined;  // token usage stats
    compact(options?: CompactOptions): void;      // trigger compaction
    getSystemPrompt(): string;        // current effective system prompt
}
```

### ContextUsage — Token Stats

```typescript
interface ContextUsage {
    tokens: number | null;       // estimated context tokens used
    contextWindow: number;       // model's context window
    percent: number | null;      // usage as percentage
}
```

Usage in A-agentbot decision logic:

```javascript
const usage = ctx.getContextUsage();
if (usage && usage.percent !== null) {
    if (usage.percent > 90) {
        // PRESERVE mode — save what we can
    } else if (usage.percent > 70) {
        // CONSOLIDATE mode — summarize and commit
    } else if (usage.percent > 30) {
        // COLLABORATE mode — review with S
    } else {
        // PLAN mode — plenty of context, plan ahead
    }
}
```

### How psypi Uses This

The identity tools (`psypi-somatic-id`, `psypi-autonomic-id`) read `ctx.model` at
call time to build model-aware IDs:

```javascript
// Generated extension.js
async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const result = await agent_identity_get_resolved_identity(
        false,                              // autonomous = false (S-agentbot)
        "psypi",                            // project
        "psypi",                            // source
        (ctx.model?.id || ''),             // model — LIVE, always current
        (ctx.model?.thinkingLevel || '')   // thinking level — LIVE
    );
}
```

This produces IDs like:
```
S-psypi-psypi-openrouter/owl-alpha          # thinking off
S-psypi-psypi-openrouter/owl-alpha-medium   # medium reasoning
A-psypi-psypi-anthropic/claude-opus-4-5-high # high reasoning
```

### Session File Records Model Changes

The session `.jsonl` file records `model_change` events:

```json
{"type":"model_change","id":"02d6a750","timestamp":"2026-05-15T10:22:36.536Z","provider":"openrouter","modelId":"openrouter/owl-alpha"}
```

Each assistant message also records which model produced it:

```json
{"type":"message","message":{"role":"assistant","api":"openai-completions","provider":"openrouter","model":"openrouter/owl-alpha","usage":{"input":10212,"output":129,...}}}
```

### References

- `packages/coding-agent/src/core/extensions/types.ts` — ExtensionContext, Model, ThinkingLevel interfaces
- `packages/coding-agent/src/core/extensions/runner.ts` — createContext() getter wiring (line 573)
- `packages/coding-agent/src/core/agent-session.ts` — getModel binding (line 2203), setModel (line 2118)
- `packages/ai/src/types.ts` — Model interface (line 528), ThinkingLevel type (line 65)
- `docs/AGENT-IDENTITY.md` — psypi identity system documentation
