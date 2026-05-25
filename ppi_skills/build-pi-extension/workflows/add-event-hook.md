# Add Event Hooks

## Required Reading

- `references/events.md` — event lifecycle cheat sheet
- `references/gotchas.md` — event hook section

## Process

1. **Copy the template**
   ```bash
   cp templates/event-hook.ts /path/to/extension/my-hooks.ts
   ```

2. **Pick the events you need**

   | Need | Event |
   |---|---|
   | Init/cleanup | `session_start` / `session_shutdown` |
   | Modify system prompt before LLM | `before_agent_start` |
   | Block dangerous tool calls | `tool_call` |
   | Post-process tool results | `tool_result` |
   | React after agent finishes | `agent_end` |
   | Intercept user input | `input` |
   | Prune conversation | `context` |
   | React to model change | `model_select` |

3. **Implement handlers**

   Key patterns:
   ```typescript
   // Block a tool call
   pi.on("tool_call", async (event, ctx) => {
     if (event.toolName === "bash" && event.input.command?.includes("rm -rf")) {
       return { block: true, reason: "Dangerous" };
     }
   });

   // Modify tool result
   pi.on("tool_result", async (event, ctx) => {
     return { content: [{ type: "text", text: "Modified" }] };
   });

   // Inject message before agent starts
   pi.on("before_agent_start", async (event, ctx) => {
     return {
       message: { customType: "my-ext", content: "Context", display: true },
     };
   });
   ```

4. **Register in your extension**
   ```typescript
   import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
   export default function (pi: ExtensionAPI) {
     pi.on("event_name", handler);
   }
   ```

## Success Criteria

- [ ] Handlers return correct shape for their event type
- `tool_call`: returns `{ block: true, reason }` or nothing
- `tool_result`: returns `{ content, details }` or nothing
- `before_agent_start`: returns `{ message, systemPrompt }` or nothing
- `input`: returns `{ action: "continue" | "transform" | "handled" }`
- [ ] Handlers don't throw (errors in `tool_call` block the tool — fail-safe)
- [ ] Async work uses `ctx.signal` for abort awareness
