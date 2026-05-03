# Guide: How to Ask Pi to Write Extensions (For AI Agents)

**Audience**: Coder AI, Helper AI, and all psypi AI agents  
**Purpose**: Learn to request Pi extensions to automate tasks, hook into events, and extend functionality  
**Prerequisite**: Read `AGENTS.md` first (especially "Report issues first, fix later" rule)

---

## 🎯 What Are Pi Extensions?

Per Pi's official docs, extensions are TypeScript modules that:
- Extend Pi's behavior (TUI, CLI, agent loop)
- Subscribe to **lifecycle events** (session, tools, agents)
- Register custom tools, commands, shortcuts
- Intercept/hook into tool calls and results

**Key Use Cases for psypi AIs**:
1. **Automatic meeting monitoring** (hook into `tool_result` to detect `psypi meeting opinion`)
2. **Auto-issue reporting** (detect errors, create psypi issues automatically)
3. **Session tracking** (log agent sessions to psypi DB via `session_start`/`shutdown`)
4. **Custom psypi shortcuts** (e.g., `/my-tasks` → `psypi tasks --status pending`)

---

## ⚠️ Critical Rules to Follow FIRST

### 1. Report the Need as an Issue (MANDATORY)
Per `AGENTS.md`: "Report issues first, fix later"
```bash
# ✅ CORRECT: Report missing extension need first
psypi issue-add "Need Pi extension for automatic meeting monitoring" --severity high
```

### 2. Use psypi Tools (Not psql)
- ❌ **WRONG**: `psql psypi -c "INSERT INTO issues..."` (bypasses psypi code)
- ✅ **CORRECT**: `psypi issue-add` (tests psypi's issue creation code)

### 3. Use ONE SINGLE WAY for IDs
- Session ID: `await kernel.piSessionID()`
- Agent ID: `await AgentIdentityService.getResolvedIdentity()`

---

## 📚 Prerequisites (Read These First)

### Pi Extension Documentation
**Path**: `/Users/jk/Library/pnpm/global/5/.pnpm/@mariozechner+pi-coding-agent@0.72.1_ws@8.20.0_zod@4.4.2/node_modules/@mariozechner/pi-coding-agent/docs/extensions.md`

**Key Sections to Know**:
| Section | Purpose |
|---------|---------|
| [Events](#events) | Lifecycle events you can hook into |
| [Extension API](#extensionapi-methods) | `pi.on()`, `pi.registerTool()`, `pi.registerCommand()` |
| [ExtensionContext](#extensioncontext) | `ctx.ui`, `ctx.sessionManager`, `ctx.signal` |

### Key Pi Events for psypi Integration
| Event | When It Fires | Use Case for psypi |
|-------|---------------|-------------------|
| `tool_result` | After tool execution (bash, read, etc.) | Detect `psypi meeting opinion` commands |
| `tool_call` | Before tool execution | Block dangerous commands, modify args |
| `session_start` | Session loads/resumes | Initialize extension state |
| `session_shutdown` | Session exits/reloads | Cleanup intervals, save state |
| `turn_end` | After LLM turn completes | Periodic checks for meeting updates |
| `agent_end` | After agent finishes prompt | Summarize work to psypi |

---

## 📝 Step-by-Step: How to Request an Extension from Pi

### Step 1: Define Clear Requirements
Be specific about:
1. **Problem**: What task needs automation?
2. **Events**: Which Pi events to hook into?
3. **Functionality**: What should the extension do?
4. **Commands/Tools**: Any custom commands or tools to register?

**Example Requirements (Meeting Monitor)**:
```markdown
Problem: Need to automatically monitor meeting 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 for new opinions

Events to hook:
- `tool_result`: Detect when `psypi meeting opinion` is executed
- `turn_end`: Periodic check every 10 minutes
- `session_shutdown`: Cleanup intervals

Functionality:
1. Count opinions via `psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`
2. Notify via `ctx.ui.notify()` when new opinions are added
3. Track last opinion count in extension state

Commands:
- `/check-meeting`: Manually trigger a meeting check
- Flag: `--meeting-monitor` to enable/disable
```

### Step 2: Report as Issue First
```bash
psypi issue-add "Request: Pi extension for meeting progress monitoring" \
  --severity high \
  --description "Auto-detect meeting opinions via tool_result event, notify on updates"
```

**If `psypi issue-add` fails** (like we saw earlier with schema errors):
1. Note the failure (this is a bug in psypi!)
2. Report a *separate* issue: `psypi issue-add "psypi issue-add broken: missing created_by column"`
3. Temporarily use psql ONLY to create the issue (document why you bypassed psypi tools!)

### Step 3: Structure Your Prompt to Pi
Send a clear, specific prompt to Pi (TUI or via `pi sendUserMessage`):

#### ✅ GOOD Prompt (Specific, References Docs)
```
Please write a Pi extension per the Extension Docs (extensions.md) with these requirements:

**Extension Name**: meeting-monitor
**Placement**: .pi/extensions/meeting-monitor.ts (project-local)

**Requirements**:
1. Hook into `tool_result` event to detect when `psypi meeting opinion` runs
   - Check if tool_name === "bash" and input.command includes "psypi meeting opinion"
   - After detection, wait 1s, then run `psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`
   - Parse opinion count, notify if new opinions added

2. Hook into `turn_end` event for periodic checks
   - Every 10 minutes (600000ms), run the same meeting check
   - Use setInterval, cleanup on `session_shutdown`

3. Register command `/check-meeting` to manually trigger check

4. Register flag `--meeting-monitor` (boolean, default: true)

5. Use `session_shutdown` to clear intervals

**Key APIs to Use**:
- pi.on("tool_result", (event, ctx) => { ... })
- ctx.ui.notify("message", "info")
- ctx.exec?.("psypi", ["meeting", "show", "7b3e9f1a-..."])

Reference: Pi Extension Docs section on Events > Tool Events > tool_result
```

#### ❌ BAD Prompt (Vague)
```
Write an extension to monitor meetings.
```

### Step 4: Review Pi's Extension Code
Check that Pi's output:
1. Uses correct event names (from Pi docs, not guessed)
2. Doesn't use deprecated APIs (e.g., old `kernel.agentID()`)
3. Uses `ctx.ui.notify()` for user feedback (not console.log)
4. Cleans up resources in `session_shutdown`
5. Follows psypi rules (no psql, uses psypi commands)

### Step 5: Install and Test
1. **Save to project-local extensions folder**:
   ```bash
   # Pi auto-discovers from .pi/extensions/
   .pi/extensions/meeting-monitor.ts
   ```

2. **Reload Pi to load extension**:
   ```bash
   # In Pi TUI:
   /reload
   ```

3. **Test with psypi tools only**:
   ```bash
   # Test manual command
   /check-meeting
   
   # Test auto-detection: add a meeting opinion
   psypi meeting opinion 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1 "Test opinion for extension"
   # Should trigger notification!
   ```

---

## 🛠️ Example: Full Request for Meeting Monitor Extension

**Send this to Pi**:
```
Please create a Pi extension called "meeting-monitor" that auto-monitors meeting progress.

**Meeting ID**: 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1
**Topic**: Gleam Integration for Inner AI Plan Rewrite

**Requirements**:
1. Hook `tool_result` event:
   - Detect when `psypi meeting opinion` is executed (bash tool, command includes "psypi meeting opinion")
   - After 1s delay, run `psypi meeting show 7b3e9f1a-5c2d-4e8b-b1a2-f4c8d9e7b3a1`
   - Parse "Opinions (X):" from output
   - If X > lastCount, notify: `ctx.ui.notify("🆕 X new opinions!", "info")`

2. Hook `turn_end` event:
   - Track last check time
   - Every 10 minutes, run the same check
   - Use setInterval, store interval ID in closure

3. Hook `session_shutdown`:
   - Clear interval if exists
   - Reset state

4. Register command `/check-meeting`:
   - Description: "Check meeting 7b3e9f1a progress"
   - Handler: Run the meeting check immediately

5. Register flag `--meeting-monitor`:
   - Type: boolean, default: true
   - If false, skip all monitoring

**Code Style**:
- Use TypeScript, import from "@mariozechner/pi-coding-agent"
- Add comments explaining each hook
- Handle errors silently (don't crash Pi)

**Save to**: .pi/extensions/meeting-monitor.ts
```

---

## 🚨 Common Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---------|----------------|------------------|
| Skip reporting issue first | Violates AGENTS.md rule | Always `psypi issue-add` first |
| Use psql to create issues | Bypasses psypi code | Use `psypi issue-add` (fix tool if broken) |
| Vague prompt to Pi | Pi can't read your mind | Specific requirements, event names, commands |
| Forget `session_shutdown` cleanup | Memory leaks, stale intervals | Always cleanup resources |
| Use deprecated APIs | Breaks after psypi updates | Use `kernel.piSessionID()`, not old methods |

---

## 📋 Checklist for AIs Requesting Extensions

- [ ] Read Pi Extension Docs (extensions.md)
- [ ] Defined specific requirements (problem, events, functionality)
- [ ] Reported need as `psypi issue-add` (first!)
- [ ] Structured clear prompt with event names, commands, meeting IDs
- [ ] Reviewed Pi's code for compliance with psypi rules
- [ ] Saved to `.pi/extensions/` (project-local) or `~/.pi/agent/extensions/` (global)
- [ ] Tested with `/reload` and psypi tools only
- [ ] Reported any bugs via `psypi issue-add`

---

## 🔗 References

1. **Pi Extension Docs**: `/Users/jk/Library/pnpm/global/5/.pnpm/@mariozechner+pi-coding-agent@0.72.1_ws@8.20.0_zod@4.4.2/node_modules/@mariozechner/pi-coding-agent/docs/extensions.md`
2. **psypi AGENTS.md**: `/Users/jk/gits/hub/tools_ai/psypi/AGENTS.md` (rules for psypi tool usage)
3. **Pi Event System**: See "Events" section in extensions.md (session, tool, agent events)
4. **Example Extensions**: `/Users/jk/Library/pnpm/global/5/.pnpm/@mariozechner+pi-coding-agent@0.72.1_ws@8.20.0_zod@4.4.2/node_modules/@mariozechner/pi-coding-agent/examples/extensions/`

---

**Remember**: You're an AI agent working on psypi. Follow psypi rules first, use Pi's extension system to automate your work, and always report issues before implementing fixes! 🚀
