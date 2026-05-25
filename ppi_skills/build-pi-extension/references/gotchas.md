# Pi Extension Gotchas

Non-obvious pitfalls that will bite you. Read this before implementing.

## Tool Definition Gotchas

### String Enums
```typescript
// ❌ WRONG — breaks Google API
parameters: Type.Object({
  action: Type.Union([Type.Literal("list"), Type.Literal("add")]),
})

// ✅ CORRECT — use StringEnum
import { StringEnum } from "@earendil-works/pi-ai";
parameters: Type.Object({
  action: StringEnum(["list", "add"] as const),
})
```

### Error Signaling
```typescript
// ❌ WRONG — isError is never set by returning it
return { content: [...], details: { error: "fail" }, isError: true };

// ✅ CORRECT — throw to signal errors
throw new Error("Something went wrong");
```

### Tool Output Truncation
```typescript
// ❌ WRONG — unbounded output can overflow context
return { content: [{ type: "text", text: hugeString }] };

// ✅ CORRECT — truncate with utilities
import { truncateHead, DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES } from "@earendil-works/pi-coding-agent";
const result = truncateHead(hugeString, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES });
return { content: [{ type: "text", text: result.content }] };
```

### File Mutation Races
```typescript
// ❌ WRONG — races with built-in edit/write on same file
async execute(toolCallId, params, signal, onUpdate, ctx) {
  const content = await readFile(path, "utf8");
  await writeFile(path, transform(content));
}

// ✅ CORRECT — use the file mutation queue
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
async execute(toolCallId, params, signal, onUpdate, ctx) {
  const absolutePath = resolve(ctx.cwd, params.path);
  return withFileMutationQueue(absolutePath, async () => {
    const content = await readFile(absolutePath, "utf8");
    await writeFile(absolutePath, transform(content));
    return { content: [{ type: "text", text: "Done" }], details: {} };
  });
}
```

### Path Arguments
Some models prefix paths with `@`. Built-in tools strip this. If your tool accepts paths, strip a leading `@` too:
```typescript
const cleanPath = params.path.replace(/^@/, "");
```

## Event Hook Gotchas

### tool_call Blocking
- `event.input` is **mutable** — mutate in place to patch arguments
- Later handlers see earlier mutations
- No re-validation after mutation
- Return `{ block: true, reason: string }` to block

### tool_result Chaining
- Handlers run in extension load order (middleware chain)
- Each handler sees the result of the previous one
- Return partial patches: `{ content: [...], details: {...} }`

### before_agent_start System Prompt
- `event.systemPrompt` reflects chained changes from earlier handlers
- `ctx.getSystemPrompt()` returns the same chained value
- Later handlers can still override your changes
- Does NOT include `before_provider_request` payload rewrites

### Context Event
- `event.messages` is a **deep copy** — safe to modify
- Return `{ messages: filtered }` to change what the LLM sees

## UI Gotchas

### Non-Interactive Modes
```typescript
// ❌ WRONG — crashes in print/JSON mode
const ok = await ctx.ui.confirm("Delete?", "Are you sure?");

// ✅ CORRECT — check first
if (ctx.hasUI) {
  const ok = await ctx.ui.confirm("Delete?", "Are you sure?");
  if (!ok) return;
}
```

### Dialog Timeouts
```typescript
// Auto-dismiss with countdown
const ok = await ctx.ui.confirm("Title", "Message", { timeout: 5000 });
// Returns false on timeout
```

## State Management Gotchas

### State Reconstruction
Store state in tool result `details`, reconstruct from session on `session_start`:
```typescript
pi.on("session_start", async (_event, ctx) => {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "message" && entry.message.role === "toolResult") {
      if (entry.message.toolName === "my_tool") {
        myState = entry.message.details?.state ?? defaultState;
      }
    }
  }
});
```

### Session Replacement
In `newSession`/`fork`/`switchSession` `withSession` callbacks:
- **Don't** use captured old `pi` or old `ctx` — they're stale
- **Do** use the fresh `ctx` passed to the callback
- Old session objects throw if used after replacement

## Command Gotchas

### Command Name Collisions
If two extensions register `/stats`, Pi keeps both as `/stats:1` and `/stats:2`. Use unique names.

### Argument Completion
```typescript
pi.registerCommand("deploy", {
  getArgumentCompletions: (prefix) => {
    return ["dev", "staging", "prod"]
      .filter(e => e.startsWith(prefix))
      .map(e => ({ value: e, label: e }));
  },
  handler: async (args, ctx) => { ... },
});
```

## Lifecycle Gotchas

### Async Factory
If you need async init (fetching models, remote config), return a Promise from the factory:
```typescript
export default async function (pi: ExtensionAPI) {
  const models = await fetchRemoteModels();
  pi.registerProvider("custom", { ... });
}
```
Pi awaits the factory before continuing startup.

### Session Shutdown Cleanup
```typescript
pi.on("session_shutdown", async (event, ctx) => {
  // event.reason: "quit" | "reload" | "new" | "resume" | "fork"
  // Close connections, save state, etc.
});
```

### Reload Behavior
```typescript
await ctx.reload();
return; // Treat as terminal — old code continues running but state may be stale
```

## Common Patterns That Look Right But Aren't

| Pattern | Problem | Fix |
|---|---|---|
| `Type.Literal` for enums | Breaks Google API | `StringEnum` |
| `return { isError: true }` | Never sets error flag | `throw new Error()` |
| `return { terminate: true }` alone | Only works if ALL tools in batch return it | Ensure all tools cooperate |
| `ctx.getSystemPrompt()` in `before_provider_request` | Returns Pi's prompt, not provider payload | Inspect `event.payload` directly |
| `pi.on("tool_call", ...)` for state | State not synced for parallel sibling tools | Use `tool_result` or `turn_end` |
| Large tool output | Context overflow | Truncate to 50KB/2000 lines |
