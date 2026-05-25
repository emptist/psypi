# Build a Full Extension

## Required Reading

- `references/gotchas.md` — read entirely
- `references/events.md` — event lifecycle
- `references/state.md` — state management patterns

## Process

1. **Copy the template**
   ```bash
   cp templates/full-extension.ts ~/.pi/agent/extensions/my-extension.ts
   ```

2. **Plan your extension**
   - What tools does the LLM need? → `pi.registerTool()`
   - What slash commands do users need? → `pi.registerCommand()`
   - What lifecycle events matter? → `pi.on("event", handler)`
   - Does it need state? → see `references/state.md`

3. **Implement in order**
   1. State reconstruction (`session_start`)
   2. Custom tools (see `workflows/create-tool.md`)
   3. Slash commands (see `workflows/create-command.md`)
   4. Event hooks (see `workflows/add-event-hook.md`)
   5. Cleanup (`session_shutdown`)

4. **Apply gotchas**
   - String enums → `StringEnum`
   - Errors → `throw`
   - Large output → `truncateHead` / `truncateTail`
   - File mutations → `withFileMutationQueue`
   - UI calls → check `ctx.hasUI`
   - `promptGuidelines` → name the tool explicitly

5. **Test**
   ```bash
   pi -e ./my-extension.ts
   ```
   - Verify tools appear and are callable
   - Verify commands work with `/`
   - Verify event hooks fire correctly
   - Test `/reload` to ensure state reconstruction works

## Success Criteria

- [ ] Extension loads without errors
- [ ] All tools are callable by the LLM
- [ ] All commands work from TUI
- [ ] Event hooks fire at the right time
- [ ] State survives `/reload` (reconstructed from session)
- [ ] No gotchas from `references/gotchas.md` are violated
- [ ] Cleanup runs on `session_shutdown`
