# Create a Slash Command

## Required Reading

- `references/gotchas.md` — command section

## Process

1. **Copy the template**
   ```bash
   cp templates/command.ts /path/to/extension/my-command.ts
   ```

2. **Fill in the TODOs**
   - `name`: unique command name (no leading `/`)
   - `description`: shown in `/help`
   - `handler`: receives `(args, ctx)` — args is the string after the command

3. **Add argument completion (optional)**
   ```typescript
   getArgumentCompletions: (prefix) => {
     return ["dev", "staging", "prod"]
       .filter(o => o.startsWith(prefix))
       .map(o => ({ value: o, label: o }));
   },
   ```

4. **Register in your extension**
   ```typescript
   import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
   export default function (pi: ExtensionAPI) {
     pi.registerCommand("my-command", { ... });
   }
   ```

5. **Test**
   ```bash
   pi -e ./my-command.ts
   ```
   Then type `/my-command someargs` in the TUI.

## Success Criteria

- [ ] Command name is unique (or you're OK with numbered suffixes)
- [ ] Handler responds appropriately to args
- [ ] Uses `ctx.ui.notify()` or other UI for feedback
- [ ] `ctx.hasUI` checked before UI calls
- [ ] Command works from TUI
