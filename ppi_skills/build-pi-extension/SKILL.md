---
name: build-pi-extension
description: Build Pi TUI extensions with tools, commands, hooks, and UI. Provides copy-paste templates and gotchas for the most common extension patterns. Use when creating new Pi extensions, adding custom tools, registering event hooks, or building interactive TUI components.
---

<objective>
Help agents quickly build Pi extensions by providing ready-to-use templates, common patterns, and non-obvious gotchas — without re-reading the full 2600-line extension doc.
</objective>

<essential_principles>

## Pi Extension Essentials

### What Extensions Are
TypeScript modules (no compilation needed — Pi uses jiti). Default-export a factory function that receives `ExtensionAPI`:

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
export default function (pi: ExtensionAPI) { ... }
```

### Where They Live
| Location | Scope |
|---|---|
| `~/.pi/agent/extensions/*.ts` | Global |
| `.pi/extensions/*.ts` | Project-local |
| Subdirectory with `index.ts` | Multi-file |

Test quickly: `pi -e ./my-extension.ts`

### Three Extension Styles
1. **Single file** — `extensions/my-ext.ts` (simplest)
2. **Directory** — `extensions/my-ext/index.ts` (multi-file)
3. **Package** — with `package.json` + `node_modules/` (npm deps)

### Core Capabilities
- **Tools** — `pi.registerTool()` — LLM-callable functions
- **Commands** — `pi.registerCommand()` — slash commands like `/mycmd`
- **Events** — `pi.on("event_name", handler)` — lifecycle hooks
- **UI** — `ctx.ui.notify/select/confirm/input/custom()` — user interaction
- **Messages** — `pi.sendMessage()` — inject messages into session
- **Providers** — `pi.registerProvider()` — add model providers

### Critical Rules
1. Use `StringEnum` from `@earendil-works/pi-ai` for string enums — `Type.Union`/`Type.Literal` breaks Google's API
2. **Throw** errors from tool `execute()` — don't return error flags
3. Use `withFileMutationQueue()` when editing files — avoids races with built-in tools
4. Truncate tool output to 50KB / 2000 lines — use `truncateHead`/`truncateTail`
5. `promptGuidelines` must name the tool explicitly — "Use my_tool when..." not "Use this tool when..."
6. Check `ctx.hasUI` before UI calls in non-interactive modes

</essential_principles>

<intake>
What do you want to build?

1. Custom tool (LLM-callable)
2. Slash command
3. Event hook (react to lifecycle)
4. Tool + command combo
5. Full extension (multiple capabilities)
6. Something else

**Wait for response before proceeding.**
</intake>

<routing>
| Response | Action |
|----------|--------|
| 1, "tool", "custom tool" | → `workflows/create-tool.md` + `templates/tool.ts` |
| 2, "command", "slash command" | → `workflows/create-command.md` + `templates/command.ts` |
| 3, "hook", "event", "event hook" | → `workflows/add-event-hook.md` + `templates/event-hook.ts` |
| 4, "combo", "tool and command" | → `workflows/create-tool.md` then `workflows/create-command.md` |
| 5, "full extension", "complete" | → `workflows/build-full-extension.md` + `templates/full-extension.ts` |
| 6, other | Clarify intent, then route |

**After scaffolding, always read `references/gotchas.md` before implementing logic.**
</routing>

<reference_index>
## References

| File | Content |
|---|---|
| `references/gotchas.md` | Non-obvious pitfalls and best practices |
| `references/events.md` | Event lifecycle cheat sheet |
| `references/ui-patterns.md` | UI interaction patterns |
| `references/state.md` | State management patterns |

**For deep reference:** `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/docs/extensions.md`
**For examples:** `/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/`
</reference_index>

<workflows_index>
## Workflows

| File | Purpose |
|---|---|
| `workflows/create-tool.md` | Scaffold a custom tool |
| `workflows/create-command.md` | Scaffold a slash command |
| `workflows/add-event-hook.md` | Add event listeners |
| `workflows/build-full-extension.md` | Build a complete extension |

**Required reading for all workflows:** `references/gotchas.md`
</workflows_index>

<templates_index>
## Templates

| File | Purpose |
|---|---|
| `templates/tool.ts` | Custom tool scaffold |
| `templates/command.ts` | Slash command scaffold |
| `templates/event-hook.ts` | Event hook scaffold |
| `templates/full-extension.ts` | Complete extension scaffold |

Copy a template, fill in your logic, done.
</templates_index>

<success_criteria>
A working Pi extension:
- File is in an auto-discovered extension location (or use `pi -e ./path.ts` for testing)
- Tool/command names don't collide with builtins (unless intentionally overriding)
- Tool output is truncated if potentially large
- Errors are thrown, not returned as flags
- File mutations use `withFileMutationQueue()`
- String enums use `StringEnum` not `Type.Union`
- `ctx.hasUI` checked before UI calls if extension might run in non-interactive mode
</success_criteria>
