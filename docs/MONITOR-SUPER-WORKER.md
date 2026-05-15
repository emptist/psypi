# Monitor Super Worker Architecture

## Problem
Monitor is currently just a "speaker/talker" — it only has read-only tools (health, alerts, stats) and exists for human consultation. It has **no tools for writing, reading files, using bash, or doing anything autonomous**. It's basically useless as a worker.

## Vision
Monitor should be a **super worker** that:
- Gets ALL worker tools (read, edit, write, bash, glob, grep, task, issue, etc.)
- Triggers autonomously on events (not user commands)
- Can grow by modifying its own Gleam module definition
- Manages the system (tasks, issues, skills, meetings, docs, DB)

## Key Pi API Discovery
From `dist/core/extensions/types.d.ts` (Pi ExtensionAPI):
```typescript
pi.setActiveTools(toolNames: string[]);  // Enable ALL worker tools
pi.getActiveTools(): string[];
pi.exec(command, args, options);          // Bash from extension
pi.sendUserMessage(content);              // Trigger agent turns
pi.sendMessage(message);                 // Inject custom messages
```

## Architecture

### Current Monitor Toolset (useless):
- `psypi-autonomic-health` — read DB metrics
- `psypi-autonomic-status` — read status
- `psypi-autonomic-alerts` — read alerts
- `psypi-autonomic-stats` — read stats
- `psypi-autonomic-suggest` — read suggestions
- `psypi-autonomic-consult` — LLM chat only
- `psypi-commit` — review only
- `/autonomic-listen` — slash command

### Target Monitor Toolset (super worker):

**Phase 1: All Worker Tools**
- `read`, `bash`, `edit`, `write`, `glob`, `grep` (via `pi.setActiveTools`)
- `psypi-task-*`, `psypi-issue-*`, `psypi-skill-*`, `psypi-meeting-*`
- Database tools via Gleam

**Phase 2: Event-Driven Autonomy**
- `agent_end` → Monitor analyzes, optionally takes action
- `tool_result` → Monitor detects failures, auto-files issues
- `tool_call` → Monitor tracks dangerous patterns, intervenes
- `session_start` → Monitor health check + auto-task creation

**Phase 3: Self-Modification**
- Monitor can `edit` its own Gleam module (`src/monitor_ai.gleam`)
- Monitor can `psypi-commit` its own changes
- Monitor can regenerate `extension.js`
- This makes Monitor grow with usage

## Gleam Implementation (Pure Gleam!)

### extension_generator.gleam — Add super worker mode
```gleam
pub fn before_agent_start_hook() -> PiEventHook {
  event_hook("before_agent_start", [
    "    // Monitor Super Worker: Enable ALL tools",
    "    pi.setActiveTools(['read', 'bash', 'edit', 'write', 'glob', 'grep', 'find', 'ls']);",
    "    // Monitor autonomous analysis on session start",
    "    const { analyze_and_act } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');",
    "    analyze_and_act().then(r => {",
    "      if (r.ok && r.value?.action) ctx.ui.notify('Monitor: ' + r.value.action, 'info');",
    "    }).catch(e => {});",
  ] |> string.concat)
}
```

### monitor_ai.gleam — Autonomous action functions
```gleam
pub fn analyze_and_act() -> promise.Promise(Result(MonitorAction, MonitorError)) {
  db.with_connection(fn(conn) {
    // Check for failed tasks, open issues, dangerous patterns
    // Return MonitorAction with auto-created tasks/issues
  })
}
```

### Event-Driven Actions
Monitor hooks into lifecycle events and can:
1. On `agent_end`: Analyze if work needs to be done → auto-create tasks/issues
2. On `tool_result` with error: Auto-file issue
3. On `tool_call` dangerous pattern: Block + log
4. On session start: Health check → create tasks for failures

### Autonomous Decision Loop
Monitor gets an "autonomous turn" via `pi.sendUserMessage()`:
```javascript
// Monitor sends itself a message to "think"
pi.sendUserMessage("Monitor: Analyze recent events and take action if needed");
```

### Self-Modification (Future)
Monitor edits `src/monitor_ai.gleam` to add new behaviors.

## Critical Design Decision
**How does Monitor get turns? Two approaches:**

### Approach A: Event-Driven (Monitor reacts to events)
- Monitor has no independent turns
- On `agent_end`, Monitor analyzes and may `sendUserMessage` to itself
- Pro: Simple, no extra LLM calls
- Con: Monitor only acts when worker acts

### Approach B: Scheduled/Idle Check (Monitor proactively checks)
- On `session_start` and periodically, Monitor does health check
- If issues found, Monitor creates tasks/issues automatically
- Pro: Monitor is always monitoring
- Con: Needs background interval mechanism

**Recommendation**: Start with Approach A + scheduled `session_start` check. Monitor acts on:
1. Session start (health check)
2. Agent end (result analysis)
3. Tool error (auto-issue)

## Gleam Files to Modify/Create

1. **`src/extension_generator.gleam`** — Add super worker hooks
2. **`src/monitor_ai.gleam`** — Add autonomous action functions  
3. **`src/pi_tool_call.gleam`** — Update PiEventHook type if needed
4. **`extension.js`** — Regenerated output (auto-generated from Gleam)

## TODO
- [x] Add `pi.setActiveTools` call in `before_agent_start` hook
- [x] Add `analyze_and_act()` function in `monitor_ai.gleam`
- [ ] Add error → auto-issue on `tool_result`
- [ ] Add Monitor self-analysis turn capability
- [ ] Self-modification capability (Phase 3)

## Changes Made (2026-05-12)

### `src/extension_generator.gleam`
- `before_agent_start_hook()` now enables ALL worker tools via `pi.setActiveTools()`
- Calls `analyze_and_act()` from Gleam on session start
- Shows Monitor notification via `ctx.ui.notify()`

### `src/monitor_ai.gleam`
- Added `analyze_and_act()` - checks failed tasks, critical issues, stale tasks
- Added `auto_file_issue()` - auto-files issues from tool errors
- Added `MonitorAction` type for action reporting

### `extension.js` (regenerated)
- `before_agent_start` now includes:
  - `pi.setActiveTools(['read', 'bash', 'edit', 'write', 'glob', 'grep', 'find', 'ls'])`
  - `analyze_and_act()` call with notification
