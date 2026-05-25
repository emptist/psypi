# Create a Custom Tool

## Required Reading

- `references/gotchas.md` — read this first, especially the tool definition section

## Process

1. **Copy the template**
   ```bash
   cp templates/tool.ts /path/to/extension/my-tool.ts
   ```

2. **Fill in the TODOs**
   - `name`: unique, lowercase_with_underscores
   - `label`: human-readable name
   - `description`: what it does (shown to LLM — be specific)
   - `promptSnippet`: one-line for Available tools section
   - `promptGuidelines`: "Use {name} when..." (name the tool explicitly!)
   - `parameters`: TypeBox schema
   - `execute()`: your logic

3. **Handle errors correctly**
   - Throw errors, don't return `{ isError: true }`
   - Check `signal?.aborted` for cancellation

4. **Truncate large output**
   - Use `truncateHead` / `truncateTail` for potentially large results
   - Default limit: 50KB / 2000 lines

5. **File mutations?**
   - Wrap in `withFileMutationQueue(absPath, fn)` to avoid races

6. **String enums?**
   - Use `StringEnum(["a", "b"] as const)` from `@earendil-works/pi-ai`
   - NOT `Type.Union([Type.Literal("a"), ...])` — breaks Google API

7. **Register in your extension**
   ```typescript
   import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
   export default function (pi: ExtensionAPI) {
     pi.registerTool({ /* your tool definition */ });
   }
   ```

8. **Test**
   ```bash
   pi -e ./my-tool.ts
   ```
   Then ask the agent to use the tool.

## Success Criteria

- [ ] Tool name is unique (doesn't collide with builtins unless intentional)
- [ ] Description is clear and specific (LLM uses this to decide when to call it)
- [ ] String enums use `StringEnum`, not `Type.Union`
- [ ] Errors are thrown, not returned
- [ ] Large output is truncated
- [ ] File mutations use `withFileMutationQueue`
- [ ] Tool works when agent calls it via Pi TUI
